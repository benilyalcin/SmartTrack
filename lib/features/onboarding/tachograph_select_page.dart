import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/localization.dart';
import '../../core/models/tachograph_type.dart';
import '../../core/providers/app_state.dart';

/// The first screen after the splash, on every launch: which tachograph is
/// this. The choice decides how the connection screen that follows talks to
/// the device (see TachographType.link); the rest of the app is shared.
class TachographSelectPage extends StatelessWidget {
  const TachographSelectPage({super.key});

  void _choose(BuildContext context, TachographType type) {
    AppStateProvider.of(context).setTachographType(type);
    context.go('/connect');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lang = AppStateProvider.of(context).selectedLanguage;
    String t(String key) => AppLocalizations.getText(lang, key);

    final backgroundColor = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.07),
      scheme.surface,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            left: -80,
            child: _blurCircle(scheme.primary, 240),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: _blurCircle(scheme.tertiary, 280),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 448),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'logo.png',
                        height: 64,
                        errorBuilder: (context, error, stack) => Icon(
                          Icons.local_shipping,
                          size: 56,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t('select.title'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t('select.subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      for (final type in TachographType.values) ...[
                        _TypeCard(
                          type: type,
                          description: t(type.descriptionKey),
                          onTap: () => _choose(context, type),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _blurCircle(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final TachographType type;
  final String description;
  final VoidCallback onTap;

  const _TypeCard({
    required this.type,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.primaryContainer, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  type.hasIts ? Icons.settings_input_antenna : Icons.speed,
                  color: scheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.code,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
