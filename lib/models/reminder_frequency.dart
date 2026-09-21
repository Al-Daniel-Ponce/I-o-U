/// Frequency options for recurring debt reminders.
enum ReminderFrequency {
  daily,
  every2Days,
  every3Days,
  weekly,
  biweekly,
  monthly,
  custom;

  static ReminderFrequency fromString(String value) {
    return ReminderFrequency.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ReminderFrequency.daily,
    );
  }

  String get label {
    switch (this) {
      case ReminderFrequency.daily:
        return 'Every day';
      case ReminderFrequency.every2Days:
        return 'Every 2 days';
      case ReminderFrequency.every3Days:
        return 'Every 3 days';
      case ReminderFrequency.weekly:
        return 'Every week';
      case ReminderFrequency.biweekly:
        return 'Every 2 weeks';
      case ReminderFrequency.monthly:
        return 'Every month';
      case ReminderFrequency.custom:
        return 'Custom';
    }
  }

  /// Returns the interval in days for non-custom frequencies.
  int? get defaultIntervalDays {
    switch (this) {
      case ReminderFrequency.daily:
        return 1;
      case ReminderFrequency.every2Days:
        return 2;
      case ReminderFrequency.every3Days:
        return 3;
      case ReminderFrequency.weekly:
        return 7;
      case ReminderFrequency.biweekly:
        return 14;
      case ReminderFrequency.monthly:
        return 30;
      case ReminderFrequency.custom:
        return null;
    }
  }

  /// Returns a human-readable label for a given interval in days.
  static String labelForDays(int days) {
    if (days == 1) return 'Every day';
    if (days == 2) return 'Every 2 days';
    if (days == 3) return 'Every 3 days';
    if (days == 7) return 'Every week';
    if (days == 14) return 'Every 2 weeks';
    if (days == 30) return 'Every month';
    return 'Every $days days';
  }
}
