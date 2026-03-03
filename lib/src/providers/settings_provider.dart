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
  final int maxConcurrentConversions;

  const AppSettings({
    this.theme = AppTheme.system,
    this.language = AppLanguage.system,
    this.maxConcurrentConversions = 2,
  });

  AppSettings copyWith({
    AppTheme? theme,
    AppLanguage? language,
    int? maxConcurrentConversions,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      language: language ?? this.language,
      maxConcurrentConversions:
          maxConcurrentConversions ?? this.maxConcurrentConversions,
    );
  }

  Locale? getLocale() {
    switch (language) {
      case AppLanguage.english:
        return const Locale('en');
      case AppLanguage.chinese:
        return const Locale('zh');
      case AppLanguage.system:
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
        return ThemeMode.system;
    }
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  static const _themeKey = 'app_theme';
  static const _languageKey = 'app_language';
  static const _maxConcurrentConversionsKey = 'max_concurrent_conversions';

  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final themeIndex = prefs.getInt(_themeKey) ?? 0;
    final languageIndex = prefs.getInt(_languageKey) ?? 0;
    final maxConcurrent = prefs.getInt(_maxConcurrentConversionsKey) ?? 2;
    final safeMaxConcurrent = maxConcurrent.clamp(1, 4);

    state = AppSettings(
      theme: AppTheme.values[themeIndex],
      language: AppLanguage.values[languageIndex],
      maxConcurrentConversions: safeMaxConcurrent,
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

  Future<void> setMaxConcurrentConversions(int value) async {
    final safeValue = value.clamp(1, 4);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxConcurrentConversionsKey, safeValue);
    state = state.copyWith(maxConcurrentConversions: safeValue);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
