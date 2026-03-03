import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildThemeSection(context, ref, settings),
          const Divider(),
          _buildLanguageSection(context, ref, settings),
          const Divider(),
          _buildPerformanceSection(context, ref, settings),
        ],
      ),
    );
  }

  Widget _buildThemeSection(
      BuildContext context, WidgetRef ref, AppSettings settings) {
    return _SettingsSection(
      title: 'Theme',
      icon: Icons.palette_outlined,
      children: [
        _SettingsTile(
          title: 'App Theme',
          subtitle: _getThemeName(settings.theme),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showThemeDialog(context, ref, settings),
        ),
      ],
    );
  }

  Widget _buildLanguageSection(
      BuildContext context, WidgetRef ref, AppSettings settings) {
    return _SettingsSection(
      title: 'Language',
      icon: Icons.language,
      children: [
        _SettingsTile(
          title: 'App Language',
          subtitle: _getLanguageName(settings.language),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLanguageDialog(context, ref, settings),
        ),
      ],
    );
  }

  Widget _buildPerformanceSection(
      BuildContext context, WidgetRef ref, AppSettings settings) {
    return _SettingsSection(
      title: 'Performance',
      icon: Icons.speed_outlined,
      children: [
        _SettingsTile(
          title: 'Max Concurrent Conversions',
          subtitle: '${settings.maxConcurrentConversions} at a time',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showMaxConcurrentDialog(context, ref, settings),
        ),
      ],
    );
  }

  String _getThemeName(AppTheme theme) {
    switch (theme) {
      case AppTheme.system:
        return 'System';
      case AppTheme.light:
        return 'Light';
      case AppTheme.dark:
        return 'Dark';
    }
  }

  String _getLanguageName(AppLanguage language) {
    switch (language) {
      case AppLanguage.system:
        return 'System';
      case AppLanguage.english:
        return 'English';
      case AppLanguage.chinese:
        return '中文';
    }
  }

  void _showThemeDialog(
      BuildContext context, WidgetRef ref, AppSettings settings) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppTheme.values.map((theme) {
              final selected = settings.theme == theme;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20,
                ),
                title: Text(_getThemeName(theme)),
                onTap: () {
                  ref.read(settingsProvider.notifier).setTheme(theme);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showLanguageDialog(
      BuildContext context, WidgetRef ref, AppSettings settings) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppLanguage.values.map((language) {
              final selected = settings.language == language;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20,
                ),
                title: Text(_getLanguageName(language)),
                onTap: () {
                  ref.read(settingsProvider.notifier).setLanguage(language);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showMaxConcurrentDialog(
      BuildContext context, WidgetRef ref, AppSettings settings) {
    const choices = [1, 2, 3, 4];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Max Concurrent Conversions'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: choices.map((value) {
              final selected = settings.maxConcurrentConversions == value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20,
                ),
                title: Text('$value at a time'),
                onTap: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setMaxConcurrentConversions(value);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
