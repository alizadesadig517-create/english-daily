import '../logic/dates.dart';
import '../logic/text_match.dart';
import '../models/app_settings.dart';
import '../models/lesson.dart';

String _e(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

const _css = '''
:root{--bg:#f6f4ef;--card:#ffffff;--text:#1f2328;--muted:#5d6570;--accent:#2f6f5e;--accent-soft:#e3f1ec;--mark:#fff1b8;--line:#e3e0d8}
@media (prefers-color-scheme:dark){:root{--bg:#14171a;--card:#1e2226;--text:#e8eaed;--muted:#a3abb5;--accent:#7cc7b0;--accent-soft:#22352f;--mark:#5a4b12;--line:#30363d}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:17px/1.6 -apple-system,"Segoe UI",Roboto,"Noto Sans",sans-serif;-webkit-print-color-adjust:exact;print-color-adjust:exact}
main{max-width:760px;margin:0 auto;padding:20px 16px 40px}
header{background:var(--accent);color:#fff;border-radius:20px;padding:22px 22px 18px;margin-bottom:18px}
@media (prefers-color-scheme:dark){header{color:#0e1512}}
header h1{margin:0 0 4px;font-size:26px;line-height:1.25}
header .meta{opacity:.9;font-size:15px}
section{background:var(--card);border:1px solid var(--line);border-radius:18px;padding:18px 18px 10px;margin-bottom:16px;break-inside:avoid-page}
h2{margin:0 0 12px;font-size:21px;color:var(--accent)}
h3{margin:0;font-size:22px}
.word{border-top:1px solid var(--line);padding:14px 0 6px}
.word:first-of-type{border-top:0;padding-top:0}
.ipa{color:var(--muted);font-size:16px;margin-left:6px}
.sense{margin:10px 0 8px;padding-left:12px;border-left:3px solid var(--accent-soft)}
.pos{display:inline-block;background:var(--accent-soft);color:var(--accent);border-radius:999px;padding:1px 10px;font-size:13px;font-weight:600;margin-right:6px}
.tr{font-weight:600}
.def{margin:4px 0}
.small{font-size:14px;color:var(--muted)}
.label{font-weight:600;color:var(--text)}
ul{margin:6px 0 10px;padding-left:20px}
li{margin:3px 0}
.t{display:block;color:var(--muted);font-size:15px}
.story p{margin:0 0 14px}
.sent{display:block;margin-bottom:6px}
mark{background:var(--mark);color:inherit;border-radius:4px;padding:0 2px}
table{width:100%;border-collapse:collapse;font-size:15px;margin-bottom:10px}
td,th{border-top:1px solid var(--line);padding:6px 6px;text-align:left;vertical-align:top}
th{color:var(--muted);font-weight:600}
.expl{white-space:pre-line}
ol{padding-left:22px}
.answers{font-size:15px;color:var(--muted)}
footer{text-align:center;color:var(--muted);font-size:13px;margin-top:20px}
''';

String _translated(Translated t) =>
    '<li>${_e(t.text)}<span class="t">${_e(t.translation)}</span></li>';

String _highlightNewWords(String text, Lesson lesson) {
  final glossary = lesson.story?.glossary ?? const <GlossaryEntry>[];
  final phrases = newPhraseRanges(text, lesson.words);
  final buf = StringBuffer();
  for (final t in tokenize(text)) {
    final inPhrase = phrases.any((r) => r.$1 <= t.start && t.end <= r.$2);
    if (t.isWord && (inPhrase || isNewWordToken(t.text, lesson.words, glossary))) {
      buf.write('<mark>${_e(t.text)}</mark>');
    } else {
      buf.write(_e(t.text));
    }
  }
  return buf.toString();
}

/// A self-contained HTML page ("lesson card") for sharing and printing.
/// Inline CSS only, readable in light and dark mode.
String lessonCardHtml(Lesson lesson) {
  final lang = languageName(lesson.translationLanguage);
  final b = StringBuffer()
    ..write('<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">')
    ..write('<meta name="viewport" content="width=device-width,initial-scale=1">')
    ..write('<meta name="color-scheme" content="light dark">')
    ..write('<title>English Daily - ${_e(lesson.date)}</title><style>$_css</style></head><body><main>')
    ..write('<header><h1>English Daily</h1><div class="meta">${_e(prettyDate(lesson.date))} &middot; '
        'Level ${_e(lesson.level)} &middot; English &rarr; ${_e(lang)}</div></header>');

  // Words
  b.write('<section><h2>New words</h2>');
  for (final w in lesson.words) {
    b.write('<div class="word"><h3>${_e(w.word)}<span class="ipa">${_e(w.ipa)}</span></h3>');
    for (final s in w.senses) {
      b.write('<div class="sense"><span class="pos">${_e(s.partOfSpeech)}</span>'
          '<span class="tr">${_e(s.translation)}</span>'
          '<div class="def">${_e(s.definition)}</div>');
      if (s.synonyms.isNotEmpty) {
        b.write('<div class="small"><span class="label">Synonyms:</span> ${_e(s.synonyms.join(', '))}</div>');
      }
      if (s.antonyms.isNotEmpty) {
        b.write('<div class="small"><span class="label">Antonyms:</span> ${_e(s.antonyms.join(', '))}</div>');
      }
      if (s.homonyms.isNotEmpty) {
        b.write('<div class="small"><span class="label">Homonyms:</span> ');
        b.write(s.homonyms
            .map((h) => '${_e(h.word)} &ndash; ${_e(h.meaning)} (${_e(h.translation)})')
            .join('; '));
        b.write('</div>');
      }
      b.write('<ul>${s.examples.map(_translated).join()}</ul></div>');
    }
    b.write('</div>');
  }
  b.write('</section>');

  // Story
  final story = lesson.story;
  if (story != null) {
    b.write('<section class="story"><h2>Story: ${_e(story.title)}</h2>'
        '<p class="small">${_e(story.titleTranslation)}</p>');
    for (final p in story.paragraphs) {
      b.write('<p>');
      for (final s in p.sentences) {
        b.write('<span class="sent">${_highlightNewWords(s.text, lesson)}'
            '<span class="t">${_e(s.translation)}</span></span>');
      }
      b.write('</p>');
    }
    b.write('<table><tr><th>Word / phrase</th><th>Meaning</th><th>$lang</th></tr>');
    for (final g in story.glossary) {
      b.write('<tr><td><b>${_e(g.term)}</b><br><span class="small">${_e(g.partOfSpeech)}</span></td>'
          '<td>${_e(g.meaning)}</td><td>${_e(g.translation)}</td></tr>');
    }
    b.write('</table></section>');
  }

  // Grammar
  final g = lesson.grammar;
  b.write('<section><h2>Grammar: ${_e(g.topic)}</h2>'
      '<p class="small">${_e(g.topicTranslation)}</p>'
      '<p class="expl">${_e(g.explanation)}</p>'
      '<p class="expl small">${_e(g.explanationTranslation)}</p>'
      '<b>Rules</b><ul>${g.rules.map(_translated).join()}</ul>'
      '<b>Examples</b><ul>${g.examples.map(_translated).join()}</ul>'
      '<b>Exercise</b><p class="small">${_e(g.exercise.instructions)}</p><ol>');
  for (final q in g.exercise.questions) {
    b.write('<li>${_e(q.prompt)}');
    if (q.options.isNotEmpty) {
      b.write('<span class="t">${q.options.map(_e).join(' / ')}</span>');
    }
    b.write('</li>');
  }
  b.write('</ol><p class="answers"><b>Answers:</b> ');
  b.write([
    for (var i = 0; i < g.exercise.questions.length; i++)
      '${i + 1}. ${_e(g.exercise.questions[i].answer)}'
  ].join(' &middot; '));
  b.write('</p></section>');

  b.write('<footer>English Daily &middot; ${_e(lesson.date)}</footer></main></body></html>');
  return b.toString();
}
