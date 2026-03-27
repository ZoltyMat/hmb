import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../dart/app_settings.dart';

/// Reactive state holder for the app's [ThemeMode].
///
/// Consumers rebuild via `JuneBuilder<ThemeModeNotifier>(...)`.
/// The selected mode is persisted to `SettingsYaml` so it survives restarts.
class ThemeModeNotifier extends JuneState {
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  /// Call once at app startup (before the first frame) to hydrate from disk.
  Future<void> load() async {
    _mode = _fromName(await AppSettings.getThemeModeName());
  }

  /// Update the active theme mode, persist, and notify listeners.
  Future<void> setMode(ThemeMode newMode) async {
    if (newMode == _mode) {
      return;
    }
    _mode = newMode;
    await AppSettings.setThemeModeName(newMode.name);
    setState();
  }

  static ThemeMode _fromName(String name) {
    for (final mode in ThemeMode.values) {
      if (mode.name == name) {
        return mode;
      }
    }
    return ThemeMode.system;
  }
}
