import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../logic/text_match.dart';
import '../models/lesson.dart';
import '../services/tts_service.dart';
import 'widgets.dart';

class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key, required this.lesson, required this.isToday});
  final Lesson lesson;
  final bool isToday;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  bool _showTranslations = false;

  Future<void> _finish() async {
    if (widget.isToday) await context.read<AppState>().markSection(Section.story);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.lesson.story!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return StudyScope(
      active: widget.isToday,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Story'),
          actions: [
            IconButton(
              tooltip: _showTranslations ? 'Hide translations' : 'Show translations',
              isSelected: _showTranslations,
              icon: const Icon(Icons.translate),
              onPressed: () => setState(() => _showTranslations = !_showTranslations),
            ),
            if (widget.isToday) const TimerChip(),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(story.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            Text(story.titleTranslation,
                style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('Tap a word to see its meaning. Long-press and drag to select a phrase.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            for (final p in story.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _showTranslations
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final s in p.sentences)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StoryText(sentences: [s], lesson: widget.lesson),
                                  Text(s.translation,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                          color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                        ],
                      )
                    : StoryText(sentences: p.sentences, lesson: widget.lesson),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _finish,
              icon: const Icon(Icons.check),
              label: Text(widget.isToday ? "I've read the story" : 'Close'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A block of story sentences rendered as one paragraph. Every word is
/// tappable; long-press + drag selects a phrase.
class StoryText extends StatefulWidget {
  const StoryText({super.key, required this.sentences, required this.lesson});
  final List<Translated> sentences;
  final Lesson lesson;

  @override
  State<StoryText> createState() => _StoryTextState();
}

class _StoryTextState extends State<StoryText> {
  final _key = GlobalKey();
  late String _text;
  late List<int> _sentenceStarts;
  late List<Token> _tokens;
  late Set<int> _newWordTokens;
  int? _selStart; // token indexes, inclusive
  int? _selEnd;
  int? _anchor;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(StoryText old) {
    super.didUpdateWidget(old);
    if (old.sentences != widget.sentences) _prepare();
  }

  void _prepare() {
    final buf = StringBuffer();
    _sentenceStarts = [];
    for (final s in widget.sentences) {
      if (buf.isNotEmpty) buf.write(' ');
      _sentenceStarts.add(buf.length);
      buf.write(s.text);
    }
    _text = buf.toString();
    _tokens = tokenize(_text);
    final glossary = widget.lesson.story?.glossary ?? const <GlossaryEntry>[];
    final phraseRanges = newPhraseRanges(_text, widget.lesson.words);
    _newWordTokens = {
      for (var i = 0; i < _tokens.length; i++)
        if (_tokens[i].isWord &&
            (isNewWordToken(_tokens[i].text, widget.lesson.words, glossary) ||
                phraseRanges.any((r) => r.$1 <= _tokens[i].start && _tokens[i].end <= r.$2)))
          i,
    };
  }

  int _sentenceAt(int charIndex) {
    var idx = 0;
    for (var i = 0; i < _sentenceStarts.length; i++) {
      if (_sentenceStarts[i] <= charIndex) idx = i;
    }
    return idx;
  }

  /// Index of the word token under [local], or null.
  int? _tokenAt(Offset local) {
    final render = _key.currentContext?.findRenderObject();
    if (render is! RenderParagraph) return null;
    final pos = render.getPositionForOffset(local).offset;
    for (var i = 0; i < _tokens.length; i++) {
      final t = _tokens[i];
      if (pos >= t.start && pos <= t.end && t.isWord) return i;
      if (pos < t.start) break;
    }
    // Between words: take the nearest word token.
    int? best;
    var bestDist = 1 << 30;
    for (var i = 0; i < _tokens.length; i++) {
      if (!_tokens[i].isWord) continue;
      final d = pos < _tokens[i].start ? _tokens[i].start - pos : pos - _tokens[i].end;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return bestDist <= 1 ? best : null;
  }

  void _onTap(TapUpDetails d) {
    final i = _tokenAt(d.localPosition);
    if (i == null) return;
    final token = _tokens[i];
    final sentence = widget.sentences[_sentenceAt(token.start)];
    final localStart = token.start - _sentenceStarts[_sentenceAt(token.start)];
    final glossary = widget.lesson.story?.glossary ?? const <GlossaryEntry>[];
    setState(() => _selStart = _selEnd = i);
    _showSheet(
      _WordSheet(
        token: token.text,
        entry: lookupWord(token.text, glossary),
        phrases: phrasesCovering(sentence.text, localStart, localStart + token.text.length, glossary),
        newWord: _newWordTokens.contains(i) ? _findNewWord(token.text) : null,
        sentences: [sentence],
      ),
    );
  }

  Word? _findNewWord(String token) {
    final glossary = widget.lesson.story?.glossary ?? const <GlossaryEntry>[];
    final entry = lookupWord(token, glossary);
    for (final w in widget.lesson.words) {
      if (isFormOf(token, w.word) || (entry != null && entry.lemma.toLowerCase() == w.word.toLowerCase())) {
        return w;
      }
    }
    return null;
  }

  void _onLongPressStart(LongPressStartDetails d) {
    final i = _tokenAt(d.localPosition);
    if (i == null) return;
    setState(() {
      _anchor = i;
      _selStart = _selEnd = i;
    });
  }

  void _onLongPressMove(LongPressMoveUpdateDetails d) {
    if (_anchor == null) return;
    final i = _tokenAt(d.localPosition);
    if (i == null) return;
    setState(() {
      _selStart = i < _anchor! ? i : _anchor;
      _selEnd = i < _anchor! ? _anchor : i;
    });
  }

  void _onLongPressEnd(LongPressEndDetails d) {
    if (_selStart == null || _selEnd == null) return;
    final start = _tokens[_selStart!].start;
    final end = _tokens[_selEnd!].end;
    final selected = _text.substring(start, end);
    final glossary = widget.lesson.story?.glossary ?? const <GlossaryEntry>[];
    final involved = <Translated>[
      for (var s = _sentenceAt(start); s <= _sentenceAt(end - 1); s++) widget.sentences[s],
    ];
    _anchor = null;
    if (_selStart == _selEnd) {
      // A long-press on one word works like a tap.
      final token = _tokens[_selStart!];
      final localStart = token.start - _sentenceStarts[_sentenceAt(token.start)];
      _showSheet(_WordSheet(
        token: token.text,
        entry: lookupWord(token.text, glossary),
        phrases: phrasesCovering(involved.first.text, localStart, localStart + token.text.length, glossary),
        newWord: _newWordTokens.contains(_selStart) ? _findNewWord(token.text) : null,
        sentences: involved,
      ));
      return;
    }
    _showSheet(_PhraseSheet(selection: selected, entry: matchSelection(selected, glossary), sentences: involved));
  }

  Future<void> _showSheet(Widget sheet) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), child: sheet),
      ),
    );
    if (mounted) setState(() => _selStart = _selEnd = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.textTheme.bodyLarge!.copyWith(fontSize: 20, height: 1.6);
    final newStyle = TextStyle(
      backgroundColor: scheme.tertiaryContainer,
      color: scheme.onTertiaryContainer,
      fontWeight: FontWeight.w600,
    );
    final selStyle = TextStyle(backgroundColor: scheme.primary.withValues(alpha: 0.35));
    final spans = <TextSpan>[];
    for (var i = 0; i < _tokens.length; i++) {
      final selected = _selStart != null && i >= _selStart! && i <= _selEnd!;
      var style = _newWordTokens.contains(i) ? newStyle : null;
      if (selected) style = (style ?? const TextStyle()).merge(selStyle);
      spans.add(TextSpan(text: _tokens[i].text, style: style));
    }
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          TapGestureRecognizer.new,
          (r) => r.onTapUp = _onTap,
        ),
        LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(duration: const Duration(milliseconds: 350)),
          (r) => r
            ..onLongPressStart = _onLongPressStart
            ..onLongPressMoveUpdate = _onLongPressMove
            ..onLongPressEnd = _onLongPressEnd,
        ),
      },
      child: RichText(
        key: _key,
        textScaler: MediaQuery.textScalerOf(context),
        text: TextSpan(style: base, children: spans),
      ),
    );
  }
}

