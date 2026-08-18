import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _storageKey = 'cloud9_agent_theme_mode';
  static const _storage = FlutterSecureStorage();

  ThemeModeNotifier() : super(ThemeMode.light) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved == 'dark') {
        state = ThemeMode.dark;
      } else if (saved == 'system') {
        state = ThemeMode.system;
      } else if (saved == 'light') {
        state = ThemeMode.light;
      }
    } catch (_) {
      // Light mode remains the safe fallback if storage is unavailable.
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    _persist(mode);
  }

  void setLight() => setThemeMode(ThemeMode.light);

  void setDark() => setThemeMode(ThemeMode.dark);

  void setSystem() => setThemeMode(ThemeMode.system);

  Future<void> _persist(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    };
    try {
      await _storage.write(key: _storageKey, value: value);
    } catch (_) {
      // The in-memory selection remains usable if persistence is unavailable.
    }
  }
}
