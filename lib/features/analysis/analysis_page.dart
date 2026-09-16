import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../core/models/role_permissions.dart';
import '../../core/providers/app_state.dart';
import '../../core/localization/localization.dart';
import '../../core/services/driving_time_calculator.dart';
import '../../core/services/penalty_calculator.dart';
import '../../core/services/risk_score_calculator.dart';
import '../../core/services/violation_analyzer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/activity_day_bar_chart.dart';
import '../../core/widgets/bluetooth_warning_banner.dart';
import '../../core/widgets/card_slot_warning_banner.dart';
import 'route_map_card.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  bool _isPremiumPreview = false;

  static const _riskColorLow = Color(0xFF2E7D32);
  static const _riskColorMedium = Color(0xFFF59E0B);
  static const _riskColorHigh = Color(0xFFBA1A1A);

  final ViolationAnalyzer _violationAnalyzer = ViolationAnalyzer();
  final PenaltyCalculator _penaltyCalculator = PenaltyCalculator();
  final RiskScoreCalculator _riskScoreCalculator = RiskScoreCalculator();

  String _t(String key) {
    return AppLocalizations.getText(
      AppStateProvider.of(context).selectedLanguage,
      key,
    );
  }

  String _formatDate(DateTime date) {
    return AppLocalizations.formatDate(
      AppStateProvider.of(context).selectedLanguage,
      date,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopLayout(context);
    final padding = isDesktop
        ? const EdgeInsets.all(48)
        : const EdgeInsets.all(16);

    final appState = AppStateProvider.of(context);

    final now = DateTime.now().toUtc();
    final allViolations = _violationAnalyzer.analyze(appState.activityLog, now);
    final windowStart = now.subtract(RiskScoreCalculator.defaultWindow);
    final recent =
        allViolations.where((v) => v.end.isAfter(windowStart)).toList()
          ..sort((a, b) => b.start.compareTo(a.start));
    final asCompany = appState.activeRole == AppRole.company;
    final risk = _riskScoreCalculator.calculate(recent);
    final breakdown = _penaltyCalculator.breakdownByType(
      recent,
      asCompany: asCompany,
    );
    final totalTl = _penaltyCalculator.totalTl(recent, asCompany: asCompany);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SingleChildScrollView(
        child: Padding(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BluetoothWarningBanner(),
                  const CardSlotWarningBanner(),
                  _buildHeader(context, isDesktop),
                  const SizedBox(height: 16),
                  _buildSelectorRow(context),
                  const SizedBox(height: 24),
                  _buildHeroRiskCard(context, risk, recent.length),
                  const SizedBox(height: 24),
                  _buildLockableSection(
                    context,
                    isDesktop,
                    recent,
                    breakdown,
                    totalTl,
                    asCompany,
                    appState,
                    now,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          child: Text(
            _t('analysis.pageTitle'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 32 : 24,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
              letterSpacing: isDesktop ? -0.64 : -0.24,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,

          child: OutlinedButton.icon(
            onPressed: () =>
                setState(() => _isPremiumPreview = !_isPremiumPreview),
            icon: Icon(
              _isPremiumPreview ? Icons.lock_open : Icons.lock_outline,
              size: 16,
            ),
            label: Text(
              _isPremiumPreview
                  ? _t('analysis.previewTogglePremium')
                  : _t('analysis.previewToggleLocked'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
              side: BorderSide(color: scheme.outlineVariant),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorRow(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final live = appState.tachographLiveData;
    final isDriver1 = appState.activeDriver == 'driver1';
    final driverName = (isDriver1 ? live.driver1Name : live.driver2Name).trim();
    final vehicleReg = live.vrn.trim();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 260,
          child: _buildSelectorChip(
            context,
            icon: Icons.person,
            label: driverName.isNotEmpty ? driverName : '-',
          ),
        ),
        SizedBox(
          width: 260,
          child: _buildSelectorChip(
            context,
            icon: Icons.local_shipping,
            label: vehicleReg.isNotEmpty
                ? vehicleReg
                : _t('analysis.vehicleLabel'),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
            ),
          ),
          Icon(Icons.expand_more, size: 18, color: scheme.outline),
        ],
      ),
    );
  }

  Widget _buildHeroRiskCard(
    BuildContext context,
    RiskScoreResult risk,
    int violationCount,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final riskColor = _riskColorFor(risk.score);
    final riskLevelKey = _riskLevelKeyFor(risk.score);
    final summary = violationCount == 0
        ? _t('analysis.riskSummaryClean')
        : _t('analysis.riskSummary').replaceFirst('{count}', '$violationCount');

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            _t('analysis.riskScoreLabel'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.outline,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          CircularPercentIndicator(
            radius: 100,
            lineWidth: 16,
            percent: risk.score / 100,
            arcType: ArcType.HALF,
            arcBackgroundColor: scheme.surfaceContainerHighest,
            progressColor: riskColor,
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animationDuration: 800,
            center: Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${risk.score}',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                      height: 1,
                    ),
                  ),
                  Text(
                    '/ 100',
                    style: TextStyle(fontSize: 13, color: scheme.outline),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: riskColor),
                const SizedBox(width: 6),
                Text(
                  _t(riskLevelKey),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: riskColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            summary,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Color _riskColorFor(int score) {
    if (score >= 80) return _riskColorLow;
    if (score >= 50) return _riskColorMedium;
    return _riskColorHigh;
  }

  String _riskLevelKeyFor(int score) {
    if (score >= 80) return 'analysis.riskLevelLow';
    if (score >= 50) return 'analysis.riskLevelMedium';
    return 'analysis.riskLevelHigh';
  }

  Widget _buildLockableSection(
    BuildContext context,
    bool isDesktop,
    List<Violation> recent,
    List<PenaltyBreakdownEntry> breakdown,
    int totalTl,
    bool asCompany,
    AppState appState,
    DateTime now,
  ) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildExposureCard(context, recent, breakdown, totalTl, asCompany, now),
        const SizedBox(height: 24),
        _buildActivityTimelineCard(context, appState.activityLog, recent, now),
        const SizedBox(height: 24),
        const RouteMapCard(),
        const SizedBox(height: 24),
        _buildViolationsListCard(context, recent, asCompany),
      ],
    );

    return Stack(
      children: [
        IgnorePointer(
          ignoring: !_isPremiumPreview,
          child: _isPremiumPreview
              ? content
              : ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: content,
                ),
        ),
        if (!_isPremiumPreview)
          Positioned.fill(child: _buildPaywallOverlay(context)),
      ],
    );
  }

  Widget _buildExposureCard(
    BuildContext context,
    List<Violation> recent,
    List<PenaltyBreakdownEntry> breakdown,
    int totalTl,
    bool asCompany,
    DateTime now,
  ) {
    final scheme = Theme.of(context).colorScheme;

    final weeklyTotals = _weeklyTotals(recent, now, asCompany: asCompany);
    final maxWeekly = weeklyTotals.fold<int>(0, (m, v) => v > m ? v : m);
    final trendPct = weeklyTotals[2] > 0
        ? ((weeklyTotals[3] - weeklyTotals[2]) / weeklyTotals[2] * 100).round()
        : null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t('analysis.penaltyExposureLabel'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.outline,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTl(totalTl),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              if (trendPct != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: trendPct > 0
                        ? scheme.errorContainer
                        : scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${trendPct > 0 ? '+' : ''}$trendPct%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: trendPct > 0
                          ? scheme.onErrorContainer
                          : scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (asCompany) ...[
            const SizedBox(height: 4),
            Text(
              _t('analysis.companyMultiplierFootnote'),
              style: TextStyle(fontSize: 11, color: scheme.outline),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 64,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < weeklyTotals.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: FractionallySizedBox(
                      heightFactor: maxWeekly > 0
                          ? max(weeklyTotals[i] / maxWeekly, 0.04)
                          : 0.04,
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          color: i == weeklyTotals.length - 1
                              ? scheme.primary
                              : scheme.surfaceContainerHighest,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _t('analysis.penaltyExposureTrend'),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (breakdown.isNotEmpty) ...[
            const SizedBox(height: 18),
            Divider(color: scheme.outlineVariant),
            const SizedBox(height: 8),
            Text(
              _t('analysis.penaltyBreakdownLabel'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.outline,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),
            for (final entry in breakdown) _buildBreakdownRow(context, entry),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(BuildContext context, PenaltyBreakdownEntry entry) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _t(_violationTypeLabelKey(entry.type)),
              style: TextStyle(fontSize: 13, color: scheme.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '×${entry.count}',
            style: TextStyle(fontSize: 11, color: scheme.outline),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTl(entry.totalTl),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  List<int> _weeklyTotals(
    List<Violation> recent,
    DateTime now, {
    required bool asCompany,
  }) {
    final totals = List<int>.filled(4, 0);
    for (final v in recent) {
      final daysAgo = now.difference(v.end).inDays;
      final weeksAgo = (daysAgo / 7).floor().clamp(0, 3);
      final index = 3 - weeksAgo;
      totals[index] +=
          _penaltyCalculator.estimate(v, asCompany: asCompany).amountTl ?? 0;
    }
    return totals;
  }

  String _formatTl(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '₺$buf';
  }

  String _violationTypeLabelKey(ViolationType type) {
    switch (type) {
      case ViolationType.continuousDrivingExceeded:
        return 'violation.continuousDrivingExceeded';
      case ViolationType.dailyDrivingExceeded:
        return 'violation.dailyDrivingExceeded';
      case ViolationType.weeklyDrivingExceeded:
        return 'violation.weeklyDrivingExceeded';
      case ViolationType.biWeeklyDrivingExceeded:
        return 'violation.biWeeklyDrivingExceeded';
      case ViolationType.dailyRestInsufficient:
        return 'violation.dailyRestInsufficient';
      case ViolationType.weeklyRestInsufficient:
        return 'violation.weeklyRestInsufficient';
      case ViolationType.missingRecord:
        return 'violation.missingRecord';
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildActivityTimelineCard(
    BuildContext context,
    List<TachographActivity> activityLog,
    List<Violation> recent,
    DateTime now,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final byDay = _groupActivitiesByDay(activityLog);
    final last7Days = byDay.keys.toList()
      ..sort((a, b) => b.compareTo(a))
      ..take(7);
    final last7 = last7Days.take(7).toList();

    final violationDays = recent
        .map((v) => DateTime.utc(v.start.year, v.start.month, v.start.day))
        .toSet();

    final thisWeekStart = now.subtract(const Duration(days: 7));
    final lastWeekStart = now.subtract(const Duration(days: 14));
    final thisWeekMinutes = _totalDrivingMinutes(
      activityLog,
      thisWeekStart,
      now,
    );
    final lastWeekMinutes = _totalDrivingMinutes(
      activityLog,
      lastWeekStart,
      thisWeekStart,
    );
    final thisWeekViolations = recent
        .where((v) => v.start.isAfter(thisWeekStart))
        .length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_view_day, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t('analysis.activityTimelineLabel'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildKpiStrip(
            context,
            thisWeekMinutes,
            lastWeekMinutes,
            thisWeekViolations,
          ),
          const SizedBox(height: 20),
          Text(
            _t('analysis.trend28DaysLabel'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: scheme.outline,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          _buildTrendSparkline(context, activityLog, violationDays, now),
          const SizedBox(height: 24),
          if (last7.isEmpty)
            Text(_t('timeline.noData'), style: TextStyle(color: scheme.outline))
          else
            for (final day in last7) ...[
              _buildPremiumDayRow(
                context,
                day,
                byDay[day]!,
                violationDays.contains(day),
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 8),
          ActivityChartLegend(
            drivingColor: scheme.primary,
            drivingLabel: _t('timeline.driving'),
            breakLabel: _t('timeline.break_'),
            workLabel: _t('timeline.otherWork'),
            availableLabel: _t('timeline.available'),
            unknownLabel: _t('violation.missingRecord'),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiStrip(
    BuildContext context,
    int thisWeekMinutes,
    int lastWeekMinutes,
    int thisWeekViolations,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final trend = lastWeekMinutes > 0
        ? ((thisWeekMinutes - lastWeekMinutes) / lastWeekMinutes * 100).round()
        : null;
    return Row(
      children: [
        Expanded(
          child: _kpiTile(
            context,
            label: _t('analysis.thisWeekDrivingLabel'),
            value: _formatDuration(Duration(minutes: thisWeekMinutes)),
            trend: trend,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _kpiTile(
            context,
            label: _t('analysis.thisWeekViolationsLabel'),
            value: '$thisWeekViolations',
            trend: null,
            valueColor: thisWeekViolations > 0 ? scheme.error : null,
          ),
        ),
      ],
    );
  }

  Widget _kpiTile(
    BuildContext context, {
    required String label,
    required String value,
    int? trend,
    Color? valueColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: scheme.outline)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? scheme.onSurface,
                ),
              ),
              if (trend != null) ...[
                const SizedBox(width: 6),
                Icon(
                  trend >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: scheme.outline,
                ),
                Text(
                  '${trend.abs()}%',
                  style: TextStyle(fontSize: 11, color: scheme.outline),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendSparkline(
    BuildContext context,
    List<TachographActivity> activityLog,
    Set<DateTime> violationDays,
    DateTime now,
  ) {
    final scheme = Theme.of(context).colorScheme;
    const days = 28;
    final todayStart = DateTime.utc(now.year, now.month, now.day);
    final bars = <Widget>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = todayStart.subtract(Duration(days: i));
      final dayEnd = day.add(const Duration(days: 1));
      final minutes = _totalDrivingMinutes(activityLog, day, dayEnd);
      final heightFactor = (minutes / (9 * 60)).clamp(0.04, 1.0);
      final isViolationDay = violationDays.contains(day);
      bars.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: FractionallySizedBox(
              heightFactor: heightFactor,
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: isViolationDay
                      ? scheme.error
                      : scheme.primary.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 40,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: bars),
    );
  }

  Widget _buildPremiumDayRow(
    BuildContext context,
    DateTime day,
    List<TachographActivity> dayActivities,
    bool hasViolation,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final dayStart = day;
    final dayEnd = day.add(const Duration(days: 1));
    var drivingMinutes = 0;
    var breakMinutes = 0;
    for (final a in dayActivities) {
      final start = a.startTime.isBefore(dayStart) ? dayStart : a.startTime;
      final end = a.endTime.isAfter(dayEnd) ? dayEnd : a.endTime;
      final minutes = end.difference(start).inMinutes;
      if (minutes <= 0) continue;
      if (a.type == ActivityType.driving) drivingMinutes += minutes;
      if (a.type == ActivityType.rest) breakMinutes += minutes;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasViolation
            ? scheme.errorContainer.withValues(alpha: 0.15)
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _formatDate(day),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              if (hasViolation)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: scheme.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _t('timeline.violation'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.error,
                      ),
                    ),
                  ],
                ),
              Text(
                '${_t('timeline.driving')} ${_formatDuration(Duration(minutes: drivingMinutes))}',
                style: TextStyle(fontSize: 11, color: scheme.outline),
              ),
              Text(
                '${_t('timeline.break_')} ${_formatDuration(Duration(minutes: breakMinutes))}',
                style: TextStyle(fontSize: 11, color: scheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ActivityDayBarChart(
            activities: dayActivities,
            day: day,
            height: 30,
            borderRadius: 14,
            useGradient: true,
            elevated: true,
          ),
        ],
      ),
    );
  }

  int _totalDrivingMinutes(
    List<TachographActivity> log,
    DateTime from,
    DateTime to,
  ) {
    var total = 0;
    for (final a in log) {
      if (a.type != ActivityType.driving) continue;
      final start = a.startTime.isBefore(from) ? from : a.startTime;
      final end = a.endTime.isAfter(to) ? to : a.endTime;
      final minutes = end.difference(start).inMinutes;
      if (minutes > 0) total += minutes;
    }
    return total;
  }

  Map<DateTime, List<TachographActivity>> _groupActivitiesByDay(
    List<TachographActivity> log,
  ) {
    final byDay = <DateTime, List<TachographActivity>>{};
    for (final a in log) {
      var cursor = DateTime.utc(
        a.startTime.year,
        a.startTime.month,
        a.startTime.day,
      );
      final effectiveEnd = a.endTime.subtract(const Duration(microseconds: 1));
      final endDay = DateTime.utc(
        effectiveEnd.year,
        effectiveEnd.month,
        effectiveEnd.day,
      );
      while (!cursor.isAfter(endDay)) {
        (byDay[cursor] ??= []).add(a);
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return byDay;
  }

  Widget _buildViolationsListCard(
    BuildContext context,
    List<Violation> recent,
    bool asCompany,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _t('analysis.violationsListLabel'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  _t('analysis.last28Days'),
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
              ],
            ),
          ),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: scheme.secondary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _t('analysis.noViolationsInWindow'),
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            for (final v in recent) _buildViolationRow(context, v, asCompany),
        ],
      ),
    );
  }

  Widget _buildViolationRow(BuildContext context, Violation v, bool asCompany) {
    final scheme = Theme.of(context).colorScheme;
    final estimate = _penaltyCalculator.estimate(v, asCompany: asCompany);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: v.severity == ViolationSeverity.violation
                  ? scheme.errorContainer
                  : scheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _violationIcon(v.type),
              color: v.severity == ViolationSeverity.violation
                  ? scheme.error
                  : scheme.outline,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(v.descriptionKey),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${v.ruleReference} • ${_formatDateTime(v.start)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _t('analysis.estimatedPenalty'),
                style: TextStyle(fontSize: 11, color: scheme.outline),
              ),
              if (estimate.isRealFine)
                Row(
                  children: [
                    if (estimate.isCompanyRate) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '×2',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _formatTl(estimate.amountTl!),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: scheme.error,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  _t('analysis.missingRecordNotFine'),
                  style: TextStyle(fontSize: 11, color: scheme.outline),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _violationIcon(ViolationType type) {
    switch (type) {
      case ViolationType.continuousDrivingExceeded:
        return Icons.timer_off;
      case ViolationType.dailyDrivingExceeded:
      case ViolationType.weeklyDrivingExceeded:
      case ViolationType.biWeeklyDrivingExceeded:
        return Icons.speed;
      case ViolationType.dailyRestInsufficient:
      case ViolationType.weeklyRestInsufficient:
        return Icons.bedtime_outlined;
      case ViolationType.missingRecord:
        return Icons.help_outline;
    }
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.${dt.year} $h:$min';
  }

  Widget _buildPaywallOverlay(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(top: 12),
      color: scheme.surface.withValues(alpha: 0.55),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.lock,
                color: scheme.onSecondaryContainer,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _t('analysis.lockedTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _t('analysis.lockedMessage'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFeatureBullet(
                    context,
                    _t('analysis.featureViolationTracking'),
                  ),
                  _buildFeatureBullet(context, _t('analysis.featureExport')),
                  _buildFeatureBullet(
                    context,
                    _t('analysis.featurePredictiveAlerts'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => setState(() => _isPremiumPreview = true),
                icon: const Icon(Icons.workspace_premium, size: 20),
                label: Text(
                  _t('analysis.upgradeButton'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _t('analysis.priceFootnote'),
              style: TextStyle(fontSize: 11, color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBullet(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
