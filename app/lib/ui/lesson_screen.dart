import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/lesson_repository.dart';
import '../logic/dates.dart';
import '../logic/streak.dart';
import '../models/lesson.dart';
import 'lesson_card_screen.dart';
import 'lesson_sections.dart';
import 'widgets.dart';

/// A past day's lesson (review mode - progress is only tracked for today).
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.date});
  final String date;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  FetchResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _result = null);
    final s = context.read<AppState>();
    final r = await s.repo.get(widget.date, s.settings, force: force);
    if (mounted) setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final Lesson? lesson = r?.lesson;
    final progress = context.select<AppState, DayProgress?>((s) => s.progressByDate[widget.date]);
    return Scaffold(
      appBar: AppBar(
        title: Text(shortDate(widget.date)),
        actions: [
          if (lesson != null)
            IconButton(
              tooltip: 'Lesson card',
              icon: const Icon(Icons.ios_share),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => LessonCardScreen(lesson: lesson))),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(prettyDate(widget.date), style: Theme.of(context).textTheme.titleMedium),
          if (progress?.completed == true)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 20), SizedBox(width: 6), Text('Completed')]),
            ),
          const SizedBox(height: 16),
          if (r == null)
            const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
          else if (lesson != null)
            LessonSections(lesson: lesson, isToday: false)
          else if (r.status == FetchStatus.notPublished)
            MessageView(
              icon: Icons.event_busy,
              title: 'No lesson for this day',
              message: 'Nothing was published on ${prettyDate(widget.date)}.',
            )
          else
            MessageView(
              icon: Icons.cloud_off_outlined,
              title: "Couldn't download this lesson",
              message: r.message ?? 'Check your internet connection.',
              actionLabel: 'Retry',
              onAction: () => _load(force: true),
            ),
        ],
      ),
    );
  }
}
