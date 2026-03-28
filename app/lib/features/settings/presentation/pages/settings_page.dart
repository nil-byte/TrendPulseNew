import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ref.read(baseUrlProvider));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(defaultLanguageProvider);
    final maxItems = ref.watch(defaultMaxItemsProvider);

    ref.listen<String>(baseUrlProvider, (_, next) {
      if (_urlController.text != next) {
        _urlController.text = next;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          _SectionHeader(label: 'Server Configuration'),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'API Base URL',
              hintText: 'http://localhost:8000',
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveBaseUrl(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: _saveBaseUrl,
              child: const Text('Save'),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          _SectionHeader(label: 'Defaults'),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Default Language'),
            trailing: DropdownButton<String>(
              value: language,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(12),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'zh', child: Text('中文')),
              ],
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(defaultLanguageProvider.notifier)
                      .setLanguage(value);
                }
              },
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Default Items'),
            subtitle: Text('$maxItems items per analysis'),
          ),
          Slider(
            value: maxItems.toDouble(),
            min: 10,
            max: 100,
            divisions: 9,
            label: '$maxItems',
            onChanged: (value) {
              ref
                  .read(defaultMaxItemsProvider.notifier)
                  .setMaxItems(value.round());
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          _SectionHeader(label: 'Appearance'),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (modes) {
              ref.read(themeModeProvider.notifier).setThemeMode(modes.first);
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          _SectionHeader(label: 'About'),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('TrendPulse'),
            subtitle: const Text('Version 0.1.0'),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Text(
              'AI-powered social media trend analysis. '
              'Aggregate content from Reddit, YouTube, and X, '
              'then generate insights with Grok.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveBaseUrl() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      ref.read(baseUrlProvider.notifier).setBaseUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Base URL saved'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
