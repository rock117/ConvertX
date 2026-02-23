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
              return RadioListTile<AppTheme>(
                title: Text(_getThemeName(theme)),
                value: theme,
                groupValue: settings.theme,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(settingsProvider.notifier).setTheme(value);
                    Navigator.of(context).pop();
                  }
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
              return RadioListTile<AppLanguage>(
                title: Text(_getLanguageName(language)),
                value: language,
                groupValue: settings.language,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(settingsProvider.notifier).setLanguage(value);
                    Navigator.of(context).pop();
                  }
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
