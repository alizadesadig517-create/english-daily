import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../logic/streak.dart';
import '../models/lesson.dart';

/// Local storage: cached lessons and daily progress. Everything stays on the
/// device.
class AppDatabase {
  AppDatabase._(this._db);
  final Database _db;

  static AppDatabase? _instance;

  static Future<AppDatabase> open() async {
    if (_instance != null) return _instance!;
    final path = p.join(await getDatabasesPath(), 'english_daily.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE lessons (
            date TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            fetched_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE progress (
            date TEXT PRIMARY KEY,
            words_done INTEGER NOT NULL DEFAULT 0,
            story_done INTEGER NOT NULL DEFAULT 0,
            grammar_done INTEGER NOT NULL DEFAULT 0,
            seconds INTEGER NOT NULL DEFAULT 0,
            completed INTEGER NOT NULL DEFAULT 0
          )''');
      },
    );
    return _instance = AppDatabase._(db);
  }

  Future<void> saveLesson(String date, String json) => _db.insert(
        'lessons',
        {'date': date, 'json': json, 'fetched_at': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<Lesson?> lesson(String date) async {
    final rows = await _db.query('lessons', where: 'date = ?', whereArgs: [date]);
    if (rows.isEmpty) return null;
    try {
      return Lesson.fromJson(jsonDecode(rows.first['json'] as String) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<Set<String>> cachedDates() async {
    final rows = await _db.query('lessons', columns: ['date']);
    return rows.map((r) => r['date'] as String).toSet();
  }

  Future<DayProgress> progress(String date) async {
    final rows = await _db.query('progress', where: 'date = ?', whereArgs: [date]);
    return rows.isEmpty ? DayProgress(date: date) : DayProgress.fromMap(rows.first);
  }

  Future<Map<String, DayProgress>> allProgress() async {
    final rows = await _db.query('progress');
    return {for (final r in rows) r['date'] as String: DayProgress.fromMap(r)};
  }

  Future<void> saveProgress(DayProgress p) =>
      _db.insert('progress', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
}
