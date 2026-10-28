import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../logic/dates.dart';
import '../models/lesson.dart';
import 'lesson_card_screen.dart';
import 'lesson_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dates = state.availableDates.where((d) => d.compareTo(state.today) <= 0).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: RefreshIndicator(
        onRefresh: state.refreshDates,
        child: dates.isEmpty
            ? ListView(children: const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No lessons yet. Pull down to refresh.', textAlign: TextAlign.center),
                ),
              ])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: dates.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _LibraryTile(date: dates[i]),
              ),
      ),
    );
  }
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({required this.date});
  final String date;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final done = context.select<AppState, bool>((s) => s.progressByDate[date]?.completed ?? false);
    final theme = Theme.of(context);
    return FutureBuilder<Lesson?>(
      future: state.repo.cached(date),
      builder: (context, snap) {
        final lesson = snap.data;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LessonScreen(date: date))),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(prettyDate(date), style: theme.textTheme.titleMedium),
                          if (done) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.check_circle, size: 18, color: Colors.green),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          lesson == null
                              ? 'Tap to download'
                              : '${lesson.words.map((w) => w.word).join(', ')}\n${lesson.grammar.topic}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Lesson card',
                    icon: const Icon(Icons.article_outlined),
                    onPressed: () async {
                      final l = lesson ?? (await state.repo.get(date, state.settings)).lesson;
                      if (l != null && context.mounted) {
                        Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => LessonCardScreen(lesson: l)));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
