import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/localization.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/driving_time_calculator.dart';
import '../../core/services/kline_protocol.dart' show TachographLiveData;
import '../../core/widgets/bluetooth_warning_banner.dart';
import '../../core/widgets/card_slot_warning_banner.dart';

class DriverModePage extends StatefulWidget {
  const DriverModePage({super.key});

  @override
  State<DriverModePage> createState() => _DriverModePageState();
}

class _DriverModePageState extends State<DriverModePage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  String _t(String key) => AppLocalizations.getText(
    AppStateProvider.of(context).selectedLanguage,
    key,
  );

  String _fmtHM(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _fmtClock(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  IconData _activityIcon(String key) {
    switch (key) {
      case 'dashboard.driving':
        return Icons.directions_car;
      case 'dashboard.rest':
        return Icons.hotel;
      case 'dashboard.otherWork':
        return Icons.engineering;
      case 'dashboard.availability':
        return Icons.event_available;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width >= size.height;

    final live = appState.tachographLiveData;
    final isDriver1 = appState.activeDriver == 'driver1';
    final driverName = (isDriver1 ? live.driver1Name : live.driver2Name);
    final continuous = appState.activeDrivingRules['continuous'];
    final daily = appState.activeDrivingRules['daily'];
    final weekly = appState.activeDrivingRules['weekly'];
    final timeUntilBreak =
        appState.activeTimeUntilNextBreakOrRest ?? continuous?.remaining;
    final isSpeeding =
        live.speedLimitKmh > 0 && live.speedKmh > live.speedLimitKmh;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const BluetoothWarningBanner(),
            const CardSlotWarningBanner(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(
                      context,
                      scheme,
                      driverName,
                      appState.vehiclePlate,
                      isSpeeding,
                      live.speedKmh,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: isLandscape
                          ? _buildLandscapeBody(
                              context,
                              scheme,
                              appState,
                              continuous,
                              daily,
                              weekly,
                              timeUntilBreak,
                              live,
                            )
                          : _buildPortraitBody(
                              context,
                              scheme,
                              appState,
                              continuous,
                              daily,
                              weekly,
                              timeUntilBreak,
                              live,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme scheme,
    String driverName,
    String plate,
    bool isSpeeding,
    int speedKmh,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.badge, color: scheme.onPrimary, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _t('driverMode.title'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              Text(
                [
                  if (driverName.isNotEmpty) driverName,
                  if (plate.isNotEmpty) plate,
                ].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (isSpeeding)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: scheme.error),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: scheme.error,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_t('driverMode.speedWarning')}: $speedKmh km/s',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
          tooltip: _t('driverMode.title'),
        ),
      ],
    );
  }

  Widget _buildLandscapeBody(
    BuildContext context,
    ColorScheme scheme,
    AppState appState,
    DrivingRuleResult? continuous,
    DrivingRuleResult? daily,
    DrivingRuleResult? weekly,
    Duration? timeUntilBreak,
    TachographLiveData live,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 4,
          child: _buildStatusAndSpeedPanel(context, scheme, appState, live),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(
                child: _buildTimeUntilBreakPanel(
                  context,
                  scheme,
                  timeUntilBreak,
                  continuous,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildRuleUsagePanel(
                  context,
                  scheme,
                  _t('driverMode.dailyDriving'),
                  daily,
                  scheme.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(
                child: _buildRuleUsagePanel(
                  context,
                  scheme,
                  _t('driverMode.weeklyDriving'),
                  weekly,
                  scheme.tertiary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildNextRestAndDistancePanel(
                  context,
                  scheme,
                  timeUntilBreak,
                  live,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitBody(
    BuildContext context,
    ColorScheme scheme,
    AppState appState,
    DrivingRuleResult? continuous,
    DrivingRuleResult? daily,
    DrivingRuleResult? weekly,
    Duration? timeUntilBreak,
    TachographLiveData live,
  ) {
    return ListView(
      children: [
        SizedBox(
          height: 220,
          child: _buildStatusAndSpeedPanel(context, scheme, appState, live),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: _buildTimeUntilBreakPanel(
            context,
            scheme,
            timeUntilBreak,
            continuous,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 140,
                child: _buildRuleUsagePanel(
                  context,
                  scheme,
                  _t('driverMode.dailyDriving'),
                  daily,
                  scheme.secondary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 140,
                child: _buildRuleUsagePanel(
                  context,
                  scheme,
                  _t('driverMode.weeklyDriving'),
                  weekly,
                  scheme.tertiary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: _buildNextRestAndDistancePanel(
            context,
            scheme,
            timeUntilBreak,
            live,
          ),
        ),
      ],
    );
  }

  Widget _panelShell(
    ColorScheme scheme, {
    required Widget child,
    Color? background,
    Color? border,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border ?? scheme.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _buildStatusAndSpeedPanel(
    BuildContext context,
    ColorScheme scheme,
    AppState appState,
    TachographLiveData live,
  ) {
    final activityKey = appState.activeCurrentActivity;
    return _panelShell(
      scheme,
      background: scheme.primary,
      border: scheme.primary,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_activityIcon(activityKey), color: scheme.onPrimary, size: 24),
          const SizedBox(height: 6),
          Text(
            _t(activityKey).toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: scheme.onPrimary,
              letterSpacing: -0.3,
            ),
          ),

          Expanded(
            child: FittedBox(
              child: Text(
                '${live.speedKmh}',
                style: TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimary,
                  height: 1,
                  letterSpacing: -2,
                ),
              ),
            ),
          ),
          Text(
            _t('driverMode.speedUnit'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUntilBreakPanel(
    BuildContext context,
    ColorScheme scheme,
    Duration? timeUntilBreak,
    DrivingRuleResult? continuous,
  ) {
    final isCritical =
        continuous != null && (continuous.isWarning || continuous.isExceeded);
    final fraction = continuous == null
        ? 0.0
        : (continuous.used.inSeconds / continuous.limit.inSeconds).clamp(
            0.0,
            1.0,
          );
    return _panelShell(
      scheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: scheme.primary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _t('compliance.timeUntilBreak'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          Expanded(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              child: Text(
                timeUntilBreak == null ? '--:--:--' : _fmtHM(timeUntilBreak),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: isCritical ? scheme.error : scheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              color: isCritical ? scheme.error : scheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isCritical ? Icons.warning_amber_rounded : Icons.check_circle,
                size: 14,
                color: isCritical ? scheme.error : scheme.primary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  isCritical
                      ? _t('violation.continuousDrivingExceeded')
                      : _t('driverMode.safeLimit'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isCritical ? scheme.error : scheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRuleUsagePanel(
    BuildContext context,
    ColorScheme scheme,
    String label,
    DrivingRuleResult? rule,
    Color accent,
  ) {
    final fraction = rule == null
        ? 0.0
        : (rule.used.inSeconds / rule.limit.inSeconds).clamp(0.0, 1.0);
    return _panelShell(
      scheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          Expanded(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: rule == null
                          ? '--:--'
                          : '${rule.used.inHours.toString().padLeft(2, '0')}:${(rule.used.inMinutes % 60).toString().padLeft(2, '0')} ',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                    TextSpan(
                      text: rule == null
                          ? ''
                          : '/ ${rule.limit.inHours}:${(rule.limit.inMinutes % 60).toString().padLeft(2, '0')} sa',
                      style: TextStyle(fontSize: 13, color: scheme.outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextRestAndDistancePanel(
    BuildContext context,
    ColorScheme scheme,
    Duration? timeUntilBreak,
    TachographLiveData live,
  ) {
    final nextRestAt = timeUntilBreak == null
        ? null
        : DateTime.now().add(timeUntilBreak);
    return _panelShell(
      scheme,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bedtime_outlined,
                      size: 16,
                      color: scheme.tertiary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _t('driverMode.nextRest'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  nextRestAt == null
                      ? '-'
                      : _t(
                          'driverMode.nextRestStartsAt',
                        ).replaceFirst('{time}', _fmtClock(nextRestAt)),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: scheme.outlineVariant),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.route_outlined,
                        size: 16,
                        color: scheme.tertiary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _t('driverMode.distance'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 16),

                  child: Text(
                    '${live.odometerKm.toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
