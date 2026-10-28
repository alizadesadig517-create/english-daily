import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../app_state.dart';
import '../logic/schedule.dart';
import 'widgets.dart';

/// Snooze today's reminder: +30 min, +1 h, +2 h or a custom time later today.
class SnoozeScreen extends StatelessWidget {
  const SnoozeScreen({super.key});

  Future<void> _snooze(BuildContext context, DateTime at) async {
    final label = formatTime(context, at);
    await context.read<AppState>().snooze(at);
    showMessage("OK, I'll remind you at $label.");
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Snooze')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Remind me again…', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text("Snooze works for today only. Tomorrow's reminder comes at the usual time.",
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          for (final o in quickSnoozeOptions(now))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.tonal(
                onPressed: o.availableAt(now) ? () => _snooze(context, o.time) : null,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
                child: Text(
                  o.availableAt(now) ? '${o.label}  ·  ${formatTime(context, o.time)}' : '${o.label}  ·  not today',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 45))),
                helpText: 'Remind me today at',
              );
              if (t == null || !context.mounted) return;
              final at = customSnooze(DateTime.now(), t.hour, t.minute);
              if (at == null) {
                showMessage('Please pick a time later today.');
              } else {
                await _snooze(context, at);
              }
            },
            icon: const Icon(Icons.access_time),
            label: const Text('Pick a time…', style: TextStyle(fontSize: 18)),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () {
              context.read<AppState>().setTab(0);
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start now instead', style: TextStyle(fontSize: 18)),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
          ),
        ],
      ),
    );
  }
}
