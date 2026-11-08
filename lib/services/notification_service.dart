import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/debt.dart';
import 'logger.dart';

/// Callback type for when a notification action is tapped.
typedef NotificationActionCallback = Future<void> Function(
    String action, int debtId);

/// Callback type for rescheduling a reminder after a notification fires.
typedef RescheduleCallback = Future<void> Function(int debtId);

/// Handles all local notification logic: scheduling, cancelling,
/// and processing action callbacks for debt reminders.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Logger _logger;

  /// Callback for notification actions (Mark as Paid, Remind Me Later).
  NotificationActionCallback? onAction;

  /// Callback to reschedule the next reminder after a notification fires.
  RescheduleCallback? onReschedule;

  /// Callback to persist the next reminder date to the database.
  Future<void> Function(int debtId, DateTime nextDate)? onPersistNextDate;

  /// Whether exact (precise) alarms are permitted. False after Android 13+
  /// when the user has not granted SCHEDULE_EXACT_ALARM — we then degrade
  /// to inexact scheduling instead of throwing.
  bool _exactAlarmsEnabled = true;

  NotificationService({Logger? logger})
      : _logger = logger ?? const Logger('NotificationService');

  static const _channelId = 'debt_reminders';
  static const _channelName = 'Debt Reminders';
  static const _channelDescription = 'Reminders for unpaid debts';

  // Default notification time: 9:00 AM
  static const _defaultHour = 9;
  static const _defaultMinute = 0;

  /// Initializes the notification plugin, channels, and action handling.
  Future<void> initialize() async {
    tz.initializeTimeZones();
    await _refreshDeviceTimezone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    // Create Android notification channel
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );
    }

    await _configureExactAlarms(androidPlugin);
    await _bootstrapFromColdStart();

    _logger.info('NotificationService initialized');
  }

  /// Sets `tz.local` to the device's actual timezone so "9:00 AM" means
  /// 9:00 AM on the user's clock, not 9:00 UTC (5:00 PM Philippine time).
  Future<void> _refreshDeviceTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      // Offset-only or unsupported identifiers fall back to UTC scheduling;
      // timestamps still resolve to the same absolute instant.
      _logger.error('Could not set device timezone, scheduling in UTC', e);
    }
  }

  /// Android 12+ gates exact alarms behind SCHEDULE_EXACT_ALARM, which is
  /// denied by default for newer installs. Ask for it once and remember the
  /// verdict so scheduling can degrade to inexact instead of throwing.
  Future<void> _configureExactAlarms(
    AndroidFlutterLocalNotificationsPlugin? androidPlugin,
  ) async {
    if (androidPlugin == null) return;
    try {
      await androidPlugin.requestExactAlarmsPermission();
    } catch (e) {
      _logger.error('Exact alarm permission request failed', e);
    }
    try {
      _exactAlarmsEnabled =
          await androidPlugin.canScheduleExactNotifications() ?? false;
    } catch (e) {
      _exactAlarmsEnabled = false;
      _logger.error('Exact alarm capability query failed', e);
    }
    if (!_exactAlarmsEnabled) {
      _logger.info('Exact alarms unavailable; reminders schedule inexact');
    }
  }

  /// A tap on the notification can launch the app from a dead process. The
  /// plugin delivers that response only once — during initialize(), when a
  /// cold start was caused by one of our notifications — so route it here,
  /// before the user sees any screen.
  Future<void> _bootstrapFromColdStart() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      final response = details?.notificationResponse;
      if (details?.didNotificationLaunchApp == true && response != null) {
        await _handleNotificationResponse(response);
      }
    } catch (e) {
      _logger.error('Failed to process notification cold start', e);
    }
  }

  /// Requests notification permissions (Android 13+, iOS).
  Future<bool> requestPermission() async {
    // Android 13+ permission
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      _logger.info('Android notification permission: $granted');
      return granted ?? false;
    }

    // iOS permission
    final iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      _logger.info('iOS notification permission: $granted');
      return granted ?? false;
    }

    return true;
  }

  /// Schedules a recurring reminder for the given debt.
  ///
  /// Uses the debt's `reminderStartDate` and `reminderIntervalDays`
  /// to compute the next notification time at 9:00 AM.
  /// Notification ID is the debt ID (unique per debt).
  Future<void> scheduleDebtReminder(Debt debt) async {
    if (!debt.reminderEnabled || debt.isPaid || debt.id == null) return;

    final reminderDate = debt.nextReminderDate ?? debt.reminderStartDate;
    if (reminderDate == null) return;

    final scheduledDate = _nextInstanceOf9AM(reminderDate);
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      // If the date is in the past, schedule for tomorrow at 9 AM
      return scheduleNextAfterFired(debt);
    }

    final notificationId = debt.id!;
    final body = _buildNotificationBody(debt);

    try {
      await _plugin.zonedSchedule(
        notificationId,
        '💰 Debt Reminder',
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            actions: [
              AndroidNotificationAction('paid', 'Mark as Paid'),
              AndroidNotificationAction('later', 'Remind Me Later'),
            ],
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: _exactAlarmsEnabled
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null,
        payload: 'reminder|${debt.id}',
      );

      _logger.info(
          'Scheduled reminder for ${debt.lenderName} at $scheduledDate');
    } catch (e) {
      _logger.error('Failed to schedule reminder for debt ${debt.id}', e);
    }
  }

  /// Schedules the next occurrence after the current one fires.
  /// Called internally when a notification is received.
  Future<void> scheduleNextAfterFired(Debt debt,
      {DateTime? fromDate}) async {
    if (!debt.reminderEnabled || debt.isPaid || debt.id == null) return;

    final base = fromDate ?? tz.TZDateTime.now(tz.local);
    final nextDate = base.add(Duration(days: debt.reminderIntervalDays));
    final scheduledDate = _nextInstanceOf9AM(nextDate);

    final notificationId = debt.id!;
    final body = _buildNotificationBody(debt);

    try {
      await _plugin.zonedSchedule(
        notificationId,
        '💰 Debt Reminder',
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            actions: [
              AndroidNotificationAction('paid', 'Mark as Paid'),
              AndroidNotificationAction('later', 'Remind Me Later'),
            ],
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: _exactAlarmsEnabled
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'reminder|${debt.id}',
      );

      // Persist the actual scheduled date so the DB stays in sync.
      final actualDate = DateTime(
          scheduledDate.year, scheduledDate.month, scheduledDate.day);
      onPersistNextDate?.call(debt.id!, actualDate);

      _logger.info(
          'Rescheduled next reminder for ${debt.lenderName} at $scheduledDate');
    } catch (e) {
      _logger.error('Failed to reschedule reminder for debt ${debt.id}', e);
    }
  }

  /// Cancels the scheduled notification for a specific debt.
  ///
  /// Wrapped: a platform hiccup on cancel must never abort the surrounding
  /// operation (delete, payment) which has already succeeded logically.
  Future<void> cancelDebtReminder(int debtId) async {
    try {
      await _plugin.cancel(debtId);
      _logger.info('Cancelled reminder for debt $debtId');
    } catch (e) {
      _logger.error('Failed to cancel reminder for debt $debtId', e);
    }
  }

  /// Cancels all scheduled notifications.
  Future<void> cancelAllReminders() async {
    await _plugin.cancelAll();
    _logger.info('Cancelled all reminders');
  }

  /// Reschedules a reminder after settings change.
  Future<void> rescheduleDebtReminder(Debt debt) async {
    await cancelDebtReminder(debt.id!);
    await scheduleDebtReminder(debt);
  }

  /// Fires an immediate notification (used for "Remind Me Later").
  Future<void> showDebtReminder(Debt debt) async {
    if (debt.id == null) return;

    final body = _buildNotificationBody(debt);

    try {
      await _plugin.show(
        math.Random().nextInt(100000) + 100000,
        '🔔 Payment Reminder',
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      _logger.error('Failed to show immediate reminder for debt ${debt.id}', e);
    }
  }

  /// Builds the notification body text from debt data.
  String _buildNotificationBody(Debt debt) {
    final buffer = StringBuffer();
    buffer.write('${debt.lenderName} still owes you ');
    buffer.write('₱${debt.amount.toStringAsFixed(2)}.');
    if (debt.notes != null && debt.notes!.isNotEmpty) {
      buffer.write('\nNote: ${debt.notes}');
    }
    return buffer.toString();
  }

  /// Computes the next occurrence of 9:00 AM on or after [date].
  tz.TZDateTime _nextInstanceOf9AM(DateTime date) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      _defaultHour,
      _defaultMinute,
    );

    // If that time has already passed today, move to the next day
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  /// Handles notification taps and action buttons.
  ///
  /// The button id ('paid' / 'later') rides on [NotificationResponse.actionId];
  /// a plain body tap leaves actionId null. 'paid' and the reschedule chain
  /// are awaited strictly to stop them racing on the same DB row.
  Future<void> _handleNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;

    final parts = payload.split('|');
    if (parts.length != 2) return;

    final debtId = int.tryParse(parts[1]);
    if (debtId == null) return;

    final action = response.actionId ?? 'reminder';
    _logger.info('Notification action: $action for debt $debtId');

    if (action == 'paid') {
      // The payment handler cancels the reminder itself; rescheduling here
      // would re-queue an alarm for a debt that is already settled.
      await onAction?.call('paid', debtId);
      return;
    }

    await onAction?.call(action, debtId);
    await onReschedule?.call(debtId);
  }

  /// Reschedules reminders for active debts.
  ///
  /// Honors the persisted [Debt.nextReminderDate] (passed through
  /// [scheduleDebtReminder]) so that using the app daily never pushes a
  /// reminder forward — it fires on its original date.
  Future<void> rescheduleAllActive(List<Debt> activeDebts) async {
    for (final debt in activeDebts) {
      if (debt.reminderEnabled && !debt.isPaid && debt.id != null) {
        await cancelDebtReminder(debt.id!);
        await scheduleDebtReminder(debt);
      }
    }
    _logger.info('Rescheduled ${activeDebts.length} active reminders');
  }
}
