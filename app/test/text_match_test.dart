import 'dart:convert';
import 'dart:io';

import 'package:english_daily/logic/text_match.dart';
import 'package:english_daily/models/lesson.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lesson = Lesson.fromJson(
      jsonDecode(File('../content/2026-10-28.json').readAsStringSync()) as Map<String, dynamic>);
  final glossary = lesson.story!.glossary;

  test('tokenize covers the whole text and keeps contractions', () {
    const text = "“Don't rush,” he said.";
    final tokens = tokenize(text);
    expect(tokens.map((t) => t.text).join(), text);
    expect(tokens.where((t) => t.isWord).map((t) => t.text), ["Don't", 'rush', 'he', 'said']);
  });

  test('wordForms handles regular inflections', () {
    expect(isFormOf('rushed', 'rush'), isTrue);
    expect(isFormOf('struggled', 'struggle'), isTrue);
    expect(isFormOf('studies', 'study'), isTrue);
    expect(isFormOf('stopped', 'stop'), isTrue);
    expect(isFormOf('trusting', 'trust'), isTrue);
    expect(isFormOf('rust', 'trust'), isFalse);
  });

  test('lookupWord finds exact terms and lemmas', () {
    expect(lookupWord('Panicked', glossary)?.lemma, 'panic');
    expect(lookupWord('patient', glossary)?.translation, 'səbirli');
    expect(lookupWord('the', glossary), isNull);
  });

  test('phrasesCovering finds the phrase around a tapped word', () {
    const s = 'After three weeks, Murad still couldn\'t swim, and he wanted to give up.';
    final start = s.indexOf('give');
    final found = phrasesCovering(s, start, start + 4, glossary);
    expect(found.map((g) => g.term), contains('give up'));
  });

  test('matchSelection: exact, partial and no match', () {
    expect(matchSelection('No longer', glossary)?.term, 'no longer');
    expect(matchSelection('how far he had', glossary)?.term, 'how far he had come');
    expect(matchSelection('he was no longer', glossary)?.term, 'no longer');
    expect(matchSelection('the water will hold you', glossary), isNull);
  });

  test('new words are recognised in the story, including irregular forms via the glossary', () {
    expect(isNewWordToken('patient', lesson.words, glossary), isTrue);
    expect(isNewWordToken('struggle', lesson.words, glossary), isTrue);
    expect(isNewWordToken('trust', lesson.words, glossary), isTrue);
    expect(isNewWordToken('water', lesson.words, glossary), isFalse);
    const text = 'he wanted to give up.';
    expect(newPhraseRanges(text, lesson.words), [(text.indexOf('give'), text.indexOf('.'))]);
  });
}
