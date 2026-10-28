import 'dart:convert';

import '../models/app_settings.dart';
import '../models/lesson.dart';
import 'database.dart';
import 'github_client.dart';
import 'settings_store.dart';

enum FetchStatus { ok, notPublished, error }

class FetchResult {
  const FetchResult(this.status, {this.lesson, this.message});
  final FetchStatus status;
  final Lesson? lesson;
  final String? message;
}

/// Downloads lessons from GitHub and caches them in the local database so
/// they work offline.
class LessonRepository {
  LessonRepository(this.db, this.store);
  final AppDatabase db;
  final SettingsStore store;

  Future<GitHubClient> _client(AppSettings s) async => GitHubClient(
        owner: s.repoOwner.trim(),
        repo: s.repoName.trim(),
        branch: s.branch.trim().isEmpty ? 'main' : s.branch.trim(),
        token: await store.token(),
      );

  Future<Lesson?> cached(String date) => db.lesson(date);

  /// Cached lesson if present (unless [force]), otherwise downloads it.
  Future<FetchResult> get(String date, AppSettings settings, {bool force = false}) async {
    if (!force) {
      final c = await db.lesson(date);
      if (c != null) return FetchResult(FetchStatus.ok, lesson: c);
    }
    try {
      final client = await _client(settings);
      final body = await client.getFile('content/$date.json');
      if (body == null) {
        final c = await db.lesson(date);
        if (c != null) return FetchResult(FetchStatus.ok, lesson: c);
        return const FetchResult(FetchStatus.notPublished);
      }
      final lesson = Lesson.fromJson(jsonDecode(body) as Map<String, dynamic>);
      await db.saveLesson(date, body);
      return FetchResult(FetchStatus.ok, lesson: lesson);
    } catch (e) {
      final c = await db.lesson(date);
      if (c != null) return FetchResult(FetchStatus.ok, lesson: c, message: e.toString());
      return FetchResult(FetchStatus.error, message: e.toString());
    }
  }

  /// Refreshes the list of published dates (content/index.json), newest first.
  /// Falls back to the last known list when offline.
  Future<List<String>> availableDates(AppSettings settings, {bool refresh = true}) async {
    final known = await store.availableDates();
    final cached = await db.cachedDates();
    var dates = known;
    if (refresh) {
      try {
        final body = await (await _client(settings)).getFile('content/index.json');
        if (body != null) {
          final j = jsonDecode(body);
          final list = (j is Map ? j['dates'] : j) as List;
          dates = list.map((e) => e.toString()).toList();
          await store.setAvailableDates(dates);
        }
      } catch (_) {
        // offline - keep what we know
      }
    }
    final all = {...dates, ...cached}.toList()..sort((a, b) => b.compareTo(a));
    return all;
  }

  /// Writes the content settings to config/settings.json in the repo.
  Future<void> pushContentSettings(AppSettings settings) async {
    final client = await _client(settings);
    const encoder = JsonEncoder.withIndent('  ');
    await client.putFile(
      'config/settings.json',
      '${encoder.convert(settings.toContentJson())}\n',
      'Update learner settings from the app',
    );
  }
}
