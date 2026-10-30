import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/localization.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/its/appendix7.dart';
import '../../core/services/its/download_generation_setting.dart';

/// ITS > Gelişmiş: what a driver does not need, kept out of the way - the
/// generation a vehicle unit download asks for, and the workshop's
/// calibration console.
class ItsAdvancedPage extends StatelessWidget {
  const ItsAdvancedPage({super.key, this.embedded = false});

  final bool embedded;

  static String _hex(int v) =>
      '0x${v.toRadixString(16).padLeft(2, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.bodySmall;
    final lang = AppStateProvider.of(context).selectedLanguage;
    String t(String key) => AppLocalizations.getText(lang, key);

    final children = <Widget>[
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ValueListenableBuilder<DownloadGeneration>(
            valueListenable: DownloadGenerationSetting.value,
            builder: (context, generation, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t('its.advGenerationTitle'),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(t('its.advGenerationBody'), style: small),
                const SizedBox(height: 12),
                SegmentedButton<DownloadGeneration>(
                  segments: [
                    for (final g in DownloadGeneration.values)
                      ButtonSegment(value: g, label: Text(g.label)),
                  ],
                  selected: {generation},
                  onSelectionChanged: (s) =>
                      DownloadGenerationSetting.value.value = s.first,
                ),
                const SizedBox(height: 8),
                if (generation == DownloadGenerationSetting.recommended)
                  Text(
                    t('its.advRecommended'),
                    style: small?.copyWith(color: scheme.primary),
                  )
                else
                  Text(
                    t('its.advNotRecommended'),
                    style: small?.copyWith(color: scheme.error),
                  ),
                const SizedBox(height: 4),
                Text(
                  t('its.trtpNote')
                      .replaceAll(
                        '{overview}',
                        _hex(
                          Appendix7.trtpFor(VuTransfer.overview, generation),
                        ),
                      )
                      .replaceAll(
                        '{activities}',
                        _hex(
                          Appendix7.trtpFor(VuTransfer.activities, generation),
                        ),
                      ),
                  style: small,
                ),
              ],
            ),
          ),
        ),
      ),
      Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: const Icon(Icons.tune_outlined),
          ),
          title: Text(
            t('its.calibrationTitle'),
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(t('its.advCalibrationSubtitle')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/vu/calibration'),
        ),
      ),
    ];

    if (embedded) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        leading: BackButton(onPressed: () => context.go('/vu')),
        title: Text(
          t('its.toolAdvancedTitle'),
          style: const TextStyle(fontSize: 18),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: children),
    );
  }
}
