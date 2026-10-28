import 'dart:convert';
import 'dart:io';

import 'package:english_daily/models/lesson.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _load(String date) =>
    jsonDecode(File('../content/$date.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('sample lessons in content/', () {
    final dates = Directory('../content')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => RegExp(r'^\d{4}-\d{2}-\d{2}\.json$').hasMatch(n))
        .map((n) => n.substring(0, 10))
        .toList()
      ..sort();

    test('all published lessons are present', () => expect(dates.length, greaterThanOrEqualTo(28)));

    for (final date in dates) {
      test('$date parses completely', () {
        final lesson = Lesson.fromJson(_load(date));
        expect(lesson.date, date);
        expect(lesson.level, 'B1');
        expect(lesson.translationLanguage, 'az');
        expect(lesson.words.length, inInclusiveRange(1, 20));
        for (final w in lesson.words) {
          expect(w.ipa, startsWith('/'));
          expect(w.senses, isNotEmpty);
          for (final s in w.senses) {
            expect(s.examples.length, inInclusiveRange(2, 3));
            expect(s.translation, isNotEmpty);
          }
        }
        expect(lesson.story, isNotNull);
        expect(lesson.story!.paragraphs, isNotEmpty);
        expect(lesson.story!.glossary, isNotEmpty);
        expect(lesson.grammar.exercise.questions.length, inInclusiveRange(3, 5));
      });

      test('$date survives a toJson/fromJson round trip', () {
        final original = _load(date);
        final again = Lesson.fromJson(original).toJson();
        expect(jsonEncode(again), jsonEncode(original));
      });
    }
  });

  group('parsing rules', () {
    Map<String, dynamic> minimal() => {
          'schemaVersion': 1,
          'date': '2026-01-02',
          'level': 'A2',
          'translationLanguage': 'az',
          'words': [
            {
              'word': 'apple',
              'ipa': '/ˈæpəl/',
              'senses': [
                {
                  'partOfSpeech': 'noun',
                  'translation': 'alma',
                  'definition': 'a round fruit',
                  'synonyms': [],
                  'antonyms': [],
                  'homonyms': [],
                  'examples': [
                    {'text': 'I eat an apple.', 'translation': 'Mən alma yeyirəm.'},
                    {'text': 'This apple is red.', 'translation': 'Bu alma qırmızıdır.'},
                  ],
                }
              ],
            }
          ],
          'grammar': {
            'topic': 'a',
            'topicTranslation': 'a',
            'explanation': 'e',
            'explanationTranslation': 'e',
            'rules': [
              {'text': 'r', 'translation': 'r'}
            ],
            'examples': [
              {'text': 'x', 'translation': 'y'}
            ],
            'exercise': {
              'instructions': 'i',
              'instructionsTranslation': 'i',
              'questions': [
                {'type': 'text', 'prompt': 'p', 'answer': 'a'}
              ],
            },
          },
        };

    test('story is optional', () {
      final l = Lesson.fromJson(minimal());
      expect(l.story, isNull);
      expect(l.words.single.senses.single.examples, hasLength(2));
    });

    test('missing required field throws a readable error', () {
      final j = minimal()..remove('grammar');
      expect(() => Lesson.fromJson(j),
          throwsA(isA<LessonFormatException>().having((e) => e.message, 'message', contains('grammar'))));
    });

    test('newer schemaVersion is rejected', () {
      final j = minimal()..['schemaVersion'] = 2;
      expect(() => Lesson.fromJson(j), throwsA(isA<LessonFormatException>()));
    });

    test('bad date is rejected', () {
      final j = minimal()..['date'] = '2026/01/02';
      expect(() => Lesson.fromJson(j), throwsA(isA<LessonFormatException>()));
    });

    test('unknown question type is rejected', () {
      final j = minimal();
      ((j['grammar'] as Map)['exercise'] as Map)['questions'] = [
        {'type': 'essay', 'prompt': 'p', 'answer': 'a'}
      ];
      expect(() => Lesson.fromJson(j), throwsA(isA<LessonFormatException>()));
    });
  });

  group('Question.isCorrect', () {
    const q = Question(
      type: QuestionType.text,
      prompt: 'I ___ (call) you.',
      answer: 'will call',
      acceptedAnswers: ["'ll call"],
    );

    test('ignores case, spaces and punctuation', () {
      expect(q.isCorrect('will call'), isTrue);
      expect(q.isCorrect('  Will   Call. '), isTrue);
      expect(q.isCorrect("’ll call"), isTrue);
    });

    test('accepts alternatives and rejects wrong answers', () {
      expect(q.isCorrect("'ll call"), isTrue);
      expect(q.isCorrect('called'), isFalse);
      expect(q.isCorrect(''), isFalse);
    });
  });
}
