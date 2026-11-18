import 'package:flutter/material.dart';

import '../localization/localization.dart';
import '../providers/app_state.dart';
import '../services/driving_time_calculator.dart';
import '../services/time/display_time.dart';

/// What the line to the unit is doing, for the driver:
/// - a card download holds it ("verifying tachograph data"), with the last
///   known activity and speed, faded and time-stamped, as no live data
///   comes meanwhile;
/// - stale card data is waiting for the vehicle to stop;
/// - a card file corrected live or manual data noticeably.
class LinkStatusBanner extends StatelessWidget {
  const LinkStatusBanner({super.key});

  static const _activityKeys = {
    ActivityType.driving: 'timeline.driving',
    ActivityType.rest: 'timeline.break_',
    ActivityType.work: 'timeline.work',
    ActivityType.available: 'timeline.available',
    ActivityType.unknown: 'violation.missingRecord',
  };

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final data = appState.activityData;
    final lang = appState.selectedLanguage;
    String t(String key, [Map<String, Object?> args = const {}]) =>
        AppLocalizations.fill(AppLocalizations.getText(lang, key), args);
    final scheme = Theme.of(context).colorScheme;
    final display = DisplayTime.fromConfig();

    final banners = <Widget>[];
    if (data.isVerifying) {
      final last = data.lastLive('driver1');
      final speed = data.lastSpeed;
      final at = speed?.tsUtc ?? data.syncOf('driver1').lastLiveSampleUtc;
      banners.add(
        _Banner(
          icon: Icons.sync,
          color: scheme.primary,
          title: t('link.verifying'),
          detail: last == null || at == null
              ? null
              : t('link.lastKnown', {
                  'activity': t(_activityKeys[last.activityType]!),
                  'speed': speed?.kmh ?? '-',
                  'time': display.hm(at),
                }),
        ),
      );
    } else if (data.waitingForStop) {
      banners.add(
        _Banner(
          icon: Icons.local_parking,
          color: scheme.tertiary,
          title: t('link.waitForStop'),
        ),
      );
    }

    final corrections = data.pendingCorrections;
    if (corrections.isNotEmpty) {
      final minutes = corrections.fold<int>(
        0,
        (sum, c) => sum + c.differingTime.inMinutes,
      );
      banners.add(
        _Banner(
          icon: Icons.fact_check_outlined,
          color: scheme.secondary,
          title: t('link.corrected', {
            'count': corrections.length,
            'minutes': minutes,
          }),
          onClose: data.clearPendingCorrections,
        ),
      );
    }

    if (banners.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in banners)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: b),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.title,
    this.detail,
    this.onClose,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? detail;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: TextStyle(fontSize: 12, color: scheme.outline),
                  ),
                ],
              ],
            ),
          ),
          if (onClose != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close, size: 18, color: scheme.outline),
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}
