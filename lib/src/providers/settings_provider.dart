import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme {
  system,
  light,
  dark,
}

enum AppLanguage {
  system,
  english,
  chinese,
}

class AppSettings {
  final AppTheme theme;
  final AppLanguage language;

  const AppSettings({
    this.theme = AppTheme.system,
    this.language = AppLanguage.system,
  });

  AppSettings copyWith({
    AppTheme? theme,
    AppLanguage? language,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      language: language ?? this.language,
    );
  }

  Locale? getLocale() {
    switch (language) {
      case AppLanguage.english:
        return const Locale('en');
      case AppLanguage.chinese:
        return const Locale('zh');
      case AppLanguage.system:
      default:
        return null;
    }
  }

  ThemeMode getThemeMode() {
    switch (theme) {
      case AppTheme.light:
        return ThemeMode.light;
      case AppTheme.dark:
        return ThemeMode.dark;
      case AppTheme.system:
      default:
        return ThemeMode.system;
    }
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  static const _themeKey = 'app_theme';
  static const _languageKey = 'app_language';

  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final themeIndex = prefs.getInt(_themeKey) ?? 0;
    final languageIndex = prefs.getInt(_languageKey) ?? 0;

    state = AppSettings(
      theme: AppTheme.values[themeIndex],
      language: AppLanguage.values[languageIndex],
    );
  }

  Future<void> setTheme(AppTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, theme.index);
    state = state.copyWith(theme: theme);
  }

  Future<void> setLanguage(AppLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_languageKey, language.index);
    state = state.copyWith(language: language);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
