import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/lesson.dart';
import 'grammar_screen.dart';
import 'story_screen.dart';
import 'words_screen.dart';

/// The three section cards (Words, Story, Grammar) of a lesson.
class LessonSections extends StatelessWidget {
  const LessonSections({super.key, required this.lesson, required this.isToday, this.isDone});

  final Lesson lesson;
  final bool isToday;
  final bool Function(Section)? isDone;

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final story = lesson.story;
    return Column(
      children: [
        _SectionCard(
          icon: Icons.style_outlined,
          title: 'Words',
          subtitle: lesson.words.map((w) => w.word).join(' · '),
          done: isDone?.call(Section.words) ?? false,
          onTap: () => _open(context, WordsScreen(lesson: lesson, isToday: isToday)),
        ),
        if (story != null) ...[
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.menu_book_outlined,
            title: 'Story',
            subtitle: story.title,
            done: isDone?.call(Section.story) ?? false,
            onTap: () => _open(context, StoryScreen(lesson: lesson, isToday: isToday)),
          ),
        ],
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.rule_outlined,
          title: 'Grammar',
          subtitle: lesson.grammar.topic,
          done: isDone?.call(Section.grammar) ?? false,
          onTap: () => _open(context, GrammarScreen(lesson: lesson, isToday: isToday)),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: done ? scheme.primary : scheme.primaryContainer,
                child: Icon(done ? Icons.check : icon,
                    color: done ? scheme.onPrimary : scheme.onPrimaryContainer, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
