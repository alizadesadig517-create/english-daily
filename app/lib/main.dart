import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'app_state.dart';
import 'data/database.dart';
import 'data/settings_store.dart';
import 'services/background.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initTimeZones();
  final state = AppState(await AppDatabase.open(), SettingsStore());
  await state.init();

  await NotificationService.init(onAction: handleReminderAction);
  final launchAction = await NotificationService.launchAction();
  try {
    await Background.init();
  } catch (e) {
    debugPrint('Background init failed: $e');
  }

  runApp(ChangeNotifierProvider.value(
    value: state,
    child: EnglishDailyApp(launchAction: launchAction),
  ));
}
