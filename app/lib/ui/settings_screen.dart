import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../app_state.dart';
import '../logic/dates.dart';
import '../models/app_settings.dart';
import '../services/notification_service.dart';
import 'pickers.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _save(BuildContext context, AppSettings s) async {
    final msg = await context.read<AppState>().saveSettings(s);
    if (msg != null) showMessage(msg);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    final theme = Theme.of(context);
    final next = state.nextReminder;
    final nextLabel = '${dateKey(next) == dateKey(DateTime.now()) ? 'Today' : shortDate(dateKey(next))}, ${formatTime(context, next)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _Header('Learning'),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('English level'),
            subtitle: Text('${s.level} – ${levelDescriptions[s.level]}'),
            onTap: () async {
              final v = await pickOption(context, 'English level', {
                for (final l in levels) l: '$l – ${levelDescriptions[l]}',
              }, s.level);
              if (v != null && context.mounted) await _save(context, s.copyWith(level: v));
            },
          ),
          ListTile(
            leading: const Icon(Icons.translate),
            title: const Text('Translation language'),
            subtitle: Text(languageName(s.translationLanguage)),
            onTap: () async {
              final v = await pickOption(context, 'Translation language', translationLanguages, s.translationLanguage);
              if (v != null && context.mounted) await _save(context, s.copyWith(translationLanguage: v));
            },
          ),
          ListTile(
            leading: const Icon(Icons.style_outlined),
            title: const Text('New words per day'),
            subtitle: Text('${s.wordsPerDay}'),
            onTap: () async {
              final v = await pickNumber(context, 'New words per day', s.wordsPerDay, 1, 15);
              if (v != null && context.mounted) await _save(context, s.copyWith(wordsPerDay: v));
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Minutes per day'),
            subtitle: Text('${s.minutesPerDay} min'),
            onTap: () async {
              final v = await pickNumber(context, 'Minutes per day', s.minutesPerDay, 5, 120, step: 5);
              if (v != null && context.mounted) await _save(context, s.copyWith(minutesPerDay: v));
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.menu_book_outlined),
            title: const Text('Daily story'),
            value: s.storyEnabled,
            onChanged: (v) => _save(context, s.copyWith(storyEnabled: v)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _NoteBox(
              icon: state.hasToken ? Icons.cloud_done_outlined : Icons.info_outline,
              text: state.hasToken
                  ? 'Level, language, words, story and minutes are saved to config/settings.json on GitHub automatically, so new lessons follow them.'
                  : 'Without a GitHub token these settings only change this phone. To change the lessons themselves, edit config/settings.json in your repository on GitHub - or add a token below.',
              action: state.hasToken
                  ? TextButton(
                      onPressed: () async => showMessage(await state.syncContentSettings()),
                      child: const Text('Sync now'))
                  : null,
            ),
          ),
          const _Header('Reminder'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Daily reminder time'),
            subtitle: Text(s.notificationTime.format(context)),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: s.notificationTime);
              if (t != null && context.mounted) await _save(context, s.copyWith(notificationTime: t));
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Next notification'),
            subtitle: Text(state.snoozedUntil != null && next == state.snoozedUntil ? '$nextLabel (snoozed)' : nextLabel),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Check notification permissions'),
            subtitle: const Text('Asks again if notifications or exact alarms are blocked'),
            onTap: () async {
              await NotificationService.requestPermissions();
              final ok = await NotificationService.notificationsAllowed();
              await NotificationService.reschedule(state.settings, state.snoozedUntil);
              showMessage(ok ? 'Notifications are allowed.' : 'Notifications are blocked - enable them in Android settings.');
            },
          ),
          const _Header('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => _save(context, s.copyWith(themeMode: v.first)),
            ),
          ),
          const _Header('Lesson source (GitHub)'),
          ListTile(
            leading: const Icon(Icons.source_outlined),
            title: const Text('Repository'),
            subtitle: Text('${s.repoOwner}/${s.repoName} (${s.branch})'),
            onTap: () => _editRepo(context, s),
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('GitHub token (optional)'),
            subtitle: Text(state.hasToken
                ? 'Saved securely – using the GitHub API'
                : 'Not set – using public links (repository must be public)'),
            onTap: () => _editToken(context, state),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: FilledButton.tonalIcon(
              onPressed: () async {
                await state.loadToday(force: true);
                await state.refreshDates();
                showMessage(switch (state.todayState) {
                  LoadState.ready => "Downloaded. Today's lesson is ready.",
                  LoadState.notPublished => "Today's lesson isn't published yet.",
                  _ => 'Download failed: ${state.todayError ?? 'unknown error'}',
                });
              },
              icon: const Icon(Icons.download),
              label: const Text('Download now'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('English Daily · lessons are dated in Asia/Baku time',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Future<void> _editRepo(BuildContext context, AppSettings s) async {
    final owner = TextEditingController(text: s.repoOwner);
    final repo = TextEditingController(text: s.repoName);
    final branch = TextEditingController(text: s.branch);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repository'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: owner, decoration: const InputDecoration(labelText: 'Owner (GitHub user)')),
              TextField(controller: repo, decoration: const InputDecoration(labelText: 'Repository name')),
              TextField(controller: branch, decoration: const InputDecoration(labelText: 'Branch')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _save(
        context,
        s.copyWith(
          repoOwner: owner.text.trim(),
          repoName: repo.text.trim(),
          branch: branch.text.trim().isEmpty ? 'main' : branch.text.trim(),
        ),
      );
    }
  }

  Future<void> _editToken(BuildContext context, AppState state) async {
    final c = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GitHub token'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'A fine-grained token with access to this repository only and "Contents: Read and write" permission. '
                  'It lets the app read a private repository and save your settings to config/settings.json.'),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'github_pat_…', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          if (state.hasToken)
            TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Remove token')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    await state.setToken(result);
    if (result.trim().isNotEmpty) {
      showMessage(await state.syncContentSettings());
    } else {
      showMessage('Token removed.');
    }
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
      );
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.onSecondaryContainer),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer))),
            ],
          ),
          if (action != null) Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }
}
