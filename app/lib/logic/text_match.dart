import '../models/lesson.dart';

/// A piece of story text: either a word (tappable) or the space/punctuation
/// between words.
class Token {
  const Token(this.text, this.start, this.end, {required this.isWord});
  final String text;
  final int start;
  final int end;
  final bool isWord;

  @override
  String toString() => isWord ? 'W($text)' : 'S($text)';
}

final _wordRe = RegExp(r"[A-Za-z0-9]+(?:['’][A-Za-z]+)*(?:-[A-Za-z0-9]+)*");

/// Splits [text] into word and non-word tokens that cover it completely.
List<Token> tokenize(String text) {
  final tokens = <Token>[];
  var pos = 0;
  for (final m in _wordRe.allMatches(text)) {
    if (m.start > pos) {
      tokens.add(Token(text.substring(pos, m.start), pos, m.start, isWord: false));
    }
    tokens.add(Token(m.group(0)!, m.start, m.end, isWord: true));
    pos = m.end;
  }
  if (pos < text.length) {
    tokens.add(Token(text.substring(pos), pos, text.length, isWord: false));
  }
  return tokens;
}

/// Lowercase, straight apostrophes, letters/digits/spaces only.
String normalizeText(String s) => s
    .toLowerCase()
    .replaceAll('’', "'")
    .replaceAll(RegExp(r"[^a-z0-9\s'-]"), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Common inflected forms of an English word (regular rules only; irregular
/// forms are covered by the story glossary's lemma).
Set<String> wordForms(String word) {
  final w = word.toLowerCase().trim();
  final parts = w.split(RegExp(r'\s+'));
  if (parts.length > 1) {
    final rest = parts.sublist(1).join(' ');
    return {for (final f in wordForms(parts.first)) '$f $rest'};
  }
  final forms = <String>{w, '${w}s', '${w}es', '${w}ed', '${w}d', '${w}ing', '${w}er', '${w}est', '${w}ly', "$w's"};
  if (w.endsWith('e')) {
    final stem = w.substring(0, w.length - 1);
    forms.addAll(['${stem}ing', '${stem}ed']);
  }
  if (w.endsWith('y') && w.length > 2) {
    final stem = w.substring(0, w.length - 1);
    forms.addAll(['${stem}ies', '${stem}ied', '${stem}ier', '${stem}iest', '${stem}ily']);
  }
  const vowels = 'aeiou';
  if (w.length >= 3 &&
      !'aeiouwxy'.contains(w[w.length - 1]) &&
      vowels.contains(w[w.length - 2]) &&
      !vowels.contains(w[w.length - 3])) {
    final last = w[w.length - 1];
    forms.addAll(['$w${last}ed', '$w${last}ing', '$w${last}er']);
  }
  return forms;
}

bool isFormOf(String token, String word) =>
    wordForms(word).contains(token.toLowerCase().replaceAll('’', "'"));

/// Glossary entry for a single tapped word: exact term first, then an entry
/// whose lemma this token is a regular form of.
GlossaryEntry? lookupWord(String token, List<GlossaryEntry> glossary) {
  final t = token.toLowerCase().replaceAll('’', "'");
  for (final g in glossary) {
    if (!g.isPhrase && normalizeText(g.term) == t) return g;
  }
  for (final g in glossary) {
    if (!g.isPhrase && isFormOf(t, g.lemma)) return g;
  }
  return null;
}

/// Character ranges where [term] occurs in [text] (case-insensitive, whole
/// words, any whitespace between words).
List<(int, int)> findTerm(String text, String term) {
  final words = normalizeText(term)
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => RegExp.escape(w).replaceAll("'", "['’]"))
      .toList();
  if (words.isEmpty) return const [];
  final pattern = RegExp(
    '(?<![A-Za-z0-9])${words.join(r'[\s,]+')}(?![A-Za-z0-9])',
    caseSensitive: false,
  );
  return pattern.allMatches(text).map((m) => (m.start, m.end)).toList();
}

/// Multi-word glossary entries that cover the character range [start, end)
/// inside [sentence].
List<GlossaryEntry> phrasesCovering(
    String sentence, int start, int end, List<GlossaryEntry> glossary) {
  final out = <GlossaryEntry>[];
  for (final g in glossary) {
    if (!g.isPhrase) continue;
    for (final (s, e) in findTerm(sentence, g.term)) {
      if (s <= start && end <= e) {
        out.add(g);
        break;
      }
    }
  }
  return out;
}

/// Matches a dragged selection to a glossary phrase. Exact match first; then
/// the phrase that contains the selection or is contained in it (largest
/// overlap wins). Returns null when nothing fits.
GlossaryEntry? matchSelection(String selection, List<GlossaryEntry> glossary) {
  final sel = normalizeText(selection);
  if (sel.isEmpty) return null;
  for (final g in glossary) {
    if (normalizeText(g.term) == sel) return g;
  }
  final selWords = sel.split(' ');
  GlossaryEntry? best;
  var bestScore = 0;
  for (final g in glossary) {
    if (!g.isPhrase) continue;
    final term = normalizeText(g.term);
    final termWords = term.split(' ');
    final int score;
    if (' $term '.contains(' $sel ') && selWords.length >= 2) {
      score = selWords.length; // selection is part of the phrase
    } else if (' $sel '.contains(' $term ')) {
      // phrase inside the selection - only if it is most of the selection
      if (termWords.length * 2 < selWords.length) continue;
      score = termWords.length;
    } else {
      continue;
    }
    if (score > bestScore) {
      bestScore = score;
      best = g;
    }
  }
  return best;
}

/// Whether a story token is one of today's new words (regular forms, or an
/// irregular form whose glossary lemma is a new word).
bool isNewWordToken(String token, List<Word> words, List<GlossaryEntry> glossary) {
  final singleWords = words.where((w) => !w.word.contains(' '));
  if (singleWords.any((w) => isFormOf(token, w.word))) return true;
  final g = lookupWord(token, glossary);
  if (g == null) return false;
  return words.any((w) => w.word.toLowerCase() == g.lemma.toLowerCase());
}

/// Character ranges in [text] covered by multi-word new words (e.g. phrasal
/// verbs like "give up"), so they can be highlighted too.
List<(int, int)> newPhraseRanges(String text, List<Word> words) {
  final out = <(int, int)>[];
  for (final w in words.where((w) => w.word.contains(' '))) {
    for (final form in wordForms(w.word)) {
      out.addAll(findTerm(text, form));
    }
  }
  return out;
}
