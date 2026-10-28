import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../logic/dates.dart';
import 'lesson_sections.dart';
import 'snooze_screen.dart';
import 'widgets.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            tooltip: 'Snooze reminder',
            icon: const Icon(Icons.snooze),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SnoozeScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.loadToday(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(prettyDate(state.today), style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const _ProgressCard(),
            if (state.snoozedUntil != null && state.snoozedUntil!.isAfter(DateTime.now()))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.snooze, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Reminder snoozed until ${formatTime(context, state.snoozedUntil!)}')),
                    TextButton(onPressed: state.cancelSnooze, child: const Text('Cancel')),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            switch (state.todayState) {
              LoadState.loading => const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              LoadState.notPublished => MessageView(
                  icon: Icons.coffee_outlined,
                  title: 'Not ready yet',
                  message: "Today's lesson hasn't been published yet. It usually appears early in the morning. Try again in a little while.",
                  actionLabel: 'Try again',
                  onAction: () => state.loadToday(force: true),
                ),
              LoadState.error => MessageView(
                  icon: Icons.cloud_off_outlined,
                  title: "Couldn't download today's lesson",
                  message: state.todayError ?? 'Check your internet connection.',
                  actionLabel: 'Retry',
                  onAction: () => state.loadToday(force: true),
                ),
              LoadState.ready => LessonSections(
                  lesson: state.todayLesson!,
                  isToday: true,
                  isDone: state.isSectionDone,
                ),
            },
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = state.todayProgress;
    final goal = state.settings.minutesPerDay * 60;
    final streak = state.streaks.current;
    return Card(
      color: p.completed ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(p.completed ? Icons.emoji_events : Icons.timer_outlined, color: scheme.primary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.completed ? 'Goal reached!' : '${formatDuration(p.seconds)} of ${state.settings.minutesPerDay} min',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.local_fire_department, size: 18, color: Colors.deepOrange),
                  label: Text('$streak day${streak == 1 ? '' : 's'}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: p.completed ? 1 : (p.seconds / goal).clamp(0, 1).toDouble(),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              p.completed
                  ? 'You can keep practising as long as you like.'
                  : 'Finish all sections or study ${state.settings.minutesPerDay} minutes to complete the day. The timer runs while a section is open.',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
