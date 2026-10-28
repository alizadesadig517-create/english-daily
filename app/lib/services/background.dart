import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../data/database.dart';
import '../data/lesson_repository.dart';
import '../data/settings_store.dart';
import '../logic/dates.dart';
import '../logic/schedule.dart';
import '../models/app_settings.dart';
import 'notification_service.dart';

/// Background work (workmanager):
///  * "prefetch"   one-off, one hour before the reminder: download today's lesson
///  * "periodic"   every few hours: download if missing + reschedule (safety net)
///  * "reschedule" sent by TimeChangeReceiver.kt after reboot / clock / zone change
class Background {
  static const prefetchTask = 'prefetch';
  static const periodicTask = 'periodic';
  static const rescheduleTask = 'reschedule';

  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      'periodic-sync',
      periodicTask,
      frequency: const Duration(hours: 4),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  /// Schedules the next prefetch for one hour before the next reminder.
  static Future<void> schedulePrefetch(AppSettings s) async {
    if (!s.onboardingDone) return;
    final now = DateTime.now();
    final at = nextPrefetch(now, s.notificationTime.hour, s.notificationTime.minute);
    await Workmanager().registerOneOffTask(
      'daily-prefetch',
      prefetchTask,
      initialDelay: at.difference(now),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  /// Shared by every task: fetch today's lesson if needed, then make sure the
  /// reminder and next prefetch are scheduled.
  static Future<bool> run(String task) async {
    final store = SettingsStore();
    final settings = await store.load();
    if (!settings.onboardingDone) return true;
    await NotificationService.initTimeZones();
    await NotificationService.init();
    var ok = true;
    try {
      final repo = LessonRepository(await AppDatabase.open(), store);
      final result = await repo.get(lessonToday(), settings);
      if (result.status == FetchStatus.error) ok = false;
      await repo.availableDates(settings);
    } catch (e) {
      debugPrint('Background fetch failed: $e');
      ok = false;
    }
    await NotificationService.reschedule(settings, await store.snoozedUntil());
    if (task != periodicTask) await schedulePrefetch(settings);
    // Returning false makes WorkManager retry later (e.g. lesson download failed).
    return ok || task == rescheduleTask;
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    try {
      return await Background.run(task);
    } catch (e) {
      debugPrint('Background task $task failed: $e');
      return false;
    }
  });
}
