import 'package:flutter/material.dart';

const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

const levelDescriptions = {
  'A1': 'Beginner',
  'A2': 'Elementary',
  'B1': 'Intermediate',
  'B2': 'Upper intermediate',
  'C1': 'Advanced',
  'C2': 'Proficient',
};

/// Translation languages offered in onboarding. The routine can generate any
/// of them; Azerbaijani is the default.
const translationLanguages = {
  'az': 'Azerbaijani',
  'ru': 'Russian',
  'tr': 'Turkish',
  'de': 'German',
  'fr': 'French',
  'es': 'Spanish',
  'it': 'Italian',
  'pt': 'Portuguese',
  'uk': 'Ukrainian',
  'ar': 'Arabic',
  'fa': 'Persian',
  'zh': 'Chinese',
  'ja': 'Japanese',
  'ko': 'Korean',
};

String languageName(String code) => translationLanguages[code] ?? code;

/// Everything the user chooses. Saved on the device; the "content" part
/// ([toContentJson]) is what config/settings.json in the repo contains.
@immutable
class AppSettings {
  const AppSettings({
    this.onboardingDone = false,
    this.level = 'B1',
    this.translationLanguage = 'az',
    this.notificationTime = const TimeOfDay(hour: 9, minute: 0),
    this.minutesPerDay = 15,
    this.wordsPerDay = 5,
    this.storyEnabled = true,
    this.themeMode = ThemeMode.system,
    this.repoOwner = 'alizadesadig517-create',
    this.repoName = 'english-daily',
    this.branch = 'main',
    this.firstUseDate,
  });

  final bool onboardingDone;
  final String level;
  final String translationLanguage;
  final TimeOfDay notificationTime;
  final int minutesPerDay;
  final int wordsPerDay;
  final bool storyEnabled;
  final ThemeMode themeMode;
  final String repoOwner;
  final String repoName;
  final String branch;

  /// First day the app was used (YYYY-MM-DD). Days before it are never "missed".
  final String? firstUseDate;

  AppSettings copyWith({
    bool? onboardingDone,
    String? level,
    String? translationLanguage,
    TimeOfDay? notificationTime,
    int? minutesPerDay,
    int? wordsPerDay,
    bool? storyEnabled,
    ThemeMode? themeMode,
    String? repoOwner,
    String? repoName,
    String? branch,
    String? firstUseDate,
  }) =>
      AppSettings(
        onboardingDone: onboardingDone ?? this.onboardingDone,
        level: level ?? this.level,
        translationLanguage: translationLanguage ?? this.translationLanguage,
        notificationTime: notificationTime ?? this.notificationTime,
        minutesPerDay: minutesPerDay ?? this.minutesPerDay,
        wordsPerDay: wordsPerDay ?? this.wordsPerDay,
        storyEnabled: storyEnabled ?? this.storyEnabled,
        themeMode: themeMode ?? this.themeMode,
        repoOwner: repoOwner ?? this.repoOwner,
        repoName: repoName ?? this.repoName,
        branch: branch ?? this.branch,
        firstUseDate: firstUseDate ?? this.firstUseDate,
      );

  /// The fields the daily content routine reads (config/settings.json).
  Map<String, dynamic> toContentJson() => {
        'level': level,
        'translationLanguage': translationLanguage,
        'wordsPerDay': wordsPerDay,
        'storyEnabled': storyEnabled,
        'minutesPerDay': minutesPerDay,
      };

  bool sameContentSettings(AppSettings other) =>
      level == other.level &&
      translationLanguage == other.translationLanguage &&
      wordsPerDay == other.wordsPerDay &&
      storyEnabled == other.storyEnabled &&
      minutesPerDay == other.minutesPerDay;

  Map<String, dynamic> toJson() => {
        ...toContentJson(),
        'onboardingDone': onboardingDone,
        'notificationHour': notificationTime.hour,
        'notificationMinute': notificationTime.minute,
        'themeMode': themeMode.name,
        'repoOwner': repoOwner,
        'repoName': repoName,
        'branch': branch,
        'firstUseDate': firstUseDate,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    const d = AppSettings();
    T pick<T>(String key, T fallback) {
      final v = j[key];
      return v is T ? v : fallback;
    }

    final level = pick<String>('level', d.level);
    return AppSettings(
      onboardingDone: pick('onboardingDone', d.onboardingDone),
      level: levels.contains(level) ? level : d.level,
      translationLanguage: pick('translationLanguage', d.translationLanguage),
      notificationTime: TimeOfDay(
        hour: pick<int>('notificationHour', d.notificationTime.hour).clamp(0, 23),
        minute:
            pick<int>('notificationMinute', d.notificationTime.minute).clamp(0, 59),
      ),
      minutesPerDay: pick<int>('minutesPerDay', d.minutesPerDay).clamp(1, 240),
      wordsPerDay: pick<int>('wordsPerDay', d.wordsPerDay).clamp(1, 20),
      storyEnabled: pick('storyEnabled', d.storyEnabled),
      themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == j['themeMode'],
          orElse: () => d.themeMode),
      repoOwner: pick('repoOwner', d.repoOwner),
      repoName: pick('repoName', d.repoName),
      branch: pick('branch', d.branch),
      firstUseDate: j['firstUseDate'] as String?,
    );
  }
}
