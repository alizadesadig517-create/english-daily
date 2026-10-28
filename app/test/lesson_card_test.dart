import 'dart:convert';
import 'dart:io';

import 'package:english_daily/models/app_settings.dart';
import 'package:english_daily/models/lesson.dart';
import 'package:english_daily/services/lesson_card_html.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lesson card is a self-contained page with every section', () {
    final lesson = Lesson.fromJson(
        jsonDecode(File('../content/2026-10-27.json').readAsStringSync()) as Map<String, dynamic>);
    final html = lessonCardHtml(lesson);
    expect(html, startsWith('<!DOCTYPE html>'));
    expect(html, contains('prefers-color-scheme:dark'));
    expect(html, isNot(contains('<link')));
    expect(html, isNot(contains('<script')));
    for (final w in lesson.words) {
      expect(html, contains(w.word));
    }
    expect(html, contains('The Bicycle at the Fair'));
    expect(html, contains('<mark>borrow</mark>'));
    expect(html, contains('Present perfect or past simple?'));
    // Quotes and apostrophes are escaped.
    expect(html, contains('isn&#39;t'));
  });

  test('settings JSON round trip and content subset', () {
    const s = AppSettings(
      onboardingDone: true,
      level: 'B2',
      notificationTime: TimeOfDay(hour: 7, minute: 45),
      wordsPerDay: 8,
      storyEnabled: false,
      themeMode: ThemeMode.dark,
      firstUseDate: '2026-10-01',
    );
    final again = AppSettings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(again.toJson(), s.toJson());
    expect(s.toContentJson(), {
      'level': 'B2',
      'translationLanguage': 'az',
      'wordsPerDay': 8,
      'storyEnabled': false,
      'minutesPerDay': 15,
    });
    expect(AppSettings.fromJson({'level': 'Z9', 'wordsPerDay': 999}).level, 'B1');
    expect(AppSettings.fromJson({'wordsPerDay': 999}).wordsPerDay, 20);
  });
}
