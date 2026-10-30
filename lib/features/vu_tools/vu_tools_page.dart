import 'package:flutter/material.dart';

import '../../core/localization/localization.dart';
import '../../core/models/tachograph_type.dart';
import '../../core/providers/app_state.dart';
import '../ddd_files/ddd_files_page.dart';
import '../its_advanced/its_advanced_page.dart';
import '../its_download/its_download_page.dart';
import '../rhmi/rhmi_page.dart';

/// The ATC's ITS tools share one scrolling page. The STC keeps its files view.
class VuToolsPage extends StatelessWidget {
  const VuToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    if (appState.tachographType == TachographType.stc8255 ||
        !(appState.tachographType?.hasIts ?? false)) {
      return const DddFilesPage();
    }

    String t(String key) =>
        AppLocalizations.getText(appState.selectedLanguage, key);
    return SingleChildScrollView(
      key: const PageStorageKey('its-tools-scroll'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ToolSection(
            icon: Icons.settings_remote_outlined,
            title: t('its.toolRhmiTitle'),
            subtitle: t('its.toolRhmiSubtitle'),
            child: const RhmiPage(embedded: true),
          ),
          const SizedBox(height: 24),
          _ToolSection(
            icon: Icons.download_outlined,
            title: t('its.toolDownloadTitle'),
            subtitle: t('its.toolDownloadSubtitle'),
            child: const ItsDownloadPage(embedded: true),
          ),
          const SizedBox(height: 24),
          _ToolSection(
            icon: Icons.settings_suggest_outlined,
            title: t('its.toolAdvancedTitle'),
            subtitle: t('its.toolAdvancedSubtitle'),
            child: const ItsAdvancedPage(embedded: true),
          ),
        ],
      ),
    );
  }
}

class _ToolSection extends StatelessWidget {
  const _ToolSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}
