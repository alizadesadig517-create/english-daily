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

  final AppState state;
  try {
    await NotificationService.initTimeZones();
    state = AppState(await AppDatabase.open(), SettingsStore());
    await state.init();
  } catch (e, st) {
    debugPrint('Startup failed: $e\n$st');
    runApp(StartupErrorApp(error: '$e'));
    return;
  }

  // Reminders and background jobs are optional extras: if one of them fails
  // the app must still open.
  ReminderAction? launchAction;
  try {
    await NotificationService.init(onAction: handleReminderAction);
    launchAction = await NotificationService.launchAction();
  } catch (e) {
    debugPrint('Notification init failed: $e');
  }
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

/// Shown instead of a black screen if the app cannot start.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});
  final String error;

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text('English Daily could not start', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SelectableText(error, style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ),
        ),
      );
}
