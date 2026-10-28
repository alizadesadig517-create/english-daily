import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../logic/schedule.dart';
import '../models/app_settings.dart';

/// What the user tapped on a reminder.
enum ReminderAction { start, snooze }

/// Daily reminder (repeats every day at the chosen time, exact alarm) plus an
/// optional one-off snooze for today.
class NotificationService {
  NotificationService._();

  static final plugin = FlutterLocalNotificationsPlugin();

  static const dailyId = 1;
  static const snoozeId = 2;
  static const actionStart = 'start';
  static const actionSnooze = 'snooze';

  static bool _tzReady = false;

  /// Loads time zone data and sets tz.local to the device's zone.
  static Future<void> initTimeZones() async {
    if (!_tzReady) {
      tzdata.initializeTimeZones();
      _tzReady = true;
    }
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Could not read device time zone: $e');
      tz.setLocalLocation(tz.getLocation('Asia/Baku'));
    }
  }

  static ReminderAction actionFor(NotificationResponse r) =>
      r.actionId == actionSnooze ? ReminderAction.snooze : ReminderAction.start;

  static Future<void> init({void Function(ReminderAction action)? onAction}) async {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
      onDidReceiveNotificationResponse: (r) => onAction?.call(actionFor(r)),
    );
  }

  /// If the app was opened from a reminder, which button was pressed.
  static Future<ReminderAction?> launchAction() async {
    final details = await plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final r = details.notificationResponse;
    return r == null ? ReminderAction.start : actionFor(r);
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Asks for POST_NOTIFICATIONS and (if needed) exact alarm permission.
  static Future<void> requestPermissions() async {
    final android = _android;
    if (android == null) return;
    await android.requestNotificationsPermission();
    if (!(await android.canScheduleExactNotifications() ?? true)) {
      await android.requestExactAlarmsPermission();
    }
  }

  static Future<bool> notificationsAllowed() async =>
      await _android?.areNotificationsEnabled() ?? true;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_lesson',
      'Daily lesson',
      channelDescription: 'Your daily English practice reminder',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      actions: [
        AndroidNotificationAction(actionStart, 'Start', showsUserInterface: true),
        AndroidNotificationAction(actionSnooze, 'Snooze', showsUserInterface: true),
      ],
    ),
  );

  static Future<AndroidScheduleMode> _mode() async {
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    return exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static tz.TZDateTime _toTz(DateTime local) => tz.TZDateTime(
      tz.local, local.year, local.month, local.day, local.hour, local.minute);

  /// Cancels and re-creates the daily reminder and today's snooze (if any).
  /// Safe to call often: after settings changes, on app start, after reboot
  /// or a time zone change, and from the background job.
  static Future<void> reschedule(AppSettings settings, DateTime? snoozedUntil) async {
    if (!settings.onboardingDone) return;
    await initTimeZones();
    final now = DateTime.now();
    final t = settings.notificationTime;
    final mode = await _mode();

    await plugin.cancel(id: dailyId);
    await plugin.zonedSchedule(
      id: dailyId,
      title: 'Time for English',
      body: "Today's words, story and grammar are waiting. ${settings.minutesPerDay} minutes.",
      scheduledDate: _toTz(nextDailyReminder(now, t.hour, t.minute)),
      notificationDetails: _details,
      androidScheduleMode: mode,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await plugin.cancel(id: snoozeId);
    final snooze = activeSnooze(now, snoozedUntil);
    if (snooze != null) {
      await plugin.zonedSchedule(
        id: snoozeId,
        title: 'Ready for English?',
        body: 'You snoozed your lesson - here it is again.',
        scheduledDate: _toTz(snooze),
        notificationDetails: _details,
        androidScheduleMode: mode,
      );
    }
  }
}
