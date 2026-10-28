import 'package:english_daily/logic/streak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeStreaks', () {
    test('no done days', () {
      expect(computeStreaks([], '2026-10-28'), const Streaks(0, 0));
    });

    test('streak ending today', () {
      expect(computeStreaks(['2026-10-26', '2026-10-27', '2026-10-28'], '2026-10-28'), const Streaks(3, 3));
    });

    test('today not done yet keeps yesterday\'s streak alive', () {
      expect(computeStreaks(['2026-10-26', '2026-10-27'], '2026-10-28'), const Streaks(2, 2));
    });

    test('a missed day breaks the current streak', () {
      expect(computeStreaks(['2026-10-25', '2026-10-26'], '2026-10-28'), const Streaks(0, 2));
    });

    test('longest streak is kept from the past', () {
      final done = ['2026-09-01', '2026-09-02', '2026-09-03', '2026-09-04', '2026-10-27', '2026-10-28'];
      expect(computeStreaks(done, '2026-10-28'), const Streaks(2, 4));
    });

    test('works across month and year boundaries', () {
      expect(computeStreaks(['2025-12-30', '2025-12-31', '2026-01-01'], '2026-01-01'), const Streaks(3, 3));
      expect(computeStreaks(['2026-02-28', '2026-03-01'], '2026-03-01'), const Streaks(2, 2));
    });

    test('future dates and duplicates are ignored', () {
      expect(computeStreaks(['2026-10-28', '2026-10-28', '2026-10-29'], '2026-10-28'), const Streaks(1, 1));
    });
  });

  group('dayStatus', () {
    DayStatus status(String date, {DayProgress? p, String? first = '2026-10-01'}) =>
        dayStatus(date: date, today: '2026-10-28', firstUseDate: first, progress: p);

    test('future', () => expect(status('2026-10-29'), DayStatus.future));
    test('done', () => expect(status('2026-10-20', p: const DayProgress(date: '2026-10-20', completed: true)), DayStatus.done));
    test('partial', () => expect(status('2026-10-20', p: const DayProgress(date: '2026-10-20', wordsDone: true)), DayStatus.partial));
    test('missed', () => expect(status('2026-10-20'), DayStatus.missed));
    test('before first use', () => expect(status('2026-09-20'), DayStatus.none));
    test('today untouched is pending', () => expect(status('2026-10-28'), DayStatus.pending));
    test('today started is partial',
        () => expect(status('2026-10-28', p: const DayProgress(date: '2026-10-28', seconds: 120)), DayStatus.partial));
    test('a few seconds is not activity',
        () => expect(status('2026-10-20', p: const DayProgress(date: '2026-10-20', seconds: 5)), DayStatus.missed));
  });

  group('DayProgress.meetsGoal', () {
    test('all sections done', () {
      const p = DayProgress(date: 'd', wordsDone: true, storyDone: true, grammarDone: true);
      expect(p.meetsGoal(minutesPerDay: 15, hasStory: true), isTrue);
    });

    test('story not required when there is no story', () {
      const p = DayProgress(date: 'd', wordsDone: true, grammarDone: true);
      expect(p.meetsGoal(minutesPerDay: 15, hasStory: false), isTrue);
      expect(p.meetsGoal(minutesPerDay: 15, hasStory: true), isFalse);
    });

    test('minutes goal alone is enough', () {
      expect(const DayProgress(date: 'd', seconds: 900).meetsGoal(minutesPerDay: 15, hasStory: true), isTrue);
      expect(const DayProgress(date: 'd', seconds: 899).meetsGoal(minutesPerDay: 15, hasStory: true), isFalse);
    });

    test('map round trip', () {
      const p = DayProgress(date: '2026-10-28', wordsDone: true, seconds: 42, completed: true);
      final again = DayProgress.fromMap(p.toMap());
      expect(again.wordsDone, isTrue);
      expect(again.storyDone, isFalse);
      expect(again.seconds, 42);
      expect(again.completed, isTrue);
    });
  });
}
