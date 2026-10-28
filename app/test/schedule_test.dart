import 'package:english_daily/logic/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nextDailyReminder', () {
    test('later today', () {
      expect(nextDailyReminder(DateTime(2026, 10, 28, 7, 0), 9, 0), DateTime(2026, 10, 28, 9, 0));
    });

    test('already passed -> tomorrow', () {
      expect(nextDailyReminder(DateTime(2026, 10, 28, 9, 30), 9, 0), DateTime(2026, 10, 29, 9, 0));
    });

    test('exactly now -> tomorrow', () {
      expect(nextDailyReminder(DateTime(2026, 10, 28, 9, 0), 9, 0), DateTime(2026, 10, 29, 9, 0));
    });

    test('end of month and year', () {
      expect(nextDailyReminder(DateTime(2026, 12, 31, 22, 0), 8, 15), DateTime(2027, 1, 1, 8, 15));
    });
  });

  group('snooze', () {
    final now = DateTime(2026, 10, 28, 9, 5);

    test('quick options are +30 min, +1 h, +2 h', () {
      final o = quickSnoozeOptions(now);
      expect(o.map((x) => x.time), [
        DateTime(2026, 10, 28, 9, 35),
        DateTime(2026, 10, 28, 10, 5),
        DateTime(2026, 10, 28, 11, 5),
      ]);
      expect(o.every((x) => x.availableAt(now)), isTrue);
    });

    test('options crossing midnight are disabled (today only)', () {
      final late = DateTime(2026, 10, 28, 22, 45);
      final o = quickSnoozeOptions(late);
      expect(o[0].availableAt(late), isTrue); // 23:15
      expect(o[1].availableAt(late), isTrue); // 23:45
      expect(o[2].availableAt(late), isFalse); // 00:45 tomorrow
    });

    test('custom time must be later today', () {
      expect(customSnooze(now, 14, 30), DateTime(2026, 10, 28, 14, 30));
      expect(customSnooze(now, 8, 0), isNull);
      expect(customSnooze(now, 9, 5), isNull);
    });

    test('activeSnooze ignores past and other days', () {
      expect(activeSnooze(now, DateTime(2026, 10, 28, 10, 0)), DateTime(2026, 10, 28, 10, 0));
      expect(activeSnooze(now, DateTime(2026, 10, 28, 9, 0)), isNull);
      expect(activeSnooze(now, DateTime(2026, 10, 29, 10, 0)), isNull);
      expect(activeSnooze(now, null), isNull);
    });
  });

  group('nextNotification', () {
    test('pending snooze comes before tomorrow\'s reminder', () {
      final now = DateTime(2026, 10, 28, 9, 10);
      expect(nextNotification(now, 9, 0, DateTime(2026, 10, 28, 10, 10)), DateTime(2026, 10, 28, 10, 10));
    });

    test('after the snooze time passes, the normal schedule continues next day', () {
      final now = DateTime(2026, 10, 28, 11, 0);
      expect(nextNotification(now, 9, 0, DateTime(2026, 10, 28, 10, 10)), DateTime(2026, 10, 29, 9, 0));
    });

    test('yesterday\'s snooze is ignored', () {
      final now = DateTime(2026, 10, 29, 7, 0);
      expect(nextNotification(now, 9, 0, DateTime(2026, 10, 28, 23, 0)), DateTime(2026, 10, 29, 9, 0));
    });

    test('no snooze', () {
      expect(nextNotification(DateTime(2026, 10, 28, 7, 0), 9, 0, null), DateTime(2026, 10, 28, 9, 0));
    });
  });

  group('nextPrefetch', () {
    test('one hour before the reminder', () {
      expect(nextPrefetch(DateTime(2026, 10, 28, 6, 0), 9, 0), DateTime(2026, 10, 28, 8, 0));
    });

    test('inside the last hour -> now', () {
      final now = DateTime(2026, 10, 28, 8, 30);
      expect(nextPrefetch(now, 9, 0), now);
    });

    test('after the reminder -> tomorrow, one hour before', () {
      expect(nextPrefetch(DateTime(2026, 10, 28, 9, 30), 9, 0), DateTime(2026, 10, 29, 8, 0));
    });

    test('reminder just after midnight -> prefetch the evening before', () {
      expect(nextPrefetch(DateTime(2026, 10, 28, 12, 0), 0, 30), DateTime(2026, 10, 28, 23, 30));
    });
  });
}
