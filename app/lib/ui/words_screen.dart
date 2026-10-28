import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/lesson.dart';
import '../services/tts_service.dart';
import 'widgets.dart';

class WordsScreen extends StatefulWidget {
  const WordsScreen({super.key, required this.lesson, required this.isToday});
  final Lesson lesson;
  final bool isToday;

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) =>
      _pages.animateToPage(page, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);

  Future<void> _finish() async {
    if (widget.isToday) await context.read<AppState>().markSection(Section.words);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.lesson.words;
    final last = _page == words.length - 1;
    return StudyScope(
      active: widget.isToday,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Words  ${_page + 1} / ${words.length}'),
          actions: [if (widget.isToday) const TimerChip()],
        ),
        body: PageView.builder(
          controller: _pages,
          itemCount: words.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => WordCard(word: words[i]),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _page == 0 ? null : () => _go(_page - 1),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: last ? _finish : () => _go(_page + 1),
                  icon: Icon(last ? Icons.check : Icons.arrow_forward),
                  label: Text(last ? 'Done' : 'Next'),
                  style: FilledButton.styleFrom(minimumSize: const Size(140, 52)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WordCard extends StatefulWidget {
  const WordCard({super.key, required this.word});
  final Word word;

  @override
  State<WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<WordCard> {
  int _sense = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final w = widget.word;
    final s = w.senses[_sense.clamp(0, w.senses.length - 1)];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.word, style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(w.ipa, style: theme.textTheme.titleLarge?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  iconSize: 32,
                  tooltip: 'Pronounce',
                  onPressed: () => TtsService.speak(w.word),
                  icon: const Icon(Icons.volume_up),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (var i = 0; i < w.senses.length; i++)
              ChoiceChip(
                label: Text(w.senses[i].partOfSpeech, style: const TextStyle(fontSize: 16)),
                selected: i == _sense,
                onSelected: (_) => setState(() => _sense = i),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _SenseView(word: w.word, sense: s),
      ],
    );
  }
}

class _SenseView extends StatelessWidget {
  const _SenseView({required this.word, required this.sense});
  final String word;
  final Sense sense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget chips(List<String> items) => Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [for (final x in items) Chip(label: Text(x))],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Translation'),
        Text(sense.translation, style: theme.textTheme.headlineSmall),
        const SectionTitle('Meaning'),
        Text(sense.definition, style: theme.textTheme.bodyLarge),
        if (sense.synonyms.isNotEmpty) ...[const SectionTitle('Synonyms'), chips(sense.synonyms)],
        if (sense.antonyms.isNotEmpty) ...[const SectionTitle('Antonyms'), chips(sense.antonyms)],
        if (sense.homonyms.isNotEmpty) ...[
          const SectionTitle('Homonyms'),
          for (final h in sense.homonyms)
            TranslatedText('${h.word} – ${h.meaning}', h.translation,
                leading: Icon(Icons.call_split, size: 20, color: scheme.primary)),
        ],
        const SectionTitle('Examples'),
        for (final e in sense.examples)
          TranslatedText(
            e.text,
            e.translation,
            leading: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => TtsService.speak(e.text),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.volume_up_outlined, size: 22, color: scheme.primary),
              ),
            ),
          ),
      ],
    );
  }
}
