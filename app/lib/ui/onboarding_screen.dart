import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/app_settings.dart';
import 'pickers.dart';

/// First launch: one question per step. Everything can be changed later in
/// Settings.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late AppSettings _s;
  int _step = 0;
  bool _saving = false;
  static const _steps = 8;

  @override
  void initState() {
    super.initState();
    _s = context.read<AppState>().settings;
  }

  void _set(AppSettings s) => setState(() => _s = s);

  Future<void> _next() async {
    if (_step < _steps - 1) {
      setState(() => _step++);
      return;
    }
    setState(() => _saving = true);
    await context.read<AppState>().completeOnboarding(_s);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: (_step + 1) / _steps, minHeight: 8),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(key: ValueKey(_step), child: _page(theme)),
                ),
              ),
              Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: _saving ? null : () => setState(() => _step--),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(110, 56)),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : _next,
                    style: FilledButton.styleFrom(minimumSize: const Size(160, 56)),
                    child: Text(_step == 0 ? "Let's start" : _step == _steps - 1 ? 'Finish' : 'Next',
                        style: const TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _question(ThemeData theme, String title, String subtitle, Widget body) => ListView(
        children: [
          Text(title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          body,
        ],
      );

  Widget _choices<T>(List<(T, String, String?)> options, T selected, ValueChanged<T> onPick) => Column(
        children: [
          for (final (value, label, sub) in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                color: value == selected ? Theme.of(context).colorScheme.primaryContainer : null,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  title: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  subtitle: sub == null ? null : Text(sub),
                  trailing: value == selected ? const Icon(Icons.check_circle) : null,
                  onTap: () => onPick(value),
                ),
              ),
            ),
        ],
      );

  Widget _page(ThemeData theme) {
    switch (_step) {
      case 0:
        return ListView(
          children: [
            const SizedBox(height: 32),
            Icon(Icons.auto_stories, size: 96, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text('English Daily',
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Text(
              'Every day: new words, a short story and a grammar topic made for your level. '
              "Let's set it up - it takes one minute.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        );
      case 1:
        return _question(
          theme,
          'Your English level',
          'Lessons will match this level.',
          _choices([for (final l in levels) (l, l, levelDescriptions[l])], _s.level,
              (v) => _set(_s.copyWith(level: v))),
        );
      case 2:
        return _question(
          theme,
          'Translate into',
          'Translations and explanations will be in this language.',
          _choices([for (final e in translationLanguages.entries) (e.key, e.value, null)],
              _s.translationLanguage, (v) => _set(_s.copyWith(translationLanguage: v))),
        );
      case 3:
        return _question(
          theme,
          'Daily reminder',
          'When should I remind you to practise?',
          Center(
            child: FilledButton.tonalIcon(
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: _s.notificationTime);
                if (t != null) _set(_s.copyWith(notificationTime: t));
              },
              icon: const Icon(Icons.alarm, size: 32),
              label: Text(_s.notificationTime.format(context), style: theme.textTheme.displaySmall),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18)),
            ),
          ),
        );
      case 4:
        return _question(
          theme,
          'Minutes per day',
          'The day counts as done when you finish all sections or reach this time.',
          NumberStepper(
            value: _s.minutesPerDay,
            min: 5,
            max: 120,
            step: 5,
            suffix: ' min',
            onChanged: (v) => _set(_s.copyWith(minutesPerDay: v)),
          ),
        );
      case 5:
        return _question(
          theme,
          'New words per day',
          'Each word comes with meanings, examples and pronunciation.',
          NumberStepper(
            value: _s.wordsPerDay,
            min: 1,
            max: 15,
            onChanged: (v) => _set(_s.copyWith(wordsPerDay: v)),
          ),
        );
      case 6:
        return _question(
          theme,
          'Daily story',
          'A short story that uses the new words. Tap any word to see what it means.',
          _choices([(true, 'Yes, include a story', null), (false, 'No story', null)], _s.storyEnabled,
              (v) => _set(_s.copyWith(storyEnabled: v))),
        );
      default:
        return _question(
          theme,
          'Theme',
          'You can change this any time.',
          _choices([
            (ThemeMode.system, 'Follow system', null),
            (ThemeMode.light, 'Light', null),
            (ThemeMode.dark, 'Dark', null),
          ], _s.themeMode, (v) => _set(_s.copyWith(themeMode: v))),
        );
    }
  }
}
