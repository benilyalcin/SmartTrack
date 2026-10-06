import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_state.dart';

/// The ATC 8256's tools in one tab, so the bottom bar does not grow with
/// each of them: Remote HMI, data download, and calibration to come. Each is
/// a card that opens its own page.
class VuToolsPage extends StatelessWidget {
  const VuToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final its = AppStateProvider.of(context).tachographType?.hasIts ?? false;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (its) ...[
          _ToolCard(
            icon: Icons.settings_remote_outlined,
            title: 'Uzaktan kumanda',
            subtitle:
                'Aktivite, yer, özel durum, uyarılar, çıktı, kart çıkarma ve '
                'manuel giriş',
            onTap: () => context.go('/vu/rhmi'),
          ),
          _ToolCard(
            icon: Icons.download_outlined,
            title: 'Veri indirme',
            subtitle:
                'Sürücü kartı ve araç ünitesi verisini ITS üzerinden indir',
            onTap: () => context.go('/vu/download'),
          ),
        ],
        // On an ATC the downloaded files are reached from Veri indirme; the
        // STC 8255 downloads through its dongle from the files page itself.
        if (!its)
          _ToolCard(
            icon: Icons.folder_outlined,
            title: 'Veri indirme ve dosyalar',
            subtitle: 'Dongle üzerinden indir; kaydedilen .ddd dosyaları',
            onTap: () => context.go('/ddd-files'),
          ),
        if (its)
          const _ToolCard(
            icon: Icons.tune_outlined,
            title: 'Kalibrasyon',
            subtitle: 'Yakında',
          ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Null for a tool that is not there yet.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        enabled: enabled,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: enabled
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          foregroundColor: enabled
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: enabled ? const Icon(Icons.chevron_right) : null,
        onTap: onTap,
      ),
    );
  }
}
