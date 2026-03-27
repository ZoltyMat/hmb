import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../util/flutter/app_title.dart';
import '../../../util/flutter/theme_mode_notifier.dart';

/// Lets the user choose between System, Light, and Dark theme modes.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    setAppTitle('Appearance');

    return JuneBuilder(
      ThemeModeNotifier.new,
      builder: (_) {
        final notifier =
            June.getState<ThemeModeNotifier>(ThemeModeNotifier.new);
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Theme',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _ThemeOption(
              title: 'System default',
              subtitle: 'Follow the device setting',
              value: ThemeMode.system,
              selected: notifier.mode == ThemeMode.system,
              onTap: () => notifier.setMode(ThemeMode.system),
            ),
            _ThemeOption(
              title: 'Light',
              value: ThemeMode.light,
              selected: notifier.mode == ThemeMode.light,
              onTap: () => notifier.setMode(ThemeMode.light),
            ),
            _ThemeOption(
              title: 'Dark',
              value: ThemeMode.dark,
              selected: notifier.mode == ThemeMode.dark,
              onTap: () => notifier.setMode(ThemeMode.dark),
            ),
          ],
        );
      },
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.title,
    required this.value,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final ThemeMode value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      color: selected ? Theme.of(context).colorScheme.primary : null,
    ),
    title: Text(title),
    subtitle: subtitle != null ? Text(subtitle!) : null,
    onTap: onTap,
  );
}
