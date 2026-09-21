import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
      onDidReceiveNotificationResponse: _onNotificationResponse,
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

    _logger.info('NotificationService initialized');
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
  Future<void> cancelDebtReminder(int debtId) async {
    await _plugin.cancel(debtId);
    _logger.info('Cancelled reminder for debt $debtId');
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

  /// Handles notification response (action buttons).
  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    final parts = payload.split('|');
    if (parts.length != 2) return;

    final action = parts[0];
    final debtId = int.tryParse(parts[1]);
    if (debtId == null) return;

    _logger.info('Notification action: $action for debt $debtId');
    onAction?.call(action, debtId);

    // Always reschedule the next reminder after a notification fires,
    // regardless of which action was taken (or just tapping the body).
    onReschedule?.call(debtId);
  }

  /// Checks all active debts and reschedules reminders.
  /// Used on app restart / resume to recover from missed notifications.
  Future<void> rescheduleAllActive(List<Debt> activeDebts) async {
    for (final debt in activeDebts) {
      if (debt.reminderEnabled && !debt.isPaid && debt.id != null) {
        await cancelDebtReminder(debt.id!);
        // Compute the next date from now so stale DB dates don't cause
        // same-day scheduling.
        final now = tz.TZDateTime.now(tz.local);
        final nextDate = now.add(Duration(days: debt.reminderIntervalDays));
        final actualDate =
            DateTime(nextDate.year, nextDate.month, nextDate.day);
        final updatedDebt = debt.copyWith(nextReminderDate: actualDate);
        // Persist the updated date to the DB.
        onPersistNextDate?.call(debt.id!, actualDate);
        await scheduleDebtReminder(updatedDebt);
      }
    }
    _logger.info('Rescheduled ${activeDebts.length} active reminders');
  }
}