class _SentenceTranslations extends StatelessWidget {
  const _SentenceTranslations(this.sentences);
  final List<Translated> sentences;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(sentences.length == 1 ? 'Sentence' : 'Sentences'),
          for (final s in sentences) TranslatedText(s.text, s.translation),
        ],
      );
}

class _EntryView extends StatelessWidget {
  const _EntryView(this.entry);
  final GlossaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Chip(label: Text(entry.partOfSpeech), visualDensity: VisualDensity.compact),
            if (entry.lemma.toLowerCase() != entry.term.toLowerCase())
              Text('from "${entry.lemma}"', style: theme.textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: 6),
        Text(entry.translation, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(entry.meaning, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
          IconButton.filledTonal(
            tooltip: 'Pronounce',
            onPressed: () => TtsService.speak(text),
            icon: const Icon(Icons.volume_up),
          ),
        ],
      );
}

class _WordSheet extends StatelessWidget {
  const _WordSheet({
    required this.token,
    required this.entry,
    required this.phrases,
    required this.newWord,
    required this.sentences,
  });

  final String token;
  final GlossaryEntry? entry;
  final List<GlossaryEntry> phrases;
  final Word? newWord;
  final List<Translated> sentences;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(token),
        if (newWord != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Chip(
              avatar: const Icon(Icons.star, size: 18),
              label: Text("Today's word: ${newWord!.word}"),
              visualDensity: VisualDensity.compact,
            ),
          ),
        if (entry != null)
          _EntryView(entry!)
        else if (newWord != null)
          Text(newWord!.senses.map((s) => '${s.partOfSpeech}: ${s.translation}').join('\n'),
              style: theme.textTheme.titleMedium)
        else
          Text('A common word - see the sentence translation below.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        if (phrases.isNotEmpty) ...[
          const SectionTitle('Part of a phrase'),
          for (final p in phrases)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TranslatedText('${p.term} – ${p.meaning}', p.translation),
            ),
        ],
        _SentenceTranslations(sentences),
      ],
    );
  }
}

class _PhraseSheet extends StatelessWidget {
  const _PhraseSheet({required this.selection, required this.entry, required this.sentences});
  final String selection;
  final GlossaryEntry? entry;
  final List<Translated> sentences;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(entry?.term ?? selection),
        if (entry != null)
          _EntryView(entry!)
        else
          Text('This selection is not a set phrase. Here is the translation of the sentence.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        _SentenceTranslations(sentences),
      ],
    );
  }
}
