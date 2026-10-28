import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/app_settings.dart';
import '../models/lesson.dart';
import 'widgets.dart';

class GrammarScreen extends StatefulWidget {
  const GrammarScreen({super.key, required this.lesson, required this.isToday});
  final Lesson lesson;
  final bool isToday;

  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  bool _english = true;
  late final List<String?> _answers;
  late final List<TextEditingController> _controllers;
  bool _checked = false;

  List<Question> get _questions => widget.lesson.grammar.exercise.questions;

  @override
  void initState() {
    super.initState();
    _answers = List.filled(_questions.length, null);
    _controllers = [for (final _ in _questions) TextEditingController()];
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _allAnswered => _answers.every((a) => a != null && a.trim().isNotEmpty);

  int get _score {
    var n = 0;
    for (var i = 0; i < _questions.length; i++) {
      if (_answers[i] != null && _questions[i].isCorrect(_answers[i]!)) n++;
    }
    return n;
  }

  Future<void> _check() async {
    FocusScope.of(context).unfocus();
    setState(() => _checked = true);
    if (widget.isToday) await context.read<AppState>().markSection(Section.grammar);
  }

  void _reset() => setState(() {
        _checked = false;
        for (var i = 0; i < _answers.length; i++) {
          _answers[i] = null;
          _controllers[i].clear();
        }
      });

  @override
  Widget build(BuildContext context) {
    final g = widget.lesson.grammar;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final langCode = widget.lesson.translationLanguage.toUpperCase();
    return StudyScope(
      active: widget.isToday,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Grammar'),
          actions: [if (widget.isToday) const TimerChip()],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(g.topic, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            Text(g.topicTranslation, style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                segments: [
                  const ButtonSegment(value: true, label: Text('EN')),
                  ButtonSegment(
                      value: false,
                      label: Text(langCode),
                      tooltip: languageName(widget.lesson.translationLanguage)),
                ],
                selected: {_english},
                onSelectionChanged: (v) => setState(() => _english = v.first),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(_english ? g.explanation : g.explanationTranslation, style: theme.textTheme.bodyLarge),
              ),
            ),
            const SectionTitle('Rules'),
            for (final r in g.rules)
              TranslatedText(
                _english ? r.text : r.translation,
                _english ? r.translation : r.text,
                leading: Icon(Icons.check_circle_outline, color: scheme.primary, size: 22),
              ),
            const SectionTitle('Examples'),
            for (final e in g.examples)
              TranslatedText(e.text, e.translation,
                  leading: Icon(Icons.format_quote, color: scheme.primary, size: 22)),
            const SectionTitle('Exercise'),
            Text(_english ? g.exercise.instructions : g.exercise.instructionsTranslation,
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            for (var i = 0; i < _questions.length; i++) _questionCard(i),
            const SizedBox(height: 8),
            if (!_checked)
              FilledButton.icon(
                onPressed: _allAnswered ? _check : null,
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(_allAnswered ? 'Check answers' : 'Answer all questions to check'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              )
            else ...[
              Card(
                color: _score == _questions.length ? scheme.primaryContainer : scheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    _score == _questions.length
                        ? 'Perfect! ${_questions.length} / ${_questions.length}'
                        : 'You got $_score / ${_questions.length} right.',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.check),
                      label: const Text('Done'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _questionCard(int i) {
    final q = _questions[i];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final answer = _answers[i];
    final correct = _checked && answer != null && q.isCorrect(answer);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${i + 1}. ${q.prompt}', style: theme.textTheme.bodyLarge),
              if (q.promptTranslation != null && !_english)
                Text(q.promptTranslation!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              if (q.type == QuestionType.choice)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final o in q.options)
                      ChoiceChip(
                        label: Text(o, style: const TextStyle(fontSize: 16)),
                        selected: answer == o,
                        onSelected: _checked ? null : (_) => setState(() => _answers[i] = o),
                      ),
                  ],
                )
              else
                TextField(
                  controller: _controllers[i],
                  enabled: !_checked,
                  style: theme.textTheme.bodyLarge,
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Your answer'),
                  onChanged: (v) => setState(() => _answers[i] = v),
                ),
              if (_checked) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(correct ? Icons.check_circle : Icons.cancel,
                        color: correct ? Colors.green.shade600 : scheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(correct ? 'Correct' : 'Answer: ${q.answer}',
                              style: theme.textTheme.titleMedium),
                          if (q.explanation != null || q.explanationTranslation != null)
                            Text(
                              (_english ? q.explanation : q.explanationTranslation) ??
                                  q.explanation ??
                                  q.explanationTranslation!,
                              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
