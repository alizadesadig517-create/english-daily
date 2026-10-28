import 'package:timezone/timezone.dart' as tz;

/// Lesson dates follow the Asia/Baku calendar (see content/README rules).
const lessonTimeZone = 'Asia/Baku';

/// YYYY-MM-DD for the calendar date of [d] (its own y/m/d fields).
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Parses YYYY-MM-DD into a date-only [DateTime] (local midnight).
DateTime parseDateKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String addDays(String key, int days) {
  final d = parseDateKey(key);
  return dateKey(DateTime(d.year, d.month, d.day + days));
}

/// Today's lesson date (Asia/Baku). Requires timezone data to be initialised.
String lessonToday([DateTime? nowUtc]) {
  final loc = tz.getLocation(lessonTimeZone);
  final now = nowUtc == null ? tz.TZDateTime.now(loc) : tz.TZDateTime.from(nowUtc, loc);
  return dateKey(now);
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December'
];
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String monthName(int month) => _months[month - 1];

/// "Tuesday, 28 October 2026"
String prettyDate(String key) {
  final d = parseDateKey(key);
  return '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "28 Oct"
String shortDate(String key) {
  final d = parseDateKey(key);
  return '${d.day} ${_months[d.month - 1].substring(0, 3)}';
}
