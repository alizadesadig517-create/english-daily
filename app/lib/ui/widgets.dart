import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

/// Counts study time for today while this widget is on screen.
class StudyScope extends StatefulWidget {
  const StudyScope({super.key, required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  State<StudyScope> createState() => _StudyScopeState();
}

class _StudyScopeState extends State<StudyScope> {
  AppState? _state;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _state = context.read<AppState>()..enterStudy();
    }
  }

  @override
  void dispose() {
    _state?.leaveStudy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

String formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String formatTime(BuildContext context, DateTime t) =>
    MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(t),
        alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat);

/// Small timer chip for the app bar of today's lesson screens.
class TimerChip extends StatelessWidget {
  const TimerChip({super.key});

  @override
  Widget build(BuildContext context) {
    final seconds = context.select<AppState, int>((s) => s.todayProgress.seconds);
    final goal = context.select<AppState, int>((s) => s.settings.minutesPerDay);
    final done = context.select<AppState, bool>((s) => s.todayProgress.completed);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Chip(
        avatar: Icon(done ? Icons.check_circle : Icons.timer_outlined, size: 18, color: scheme.primary),
        label: Text('${formatDuration(seconds)} / $goal:00'),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
      );
}

/// English text with its translation underneath.
class TranslatedText extends StatelessWidget {
  const TranslatedText(this.text, this.translation, {super.key, this.leading});
  final String text;
  final String translation;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: theme.textTheme.bodyLarge),
                Text(translation,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.refresh), label: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
