import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_state.dart';
import '../../core/localization/localization.dart';
import '../../core/services/driving_time_calculator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/bluetooth_warning_banner.dart';
import '../../core/widgets/card_slot_warning_banner.dart';
import 'driver_identity_dialog.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _t(String key) {
    return AppLocalizations.getText(
      AppStateProvider.of(context).selectedLanguage,
      key,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BluetoothWarningBanner(),
          const CardSlotWarningBanner(),
          _buildDriverSelection(context),
          const SizedBox(height: 16),

          _buildStatusCard(context, appState),
          const SizedBox(height: 16),

          _buildDriverIdentityBanner(context),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildSpeedAndDistanceWidget(context)),
              const SizedBox(width: 16),
              _buildTimeUntilBreakCard(context),
            ],
          ),
          const SizedBox(height: 16),
          _buildDriverModeButton(context),
          const SizedBox(height: 16),

          _buildParametersSection(context, appState, isDesktopLayout(context)),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                context.go('/timeline');
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '${_t('nav.timeline')} Göster',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverSelection(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final activeDriver = appState.activeDriver;

    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 350),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => appState.setActiveDriver('driver1'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: activeDriver == 'driver1'
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      _t('dashboard.driver1Tab'),
                      style: TextStyle(
                        color: activeDriver == 'driver1'
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => appState.setActiveDriver('driver2'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: activeDriver == 'driver2'
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      _t('dashboard.driver2Tab'),
                      style: TextStyle(
                        color: activeDriver == 'driver2'
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverIdentityBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showDriverIdentityDialog(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.badge, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _t('driverIdentity.bannerText'),
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSecondaryContainer),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, AppState appState) {
    final scheme = Theme.of(context).colorScheme;
    final activities = appState.activityLog;
    final isDriver1Tab = appState.activeDriver == 'driver1';

    final sessionDuration =
        appState.activeLiveSessionDuration ??
        (isDriver1Tab && activities.isNotEmpty
            ? activities.last.duration
            : null);
    final plate = appState.vehiclePlate;

    final isDriver1 = appState.activeDriver == 'driver1';
    final driverLabel = isDriver1
        ? _t('dashboard.mainDriver')
        : _t('dashboard.backupDriver');
    final driverName = isDriver1
        ? appState.tachographLiveData.driver1Name
        : appState.tachographLiveData.driver2Name;

    final cardSlot2 = appState.tachographLiveData.cardSlot2;
    final crewLabel = cardSlot2 == null
        ? _t('dashboard.noData')
        : (cardSlot2 == 1 ? _t('ddd.crewBadge') : _t('ddd.soloBadge'));
    final country = appState.tachographLiveData.memberState;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _activityIconForKey(appState.activeCurrentActivity),
              size: 26,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _t('compliance.currentStatus'),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _t(appState.activeCurrentActivity).toUpperCase(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: scheme.onPrimaryContainer,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.onPrimaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_t('compliance.activeSession')}: '
                  '${sessionDuration == null ? '-' : '${_fmtHM(sessionDuration)} sa'}'
                  '${(!appState.isBluetoothConnected && sessionDuration != null) ? ' ${_t('compliance.staleSuffix')}' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: scheme.primaryContainer,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${_t('dashboard.plateLabel')}: ${plate.isEmpty ? '-' : plate}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '$driverLabel: ${driverName.isEmpty ? '-' : driverName}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${_t('compliance.crewStatus')}: $crewLabel',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${_t('compliance.registeredCountry')}: ${country.isEmpty ? '-' : country}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _activityIconForKey(String key) {
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

  String _fmtHM(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildParametersSection(
    BuildContext context,
    AppState appState,
    bool isDesktop,
  ) {
    final rules = appState.activeDrivingRules;
    final continuous = rules['continuous'];
    final daily = rules['daily'];
    final weekly = rules['weekly'];
    final biWeekly = rules['bi_weekly'];
    final remaining10h = appState.activeRemaining10hDrivingTimes;
    final remainingReducedRest =
        appState.activeRemainingReducedDailyRestPeriods;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          _t('compliance.parametersTitle').toUpperCase(),
        ),
        const SizedBox(height: 16),

        _buildDailyUsageCard(
          context,
          daily,
          unavailable: appState.activeDailyDrivingUnavailable,
        ),
        const SizedBox(height: 12),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildRemaining10hCard(context, remaining10h)),
            const SizedBox(width: 12),
            Expanded(
              child: _buildReducedRestCard(context, remainingReducedRest),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _buildViolationSummaryCard(context, appState),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: isDesktop ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isDesktop ? 1.1 : 0.78,
          children: [
            _buildContinuousUsageCard(context, continuous),
            _buildSimpleCard(
              context,
              icon: Icons.local_cafe,
              label: _t('compliance.cumulativeBreak'),
              value: continuous == null
                  ? '-'
                  : '${_fmtHM(appState.activeTotalBreakTime)} sa',
              hint: _t('compliance.cumulativeBreakHint'),
            ),
            _buildRuleCard(
              context,
              icon: Icons.calendar_today,
              label: _t('compliance.weeklyDriving'),
              rule: weekly,
              limit: DrivingTimeCalculator.weeklyDrivingLimit,
              hint: _t('compliance.weeklyDrivingHint'),
              unavailable: appState.activeWeeklyDrivingUnavailable,
            ),
            _buildRuleCard(
              context,
              icon: Icons.date_range,
              label: _t('compliance.biWeeklyTotal'),
              rule: biWeekly,
              limit: DrivingTimeCalculator.biWeeklyDrivingLimit,
              hint: _t('compliance.biWeeklyTotalHint'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildExtendedDetailsSection(context, appState, isDesktop),
      ],
    );
  }

  Widget _buildExtendedDetailsSection(
    BuildContext context,
    AppState appState,
    bool isDesktop,
  ) {
    final currentBreakRemaining = appState.activeCurrentBreakRestRemaining;
    final lastDailyRestEnd = appState.activeLastDailyRestEnd;
    final lastWeeklyRestEnd = appState.activeLastWeeklyRestEnd;
    final minDailyRest = appState.activeMinimumDailyRest;
    final minWeeklyRest = appState.activeMinimumWeeklyRest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, _t('compliance.detailsTitle')),
        const SizedBox(height: 16),

        _buildSectionHeader(context, _t('compliance.dailyParametersTitle')),
        const SizedBox(height: 10),
        _buildNextBreakCard(context, appState),
        const SizedBox(height: 12),

        _buildMinDailyRestCard(
          context,
          minDailyRest,
          appState.isCrew,
          unavailable: appState.activeMinimumDailyRestUnavailable,
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: isDesktop ? 1.1 : 0.78,
                child: _buildSimpleCard(
                  context,
                  icon: Icons.pause_circle_outline,
                  label: _t('compliance.currentBreakRemaining'),
                  value: currentBreakRemaining != null
                      ? '${_fmtHM(currentBreakRemaining)} sa'
                      : (appState.activeCurrentBreakRestRemainingUnavailable
                            ? _t('compliance.deviceReportsNoData')
                            : '-'),
                  hint: _t('compliance.currentBreakRemainingHint'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AspectRatio(
                aspectRatio: isDesktop ? 1.1 : 0.78,
                child: _buildLastDailyRestCard(context, lastDailyRestEnd),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _buildSectionHeader(context, _t('compliance.weeklyParametersTitle')),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: isDesktop ? 1.1 : 0.78,
                child: _buildSimpleCard(
                  context,
                  icon: Icons.event_available_outlined,
                  label: _t('compliance.lastWeeklyRestEnd'),
                  value: _fmtDateTime(lastWeeklyRestEnd),
                  hint: _t('compliance.lastWeeklyRestEndHint'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AspectRatio(
                aspectRatio: isDesktop ? 1.1 : 0.78,
                child: _buildSimpleCard(
                  context,
                  icon: Icons.king_bed_outlined,
                  label: _t('compliance.minimumWeeklyRest'),
                  value: minWeeklyRest != null
                      ? '${_fmtHM(minWeeklyRest)} sa'
                      : (appState.activeMinimumWeeklyRestUnavailable
                            ? _t('compliance.deviceReportsNoData')
                            : '-'),
                  hint: _t('compliance.minimumWeeklyRestHint'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _buildSectionHeader(context, _t('compliance.compensationDebtsTitle')),
        const SizedBox(height: 10),
        _buildCompensationDebtsPanel(context, appState),
      ],
    );
  }

  Widget _buildNextBreakCard(BuildContext context, AppState appState) {
    final scheme = Theme.of(context).colorScheme;
    final elapsed = appState.activeOpenRestElapsed;
    final targetsSecondHalf = appState.activePendingFirstHalfExists;
    final targetMinutes = targetsSecondHalf ? 30 : 45;
    final isResting = elapsed != null;
    final elapsedMinutes = isResting
        ? elapsed.inMinutes.clamp(0, targetMinutes)
        : 0;
    final isDone = isResting && elapsedMinutes >= targetMinutes;
    final percent = targetMinutes == 0
        ? 0.0
        : (elapsedMinutes / targetMinutes).clamp(0.0, 1.0);

    final String subtitle;
    if (isDone) {
      subtitle = 'Tamamlandı ✓';
    } else if (isResting) {
      subtitle = targetsSecondHalf
          ? '2. molanız sürüyor (en az 30 dk)'
          : 'Molanız sürüyor';
    } else if (targetsSecondHalf) {
      subtitle = '2. molanız en az 30 dk olmalı';
    } else {
      subtitle = 'Tek parça 45 dk, ya da önce ≥15dk sonra ≥30dk bölünmüş mola';
    }

    return _buildCardShell(
      context,
      hint: _t('compliance.nextBreakDurationHint'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  _t('compliance.nextBreakDuration'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _buildInfoIcon(
                _t('compliance.nextBreakDurationHint'),
                scheme.outline,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDone ? scheme.primary : scheme.outline,
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$elapsedMinutes ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDone ? scheme.primary : scheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: '/ $targetMinutes dk',
                  style: TextStyle(fontSize: 14, color: scheme.outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              color: isDone ? scheme.primary : scheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinDailyRestCard(
    BuildContext context,
    Duration? minDailyRest,
    bool isCrew, {
    bool unavailable = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isReduced =
        minDailyRest != null && minDailyRest <= const Duration(hours: 9);
    final crewNote = isCrew
        ? ' Ekip halinde sürüyorsunuz — bir sonraki dinlenmenizi son dinlenmenizin bitişinden itibaren 30 saat içinde almalısınız (tekli sürücüde 24 saat).'
        : '';

    return _buildCardShell(
      context,
      hint: _t('compliance.minimumDailyRestHint') + crewNote,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.king_bed_outlined,
              color: scheme.secondary,
              size: 20,
            ),
          ),
          const SizedBox(height: 10),
          _buildCardLabel(
            _t('compliance.minimumDailyRest'),
            _t('compliance.minimumDailyRestHint') + crewNote,
            scheme.outline,
          ),
          const SizedBox(height: 8),
          Text(
            minDailyRest != null
                ? '${_fmtHM(minDailyRest)} sa'
                : (unavailable ? _t('compliance.deviceReportsNoData') : '-'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          if (isReduced) ...[
            const SizedBox(height: 4),
            Text(
              _t('compliance.noCompensationNeeded'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: scheme.outline),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLastDailyRestCard(
    BuildContext context,
    DateTime? lastDailyRestEnd,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return _buildCardShell(
      context,
      hint: _t('compliance.lastDailyRestEndHint'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.bedtime_outlined,
              color: scheme.secondary,
              size: 20,
            ),
          ),
          const SizedBox(height: 10),
          _buildCardLabel(
            _t('compliance.lastDailyRestEnd'),
            _t('compliance.lastDailyRestEndHint'),
            scheme.outline,
          ),
          const SizedBox(height: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _fmtDateTime(lastDailyRestEnd),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompensationDebtsPanel(BuildContext context, AppState appState) {
    final scheme = Theme.of(context).colorScheme;
    final debts = appState.activeCompensationDebts;

    if (debts.isEmpty) {
      return _buildCardShell(
        context,
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: scheme.secondary),
            const SizedBox(width: 12),
            Text(
              _t('compliance.noCompensationDebts'),
              style: TextStyle(fontSize: 15, color: scheme.onSurface),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < debts.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _buildCardShell(
            context,
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: scheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(debts[i].labelKey),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        debts[i].remaining.inHours < 24
                            ? _t('compliance.compensationDeadlineToday')
                            : _t('compliance.daysLeft').replaceFirst(
                                '{d}',
                                '${debts[i].remaining.inDays}',
                              ),
                        style: TextStyle(fontSize: 12, color: scheme.error),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_fmtHM(debts[i].owed)} sa',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _fmtDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m $h:$min';
  }

  Widget _buildCardShell(
    BuildContext context, {
    required Widget child,
    String? hint,
  }) {
    final shell = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
    if (hint == null || hint.isEmpty) return shell;
    return Tooltip(
      message: hint,
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: true,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      textStyle: const TextStyle(fontSize: 13, color: Colors.white),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: shell,
    );
  }

  Widget _buildCardLabel(String label, String? hint, Color color) {
    final labelText = Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.2,
      ),
    );
    if (hint == null || hint.isEmpty) return labelText;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 18),
        Expanded(child: labelText),
        const SizedBox(width: 4),
        _buildInfoIcon(hint, color),
      ],
    );
  }

  Widget _buildInfoIcon(String hint, Color color, {double size = 14}) {
    return Icon(Icons.info_outline, size: size, color: color);
  }

  Widget _buildSectionHeader(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: 6, bottom: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: scheme.secondaryContainer,
                offset: const Offset(6, 6),
              ),
            ],
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: scheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedBar(
    BuildContext context, {
    required int total,
    required int filled,
    required Color filledColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(total, (i) {
        final isFilled = i < filled;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 4),
            height: 6,
            decoration: BoxDecoration(
              color: isFilled ? filledColor : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSimpleCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    String? hint,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return _buildCardShell(
      context,
      hint: hint,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: scheme.secondary, size: 20),
          ),
          const SizedBox(height: 10),
          _buildCardLabel(label, hint, scheme.outline),
          const SizedBox(height: 8),

          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required DrivingRuleResult? rule,
    required Duration limit,
    String? hint,
    bool unavailable = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final limitH = limit.inHours;

    final usedStr = rule != null
        ? '${rule.used.inHours}'
        : (unavailable ? _t('compliance.deviceReportsNoData') : '-');
    return _buildCardShell(
      context,
      hint: hint,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: scheme.outline, size: 20),
          const SizedBox(height: 10),
          _buildCardLabel(label, hint, scheme.outline),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$usedStr ',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: '/$limitH sa',
                  style: TextStyle(fontSize: 14, color: scheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinuousUsageCard(
    BuildContext context,
    DrivingRuleResult? rule,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final used = rule?.used ?? Duration.zero;
    final limit = rule?.limit ?? DrivingTimeCalculator.continuousDrivingLimit;
    final isCritical = rule != null && (rule.isWarning || rule.isExceeded);
    final percent = limit.inMinutes == 0
        ? 0.0
        : (used.inMinutes / limit.inMinutes).clamp(0.0, 1.0);
    final accentColor = isCritical ? scheme.primary : scheme.secondary;

    return _buildCardShell(
      context,
      hint: _t('compliance.continuousUsageHint'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.timer, color: accentColor, size: 20),
          const SizedBox(height: 8),
          _buildCardLabel(
            _t('compliance.continuousUsage'),
            _t('compliance.continuousUsageHint'),
            scheme.outline,
          ),
          const SizedBox(height: 8),
          Text(
            rule == null ? '-' : '${_fmtHM(used)} sa',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isCritical ? scheme.primary : scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 5,
              backgroundColor: scheme.surfaceContainerHighest,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyUsageCard(
    BuildContext context,
    DrivingRuleResult? daily, {
    bool unavailable = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final used = daily?.used ?? Duration.zero;
    final limit = daily?.limit ?? DrivingTimeCalculator.dailyDrivingLimit;
    final percent = limit.inMinutes == 0
        ? 0.0
        : (used.inMinutes / limit.inMinutes).clamp(0.0, 1.0);

    return _buildCardShell(
      context,
      hint: _t('compliance.dailyUsageHint'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  _t('compliance.dailyUsage'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _buildInfoIcon(
                _t('compliance.dailyUsageHint'),
                scheme.outline,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text:
                      '${daily != null ? _fmtHM(used) : (unavailable ? _t('compliance.deviceReportsNoData') : '-')} ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: '/ ${_fmtHM(limit)} sa',
                  style: TextStyle(fontSize: 14, color: scheme.outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              color: percent >= 1.0 ? scheme.secondary : scheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemaining10hCard(BuildContext context, int? remaining10h) {
    final scheme = Theme.of(context).colorScheme;
    final isCritical = remaining10h != null && remaining10h <= 0;

    return _buildCardShell(
      context,
      hint: _t('compliance.remaining10hHint'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  _t('compliance.remaining10h'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _buildInfoIcon(
                _t('compliance.remaining10hHint'),
                scheme.outline,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${remaining10h ?? '-'} ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isCritical ? scheme.error : scheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: '/ 2',
                  style: TextStyle(fontSize: 14, color: scheme.outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildSegmentedBar(
            context,
            total: 2,

            filled: remaining10h == null ? 0 : remaining10h.clamp(0, 2),
            filledColor: scheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildReducedRestCard(
    BuildContext context,
    int? remainingReducedRest,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isCritical =
        remainingReducedRest != null && remainingReducedRest <= 0;

    return _buildCardShell(
      context,
      hint: _t('compliance.remainingReducedRestHint'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  _t('compliance.remainingReducedRest'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _buildInfoIcon(
                _t('compliance.remainingReducedRestHint'),
                scheme.outline,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${remainingReducedRest ?? '-'} ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isCritical ? scheme.error : scheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: '/ 3',
                  style: TextStyle(fontSize: 14, color: scheme.outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildSegmentedBar(
            context,
            total: 3,

            filled: remainingReducedRest == null
                ? 0
                : remainingReducedRest.clamp(0, 3),
            filledColor: scheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildViolationSummaryCard(BuildContext context, AppState appState) {
    if (!appState.rolePermissions.viewViolations)
      return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final violations = appState.violations;
    final hasViolations = violations.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.go('/logs'),
      child: _buildCardShell(
        context,
        child: Row(
          children: [
            Icon(
              hasViolations ? Icons.warning_amber : Icons.check_circle,
              color: hasViolations ? scheme.error : scheme.secondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasViolations
                    ? '${violations.length} ${_t('violation.severityViolation')}'
                    : _t('compliance.noViolations'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.outline),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedAndDistanceWidget(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final liveData = appState.tachographLiveData;
    final hasData = appState.hasTachographData;
    final speedStr = hasData ? '${liveData.speedKmh} ' : '- ';

    final distStr = hasData
        ? '${liveData.odometerKm.toStringAsFixed(1)} '
        : '- ';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _t('dashboard.drivingData'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 24,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: speedStr,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: -1.5,
                          ),
                        ),
                        TextSpan(
                          text: 'km/h',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.speed,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _t('dashboard.speed'),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                width: 1,
                height: 48,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: distStr,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.tertiary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: 'km',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.route,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _t('dashboard.distance'),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUntilBreakCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appState = AppStateProvider.of(context);
    final continuous = appState.activeDrivingRules['continuous'];

    final remaining =
        appState.activeTimeUntilNextBreakOrRest ?? continuous?.remaining;
    final isCritical =
        continuous != null && (continuous.isWarning || continuous.isExceeded);
    final gradientColors = isCritical
        ? [scheme.secondary, scheme.primaryContainer]
        : [scheme.primary, scheme.secondaryContainer];

    final hint = _t('compliance.timeUntilBreakHint');
    return Tooltip(
      message: hint,
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: true,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      textStyle: const TextStyle(fontSize: 13, color: Colors.white),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _t('compliance.timeUntilBreak').toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              _buildInfoIcon(hint, scheme.primary, size: 13),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: 128,
            height: 128,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      remaining == null ? '-' : _fmtHM(remaining),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _t('compliance.hoursUnit'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.outline,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverModeButton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/driver-mode'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.speed_outlined, color: scheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _t('driverMode.button'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      _t('driverMode.buttonHint'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
