import 'dates.dart';

/// Progress for one day, stored on the device.
class DayProgress {
  const DayProgress({
    required this.date,
    this.wordsDone = false,
    this.storyDone = false,
    this.grammarDone = false,
    this.seconds = 0,
    this.completed = false,
  });

  final String date;
  final bool wordsDone;
  final bool storyDone;
  final bool grammarDone;
  final int seconds;
  final bool completed;

  bool get hasActivity => wordsDone || storyDone || grammarDone || seconds >= 30 || completed;

  DayProgress copyWith({
    bool? wordsDone,
    bool? storyDone,
    bool? grammarDone,
    int? seconds,
    bool? completed,
  }) =>
      DayProgress(
        date: date,
        wordsDone: wordsDone ?? this.wordsDone,
        storyDone: storyDone ?? this.storyDone,
        grammarDone: grammarDone ?? this.grammarDone,
        seconds: seconds ?? this.seconds,
        completed: completed ?? this.completed,
      );

  /// The day is done when every section is finished, or the minutes goal is
  /// reached - whichever comes first. [hasStory] is false when today's lesson
  /// has no story (then the story section is not required).
  bool meetsGoal({required int minutesPerDay, required bool hasStory}) {
    final allSections = wordsDone && grammarDone && (storyDone || !hasStory);
    return allSections || seconds >= minutesPerDay * 60;
  }

  Map<String, Object?> toMap() => {
        'date': date,
        'words_done': wordsDone ? 1 : 0,
        'story_done': storyDone ? 1 : 0,
        'grammar_done': grammarDone ? 1 : 0,
        'seconds': seconds,
        'completed': completed ? 1 : 0,
      };

  factory DayProgress.fromMap(Map<String, Object?> m) => DayProgress(
        date: m['date'] as String,
        wordsDone: m['words_done'] == 1,
        storyDone: m['story_done'] == 1,
        grammarDone: m['grammar_done'] == 1,
        seconds: (m['seconds'] as int?) ?? 0,
        completed: m['completed'] == 1,
      );
}

enum DayStatus {
  /// Goal reached.
  done,

  /// Started but not finished.
  partial,

  /// A past day (since the first use of the app) with no activity.
  missed,

  /// Today, nothing done yet.
  pending,

  /// After today.
  future,

  /// Before the app was first used.
  none,
}

DayStatus dayStatus({
  required String date,
  required String today,
  String? firstUseDate,
  DayProgress? progress,
}) {
  if (date.compareTo(today) > 0) return DayStatus.future;
  if (progress?.completed ?? false) return DayStatus.done;
  final active = progress?.hasActivity ?? false;
  if (date == today) return active ? DayStatus.partial : DayStatus.pending;
  if (active) return DayStatus.partial;
  if (firstUseDate != null && date.compareTo(firstUseDate) < 0) return DayStatus.none;
  return DayStatus.missed;
}

class Streaks {
  const Streaks(this.current, this.longest);
  final int current;
  final int longest;

  @override
  bool operator ==(Object other) =>
      other is Streaks && other.current == current && other.longest == longest;

  @override
  int get hashCode => Object.hash(current, longest);

  @override
  String toString() => 'Streaks(current: $current, longest: $longest)';
}

/// Current streak: consecutive done days ending today, or ending yesterday if
/// today is not done yet (today still counts as "in progress").
/// Longest streak: the longest run of consecutive done days ever.
Streaks computeStreaks(Iterable<String> doneDates, String today) {
  final done = doneDates.where((d) => d.compareTo(today) <= 0).toSet();
  var current = 0;
  var day = done.contains(today) ? today : addDays(today, -1);
  while (done.contains(day)) {
    current++;
    day = addDays(day, -1);
  }

  final sorted = done.toList()..sort();
  var longest = 0;
  var run = 0;
  String? prev;
  for (final d in sorted) {
    run = (prev != null && addDays(prev, 1) == d) ? run + 1 : 1;
    if (run > longest) longest = run;
    prev = d;
  }
  return Streaks(current, longest);
}
