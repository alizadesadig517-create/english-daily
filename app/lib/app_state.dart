import 'dart:async';

import 'package:flutter/widgets.dart';

import 'data/database.dart';
import 'data/lesson_repository.dart';
import 'data/settings_store.dart';
import 'logic/dates.dart';
import 'logic/schedule.dart';
import 'logic/streak.dart';
import 'models/app_settings.dart';
import 'models/lesson.dart';
import 'services/background.dart';
import 'services/notification_service.dart';

enum LoadState { loading, ready, notPublished, error }

enum Section { words, story, grammar }

/// App-wide state shared through Provider.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState(this.db, this.store) : repo = LessonRepository(db, store);

  final AppDatabase db;
  final SettingsStore store;
  final LessonRepository repo;

  AppSettings settings = const AppSettings();
  bool hasToken = false;
  DateTime? snoozedUntil;

  String today = '';
  LoadState todayState = LoadState.loading;
  Lesson? todayLesson;
  String? todayError;
  late DayProgress todayProgress;

  List<String> availableDates = const [];
  Map<String, DayProgress> progressByDate = const {};

  /// Selected bottom-navigation tab (0 = Today).
  int tab = 0;

  void setTab(int i) {
    tab = i;
    notifyListeners();
  }

  /// Called once when today's goal is reached (the UI shows a message).
  VoidCallback? onDayCompleted;

  // ---------------------------------------------------------------- startup

  Future<void> init() async {
    settings = await store.load();
    hasToken = await store.token() != null;
    snoozedUntil = await store.snoozedUntil();
    today = lessonToday();
    todayProgress = await db.progress(today);
    todayLesson = await db.lesson(today);
    todayState = todayLesson != null ? LoadState.ready : LoadState.loading;
    progressByDate = await db.allProgress();
    availableDates = await repo.availableDates(settings, refresh: false);
    WidgetsBinding.instance.addObserver(this);
  }

  /// Called after the first frame: refresh content and schedules.
  Future<void> onAppOpened() async {
    if (!settings.onboardingDone) return;
    unawaited(loadToday());
    unawaited(refreshDates());
    await _rescheduleAll();
  }

  Future<void> _rescheduleAll() async {
    try {
      await NotificationService.reschedule(settings, snoozedUntil);
      await Background.schedulePrefetch(settings);
    } catch (e) {
      debugPrint('Scheduling failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) {
      _checkDayRollover();
      if (todayState != LoadState.ready) unawaited(loadToday());
    } else {
      unawaited(_persistProgress());
    }
    _updateTicker();
  }

  // ---------------------------------------------------------------- lessons

  Future<void> loadToday({bool force = false}) async {
    if (todayLesson == null) {
      todayState = LoadState.loading;
      notifyListeners();
    }
    final r = await repo.get(today, settings, force: force);
    switch (r.status) {
      case FetchStatus.ok:
        todayLesson = r.lesson;
        todayState = LoadState.ready;
        todayError = null;
      case FetchStatus.notPublished:
        todayState = LoadState.notPublished;
      case FetchStatus.error:
        todayState = LoadState.error;
        todayError = r.message;
    }
    notifyListeners();
  }

  Future<void> refreshDates() async {
    availableDates = await repo.availableDates(settings);
    notifyListeners();
  }

  Future<void> refreshProgress() async {
    progressByDate = await db.allProgress();
    notifyListeners();
  }

  void _checkDayRollover() {
    final now = lessonToday();
    if (now == today) return;
    unawaited(_persistProgress());
    today = now;
    todayLesson = null;
    todayState = LoadState.loading;
    unawaited(() async {
      todayProgress = await db.progress(today);
      await refreshProgress();
      await loadToday();
    }());
  }

  bool get todayHasStory => todayLesson?.story != null;

  // ---------------------------------------------------------------- settings

  Future<void> completeOnboarding(AppSettings s) async {
    settings = s.copyWith(onboardingDone: true, firstUseDate: settings.firstUseDate ?? today);
    await store.save(settings);
    notifyListeners();
    await NotificationService.requestPermissions();
    await _rescheduleAll();
    unawaited(loadToday());
    unawaited(refreshDates());
    if (hasToken) {
      try {
        await repo.pushContentSettings(settings);
      } catch (_) {}
    }
  }

  /// Saves settings. Returns a message about syncing config/settings.json
  /// to GitHub when content settings changed (null when nothing to report).
  Future<String?> saveSettings(AppSettings s) async {
    final old = settings;
    settings = s;
    await store.save(s);
    notifyListeners();
    if (old.notificationTime != s.notificationTime) await _rescheduleAll();
    if (old.repoOwner != s.repoOwner || old.repoName != s.repoName || old.branch != s.branch) {
      unawaited(loadToday(force: true));
      unawaited(refreshDates());
    }
    if (old.minutesPerDay != s.minutesPerDay) _checkCompletion();
    if (!old.sameContentSettings(s)) return syncContentSettings();
    return null;
  }

  Future<String> syncContentSettings() async {
    if (!hasToken) {
      return 'Saved on this phone. To change the lessons themselves, edit config/settings.json on GitHub (or add a token in Settings).';
    }
    try {
      await repo.pushContentSettings(settings);
      return 'Saved. config/settings.json on GitHub was updated - new lessons will use it.';
    } catch (e) {
      return 'Saved on this phone, but GitHub update failed: $e';
    }
  }

  Future<void> setToken(String? token) async {
    await store.setToken(token);
    hasToken = await store.token() != null;
    notifyListeners();
    unawaited(loadToday(force: true));
    unawaited(refreshDates());
  }

  DateTime get nextReminder => nextNotification(DateTime.now(),
      settings.notificationTime.hour, settings.notificationTime.minute, snoozedUntil);

  Future<void> snooze(DateTime until) async {
    snoozedUntil = until;
    await store.setSnoozedUntil(until);
    notifyListeners();
    await NotificationService.reschedule(settings, until);
  }

  Future<void> cancelSnooze() async {
    snoozedUntil = null;
    await store.setSnoozedUntil(null);
    notifyListeners();
    await NotificationService.reschedule(settings, null);
  }

  // ---------------------------------------------------------------- progress

  Future<void> markSection(Section section) async {
    todayProgress = switch (section) {
      Section.words => todayProgress.copyWith(wordsDone: true),
      Section.story => todayProgress.copyWith(storyDone: true),
      Section.grammar => todayProgress.copyWith(grammarDone: true),
    };
    _checkCompletion();
    await _persistProgress();
    notifyListeners();
  }

  bool isSectionDone(Section s) => switch (s) {
        Section.words => todayProgress.wordsDone,
        Section.story => todayProgress.storyDone,
        Section.grammar => todayProgress.grammarDone,
      };

  void _checkCompletion() {
    if (todayProgress.completed || todayLesson == null) return;
    if (todayProgress.meetsGoal(minutesPerDay: settings.minutesPerDay, hasStory: todayHasStory)) {
      todayProgress = todayProgress.copyWith(completed: true);
      unawaited(_persistProgress());
      if (snoozedUntil != null) unawaited(cancelSnooze());
      onDayCompleted?.call();
    }
  }

  Future<void> _persistProgress() async {
    if (today.isEmpty) return;
    await db.saveProgress(todayProgress);
    progressByDate = {...progressByDate, today: todayProgress};
  }

  Streaks get streaks => computeStreaks(
      progressByDate.values.where((p) => p.completed).map((p) => p.date), today);

  // ---------------------------------------------------------------- timer

  int _studyScreens = 0;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  Timer? _ticker;
  int _unsaved = 0;

  /// Today's lesson screens call these so time is only counted while the
  /// lesson is open and the app is in the foreground.
  void enterStudy() {
    _studyScreens++;
    _updateTicker();
  }

  void leaveStudy() {
    _studyScreens = (_studyScreens - 1).clamp(0, 1 << 30);
    _updateTicker();
    unawaited(_persistProgress());
  }

  void _updateTicker() {
    final run = _studyScreens > 0 && _lifecycle == AppLifecycleState.resumed;
    if (run && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else if (!run && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  void _tick() {
    if (lessonToday() != today) {
      _checkDayRollover();
      return;
    }
    todayProgress = todayProgress.copyWith(seconds: todayProgress.seconds + 1);
    _checkCompletion();
    if (++_unsaved >= 10) {
      _unsaved = 0;
      unawaited(_persistProgress());
    }
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }
}
