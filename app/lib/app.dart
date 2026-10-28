import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'services/notification_service.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding_screen.dart';
import 'ui/snooze_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

void showMessage(String text) {
  messengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 5)));
}

/// "Start" opens today's lesson; "Snooze" opens the snooze picker.
void handleReminderAction(ReminderAction action) {
  final nav = navigatorKey.currentState;
  final context = navigatorKey.currentContext;
  if (nav == null || context == null) return;
  final state = context.read<AppState>();
  if (!state.settings.onboardingDone) return;
  nav.popUntil((r) => r.isFirst);
  state.setTab(0);
  if (action == ReminderAction.snooze) {
    nav.push(MaterialPageRoute(builder: (_) => const SnoozeScreen()));
  } else {
    state.loadToday();
  }
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2F6F5E), brightness: brightness);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.5),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 16, height: 1.45),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: const AppBarTheme(centerTitle: false),
  );
}

class EnglishDailyApp extends StatefulWidget {
  const EnglishDailyApp({super.key, this.launchAction});
  final ReminderAction? launchAction;

  @override
  State<EnglishDailyApp> createState() => _EnglishDailyAppState();
}

class _EnglishDailyAppState extends State<EnglishDailyApp> {
  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    state.onDayCompleted = () => showMessage('Great job! Today\'s goal is done.');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state.onAppOpened();
      if (widget.launchAction != null) handleReminderAction(widget.launchAction!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppState, ThemeMode>((s) => s.settings.themeMode);
    final onboarded = context.select<AppState, bool>((s) => s.settings.onboardingDone);
    return MaterialApp(
      title: 'English Daily',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      home: onboarded ? const HomeShell() : const OnboardingScreen(),
    );
  }
}
