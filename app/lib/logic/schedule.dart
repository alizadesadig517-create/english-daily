// Pure scheduling rules for the daily reminder, snooze and prefetch.
// All times are local wall-clock DateTimes; the notification service converts
// them to time-zone aware values.

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Next time the daily reminder fires: today at [hour]:[minute] if that is
/// still ahead, otherwise tomorrow.
DateTime nextDailyReminder(DateTime now, int hour, int minute) {
  final today = DateTime(now.year, now.month, now.day, hour, minute);
  if (today.isAfter(now)) return today;
  return DateTime(now.year, now.month, now.day + 1, hour, minute);
}

/// A snooze is only valid later today (it never carries over to tomorrow).
bool isValidSnooze(DateTime now, DateTime at) =>
    at.isAfter(now) && isSameDay(now, at);

/// The snooze time if it is still pending today, otherwise null.
DateTime? activeSnooze(DateTime now, DateTime? snoozedUntil) =>
    snoozedUntil != null && isValidSnooze(now, snoozedUntil) ? snoozedUntil : null;

class SnoozeOption {
  const SnoozeOption(this.label, this.delay, this.time);
  final String label;
  final Duration delay;
  final DateTime time;

  /// Options that would cross midnight are disabled (snooze is for today only).
  bool availableAt(DateTime now) => isValidSnooze(now, time);
}

List<SnoozeOption> quickSnoozeOptions(DateTime now) => [
      SnoozeOption('+30 min', const Duration(minutes: 30), now.add(const Duration(minutes: 30))),
      SnoozeOption('+1 hour', const Duration(hours: 1), now.add(const Duration(hours: 1))),
      SnoozeOption('+2 hours', const Duration(hours: 2), now.add(const Duration(hours: 2))),
    ];

/// A custom snooze picked as a time of day. Returns null when that time has
/// already passed today.
DateTime? customSnooze(DateTime now, int hour, int minute) {
  final at = DateTime(now.year, now.month, now.day, hour, minute);
  return isValidSnooze(now, at) ? at : null;
}

/// When the user will next be reminded: a pending snooze today or the next
/// daily reminder, whichever is first.
DateTime nextNotification(DateTime now, int hour, int minute, DateTime? snoozedUntil) {
  final daily = nextDailyReminder(now, hour, minute);
  final snooze = activeSnooze(now, snoozedUntil);
  if (snooze != null && snooze.isBefore(daily)) return snooze;
  return daily;
}

/// Prefetch runs one hour before the next reminder. If that moment has
/// already passed (e.g. it is 8:30 and the reminder is at 9:00), run now.
DateTime nextPrefetch(DateTime now, int hour, int minute) {
  final at = nextDailyReminder(now, hour, minute).subtract(const Duration(hours: 1));
  return at.isAfter(now) ? at : now;
}
