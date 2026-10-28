import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../logic/dates.dart';
import '../logic/streak.dart';
import 'lesson_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime? _month;

  static Color colorFor(DayStatus s, ColorScheme scheme) => switch (s) {
        DayStatus.done => const Color(0xFF3FA35B),
        DayStatus.partial => const Color(0xFFF2B33D),
        DayStatus.missed => const Color(0xFFE0645C),
        DayStatus.pending => scheme.primaryContainer,
        DayStatus.future || DayStatus.none => Colors.transparent,
      };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = parseDateKey(state.today);
    final month = _month ?? DateTime(today.year, today.month);
    final streaks = state.streaks;

    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1; // Monday first

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              Expanded(child: _StreakCard(icon: Icons.local_fire_department, label: 'Current streak', value: streaks.current)),
              const SizedBox(width: 12),
              Expanded(child: _StreakCard(icon: Icons.emoji_events_outlined, label: 'Longest streak', value: streaks.longest)),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setState(() => _month = DateTime(month.year, month.month - 1)),
                      ),
                      Expanded(
                        child: Text('${monthName(month.month)} ${month.year}',
                            textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setState(() => _month = DateTime(month.year, month.month + 1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                        Expanded(
                          child: Text(d,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
                      for (var day = 1; day <= daysInMonth; day++)
                        _dayCell(context, state, dateKey(DateTime(month.year, month.month, day))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Legend(color: colorFor(DayStatus.done, scheme), label: 'Done'),
              _Legend(color: colorFor(DayStatus.partial, scheme), label: 'Partial'),
              _Legend(color: colorFor(DayStatus.missed, scheme), label: 'Missed'),
              _Legend(color: Colors.transparent, label: 'Future', outlined: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(BuildContext context, AppState state, String key) {
    final scheme = Theme.of(context).colorScheme;
    final status = dayStatus(
      date: key,
      today: state.today,
      firstUseDate: state.settings.firstUseDate,
      progress: state.progressByDate[key],
    );
    final isToday = key == state.today;
    final bg = colorFor(status, scheme);
    final filled = bg != Colors.transparent && status != DayStatus.pending;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isToday
            ? BorderSide(color: scheme.primary, width: 2.5)
            : status == DayStatus.future
                ? BorderSide(color: scheme.outlineVariant)
                : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: status == DayStatus.future
            ? null
            : () {
                if (isToday) {
                  state.setTab(0);
                } else {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => LessonScreen(date: key)));
                }
              },
        child: Center(
          child: Text(
            '${parseDateKey(key).day}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
              color: filled ? Colors.white : (status == DayStatus.future ? scheme.onSurfaceVariant : scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.deepOrange, size: 28),
            const SizedBox(height: 6),
            Text('$value ${value == 1 ? 'day' : 'days'}', style: theme.textTheme.headlineSmall),
            Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.outlined = false});
  final Color color;
  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
              border: outlined ? Border.all(color: Theme.of(context).colorScheme.outline) : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      );
}
