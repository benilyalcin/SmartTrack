import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/role_permissions.dart';
import '../../core/providers/app_state.dart';
import '../../core/localization/localization.dart';
import '../../core/services/google_drive_service.dart';
import '../../core/services/penalty_calculator.dart';
import '../../core/services/risk_score_calculator.dart';
import '../../core/services/violation_analyzer.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/bluetooth_warning_banner.dart';
import '../../core/widgets/card_slot_warning_banner.dart';
import 'severity_reference.dart';

/// A violation together with its fine estimate.
typedef _FinedViolation = ({Violation violation, PenaltyEstimate estimate});

class _InsightCard {
  final String title;
  final IconData icon;
  final List<int> values;
  final String chartCaption;
  final String? avgLabel;
  final String description;
  final bool isPositive;
  final List<Violation> violations;

  const _InsightCard({
    required this.title,
    required this.icon,
    required this.values,
    required this.chartCaption,
    this.avgLabel,
    required this.description,
    required this.isPositive,
    required this.violations,
  });
}

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage>
    with SingleTickerProviderStateMixin {
  /// The day the user is looking at (local date). The page analyses the
  /// Monday–Sunday calendar week that contains it.
  DateTime _selectedDay = _dateOnly(DateTime.now());

  bool _notificationsEnabled = true;
  bool _autoDddDownload = true;
  int _insightIndex = 0;

  GoogleSignInAccount? _driveUser;
  bool _isDriveBackupEnabled = false;
  bool _isDriveConnecting = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseOpacity;

  final ViolationAnalyzer _violationAnalyzer = ViolationAnalyzer();
  final PenaltyCalculator _penaltyCalculator = PenaltyCalculator();
  final RiskScoreCalculator _riskScoreCalculator = RiskScoreCalculator();

  static const _riskColorLow = Color(0xFF2E7D32);
  static const _riskColorMedium = Color(0xFFF59E0B);
  static const _riskColorHigh = Color(0xFFBA1A1A);

  static const List<BoxShadow> _softShadow = [
    BoxShadow(color: Color(0x14000000), offset: Offset(0, 1), blurRadius: 3),
  ];

  static const _weekdayShortTR = [
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];
  static const _weekdayShortEN = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const _weekdayShortDE = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  static const _weekdayLongTR = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];
  static const _weekdayLongEN = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _weekdayLongDE = [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulseOpacity = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadDriveState();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadDriveState() async {
    final enabled = await GoogleDriveService.instance.isBackupEnabled();
    final user = await GoogleDriveService.instance.signInSilently();
    if (!mounted) return;
    setState(() {
      _isDriveBackupEnabled = enabled;
      _driveUser = user;
    });
  }

  Future<void> _connectDrive() async {
    setState(() => _isDriveConnecting = true);
    try {
      final user = await GoogleDriveService.instance.signIn();
      if (!mounted) return;
      setState(() {
        _driveUser = user;
        if (user != null) _isDriveBackupEnabled = true;
      });
      if (user != null) {
        await GoogleDriveService.instance.setBackupEnabled(true);
      }
    } catch (e) {
      debugPrint('Google Drive sign-in failed: $e');
      if (mounted) {
        showAppSnackBar(
          context,
          _t('ddd.driveConnectError'),
          type: AppSnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isDriveConnecting = false);
    }
  }

  Future<void> _disconnectDrive() async {
    await GoogleDriveService.instance.signOut();
    await GoogleDriveService.instance.setBackupEnabled(false);
    if (!mounted) return;
    setState(() {
      _driveUser = null;
      _isDriveBackupEnabled = false;
    });
  }

  Future<void> _toggleDriveBackup() async {
    final next = !_isDriveBackupEnabled;
    setState(() => _isDriveBackupEnabled = next);
    await GoogleDriveService.instance.setBackupEnabled(next);
  }

  String _t(String key) {
    return AppLocalizations.getText(
      AppStateProvider.of(context).selectedLanguage,
      key,
    );
  }

  String _weekdayShort(int weekday, String lang) {
    final names = lang == 'EN'
        ? _weekdayShortEN
        : lang == 'DE'
        ? _weekdayShortDE
        : _weekdayShortTR;
    return names[weekday - 1];
  }

  String _weekdayLong(int weekday, String lang) {
    final names = lang == 'EN'
        ? _weekdayLongEN
        : lang == 'DE'
        ? _weekdayLongDE
        : _weekdayLongTR;
    return names[weekday - 1];
  }

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

  String _hourMinute(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // Calendar-day helpers. They work on local dates and use DateTime
  // constructor arithmetic so day steps stay correct across DST changes.
  static DateTime _dateOnly(DateTime d) {
    final local = d.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime _addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  static DateTime _weekStartOf(DateTime d) {
    final day = _dateOnly(d);
    return _addDays(day, -(day.weekday - 1));
  }

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Index (0 = Monday … 6 = Sunday) of the local day [instant] falls on
  /// within the week starting at [weekStart], or -1 if outside that week.
  static int _dayIndexInWeek(DateTime weekStart, DateTime instant) {
    final date = _dateOnly(instant);
    for (var i = 0; i < 7; i++) {
      if (_sameDate(_addDays(weekStart, i), date)) return i;
    }
    return -1;
  }

  String _shortDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m.${dt.year} $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final lang = appState.selectedLanguage;

    // The selected Monday–Sunday week. Violations are found over all data and
    // then picked by week; the risk score of a past week only counts
    // violations up to that week's Sunday midnight.
    final now = DateTime.now();
    final weekStart = _weekStartOf(_selectedDay);
    final weekEnd = _addDays(weekStart, 7);
    final referenceNow = now.isBefore(weekEnd) ? now : weekEnd;

    final allViolations = _violationAnalyzer.analyze(
      appState.activityLog,
      now.toUtc(),
    );
    final windowStart = referenceNow.subtract(
      RiskScoreCalculator.defaultWindow,
    );
    final recent =
        allViolations
            .where(
              (v) =>
                  v.end.isAfter(windowStart) && !v.start.isAfter(referenceNow),
            )
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));
    final asCompany = appState.activeRole == AppRole.company;
    final risk = _riskScoreCalculator.calculate(recent);

    final weekViolations = allViolations
        .where((v) => !v.start.isBefore(weekStart) && v.start.isBefore(weekEnd))
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BluetoothWarningBanner(),
                    const CardSlotWarningBanner(),
                    _buildTopStatusRow(context, appState),
                    const SizedBox(height: 16),
                    _buildHeroRiskCard(context, risk, recent.length),
                    const SizedBox(height: 16),
                    _buildWeekNavigationRow(context, weekStart),
                    const SizedBox(height: 16),
                    _buildPenaltyTrendCard(
                      context,
                      weekViolations,
                      asCompany,
                      weekStart,
                      lang,
                    ),
                    const SizedBox(height: 16),
                    _buildNotificationsCard(context),
                    const SizedBox(height: 16),
                    _buildInsightCarousel(context, weekViolations, weekStart),
                    const SizedBox(height: 16),
                    _buildDrivingModeCard(context),
                    const SizedBox(height: 16),
                    _buildBackupSection(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 1. Driver/vehicle selector + connection status pill
  // ---------------------------------------------------------------------

  Widget _buildTopStatusRow(BuildContext context, AppState appState) {
    final scheme = Theme.of(context).colorScheme;
    final live = appState.tachographLiveData;
    final isDriver1 = appState.activeDriver == 'driver1';
    final activeName = (isDriver1 ? live.driver1Name : live.driver2Name).trim();
    final displayName = activeName.isNotEmpty
        ? activeName
        : '${_t('analysis.driverLabel')} ${isDriver1 ? '1' : '2'}';
    final connected = appState.isBluetoothConnected;

    return Row(
      children: [
        Expanded(
          child: PopupMenuButton<String>(
            tooltip: '',
            offset: const Offset(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) => appState.setActiveDriver(value),
            itemBuilder: (menuContext) {
              final items = <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'driver1',
                  child: Text(
                    '${live.driver1Name.trim().isNotEmpty ? live.driver1Name.trim() : '${_t('analysis.driverLabel')} 1'} '
                    '(${isDriver1 ? _t('analysis.activeSuffix') : _t('analysis.backupDriverSuffix')})',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ];
              if (appState.isCrew) {
                items.add(
                  PopupMenuItem<String>(
                    value: 'driver2',
                    child: Text(
                      '${live.driver2Name.trim().isNotEmpty ? live.driver2Name.trim() : '${_t('analysis.driverLabel')} 2'} '
                      '(${!isDriver1 ? _t('analysis.activeSuffix') : _t('analysis.backupDriverSuffix')})',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                );
              }
              if (live.vrn.trim().isNotEmpty) {
                items.add(
                  PopupMenuItem<String>(
                    value: 'info',
                    enabled: false,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_shipping,
                          size: 16,
                          color: scheme.outline,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          live.vrn.trim(),
                          style: TextStyle(fontSize: 12, color: scheme.outline),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return items;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _softShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: scheme.primary,
                    child: Icon(
                      Icons.person,
                      size: 14,
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${_t('analysis.driverLabel')}: $displayName',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: connected
                ? scheme.secondaryContainer
                : scheme.errorContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: connected
                    ? _pulseOpacity
                    : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected ? scheme.primary : scheme.error,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _t(
                  connected
                      ? 'analysis.connectionConnected'
                      : 'analysis.connectionDisconnected',
                ),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: connected
                      ? scheme.onSecondaryContainer
                      : scheme.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 2. Risk score gauge card
  // ---------------------------------------------------------------------

  Widget _buildHeroRiskCard(
    BuildContext context,
    RiskScoreResult risk,
    int violationCount,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final riskColor = _riskColorFor(risk.score);
    final riskLevelKey = _riskLevelKeyFor(risk.score);
    final taglineKey = risk.score >= 80
        ? 'analysis.riskGaugeTaglineLow'
        : risk.score >= 50
        ? 'analysis.riskGaugeTaglineMedium'
        : 'analysis.riskGaugeTaglineHigh';
    final countText = violationCount == 0
        ? _t('analysis.violationCountNone')
        : _t(
            'analysis.violationCountSuffix',
          ).replaceFirst('{count}', '$violationCount');

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => _openRiskBreakdownSheet(context, risk),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _buildHeroRiskContent(
              context,
              risk,
              riskColor: riskColor,
              riskLevelKey: riskLevelKey,
              taglineKey: taglineKey,
              countText: countText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroRiskContent(
    BuildContext context,
    RiskScoreResult risk, {
    required Color riskColor,
    required String riskLevelKey,
    required String taglineKey,
    required String countText,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _t('analysis.riskScoreLabel'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            Icon(Icons.verified_user, color: scheme.outline, size: 20),
          ],
        ),
        const SizedBox(height: 4),
        CircularPercentIndicator(
          radius: 92,
          lineWidth: 15,
          percent: risk.score / 100,
          arcType: ArcType.HALF,
          arcBackgroundColor: scheme.surfaceContainerHighest,
          progressColor: riskColor,
          circularStrokeCap: CircularStrokeCap.round,
          animation: true,
          animationDuration: 800,
          center: Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${risk.score}',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '/ 100',
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _t(taglineKey),
                  style: TextStyle(fontSize: 11, color: scheme.outline),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(999),
            boxShadow: _softShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield, size: 15, color: scheme.primary),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  '${_t(riskLevelKey)} ($countText)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: scheme.onSecondaryContainer,
              ),
            ],
          ),
        ),
      ],
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

  // ---------------------------------------------------------------------
  // 3. Date navigation row + calendar modal
  // ---------------------------------------------------------------------

  Widget _buildWeekNavigationRow(BuildContext context, DateTime weekStart) {
    final scheme = Theme.of(context).colorScheme;
    final weekLastDay = _addDays(weekStart, 6);
    final label = _t('analysis.weekRangeLabel').replaceFirst(
      '{range}',
      '${_shortDate(weekStart)} - ${_shortDate(weekLastDay)}',
    );
    final today = _dateOnly(DateTime.now());
    final canGoForward = weekStart.isBefore(_weekStartOf(today));

    return Row(
      children: [
        _weekNavButton(
          context,
          icon: Icons.chevron_left,
          label: _t('analysis.prevWeek'),
          iconFirst: true,
          onTap: () =>
              setState(() => _selectedDay = _addDays(_selectedDay, -7)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 40,
            child: FilledButton.icon(
              onPressed: () => _openCalendarModal(context),
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _weekNavButton(
          context,
          icon: Icons.chevron_right,
          label: _t('analysis.nextWeek'),
          iconFirst: false,
          onTap: canGoForward
              ? () => setState(() {
                  final next = _addDays(_selectedDay, 7);
                  _selectedDay = next.isAfter(today) ? today : next;
                })
              : null,
        ),
      ],
    );
  }

  Widget _weekNavButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool iconFirst,
    required VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[
      Icon(icon, size: 18),
      const SizedBox(width: 2),
      Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ];
    return SizedBox(
      height: 40,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: scheme.surfaceContainer,
          foregroundColor: onTap == null ? scheme.outline : scheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: iconFirst ? children : children.reversed.toList(),
        ),
      ),
    );
  }

  /// The same date picker as the timeline and alerts pages. Picking a day
  /// selects the Monday–Sunday week it falls in.
  Future<void> _openCalendarModal(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2000),
      lastDate: _dateOnly(DateTime.now()),
      locale: const Locale('tr'),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDay = _dateOnly(picked));
    }
  }

  // ---------------------------------------------------------------------
  // 4. Weekly penalty card (one expandable row per day) + severity sheet
  // ---------------------------------------------------------------------

  String _formatTl(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '₺$buf';
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

  Widget _buildPenaltyTrendCard(
    BuildContext context,
    List<Violation> weekViolations,
    bool asCompany,
    DateTime weekStart,
    String lang,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final today = _dateOnly(DateTime.now());

    // Fine-bearing violations, bucketed by the local day they started on.
    final perDay = List.generate(7, (_) => <_FinedViolation>[]);
    for (final v in weekViolations) {
      final estimate = _penaltyCalculator.estimate(v, asCompany: asCompany);
      if (!estimate.isRealFine) continue;
      final index = _dayIndexInWeek(weekStart, v.start);
      if (index < 0) continue;
      perDay[index].add((violation: v, estimate: estimate));
    }
    for (final items in perDay) {
      items.sort((a, b) => a.violation.start.compareTo(b.violation.start));
    }
    final dayTotals = [
      for (final items in perDay)
        items.fold<int>(0, (sum, x) => sum + x.estimate.amountTl!),
    ];
    final weekTotal = dayTotals.fold<int>(0, (a, b) => a + b);
    final maxDayTotal = dayTotals.fold<int>(0, max);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: scheme.surfaceContainer,
            child: Row(
              children: [
                Icon(Icons.query_builder, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _t('analysis.penaltyTrendTitle'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _t('analysis.penaltyExposureLabel'),
                      style: TextStyle(fontSize: 10, color: scheme.outline),
                    ),
                    Text(
                      _formatTl(weekTotal),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 7; i++)
                  _buildPenaltyDayTile(
                    context,
                    day: _addDays(weekStart, i),
                    items: perDay[i],
                    total: dayTotals[i],
                    maxTotal: maxDayTotal,
                    isFuture: _addDays(weekStart, i).isAfter(today),
                    asCompany: asCompany,
                    lang: lang,
                  ),
                if (asCompany)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8),
                    child: Text(
                      _t('analysis.companyMultiplierFootnote'),
                      style: TextStyle(fontSize: 11, color: scheme.outline),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _openSeveritySheet(context),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.gavel, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _t('analysis.openSeverityListButton'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPenaltyDayTile(
    BuildContext context, {
    required DateTime day,
    required List<_FinedViolation> items,
    required int total,
    required int maxTotal,
    required bool isFuture,
    required bool asCompany,
    required String lang,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final hasFines = items.isNotEmpty;
    final points = items.fold<int>(
      0,
      (sum, x) => sum + (x.estimate.penaltyPoints ?? 0),
    );
    final dateText =
        '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.${day.year}';

    // Same layout as the day tiles of downloaded files: date as the title,
    // a summary underneath, and the details behind the chevron.
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('penalty-day-${day.year}-${day.month}-${day.day}'),
        enabled: hasFines,
        tilePadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: dateText,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isFuture ? scheme.outline : scheme.onSurface,
                ),
              ),
              TextSpan(
                text: '  ${_weekdayLong(day.weekday, lang)}',
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
            ],
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: hasFines && maxTotal > 0
                            ? max(total / maxTotal, 0.04)
                            : 0,
                        minHeight: 10,
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isFuture ? '—' : _formatTl(total),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasFines
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: hasFines ? scheme.onSurface : scheme.outline,
                    ),
                  ),
                ],
              ),
              if (hasFines) ...[
                const SizedBox(height: 4),
                Text(
                  _t('analysis.dayFineSummary')
                      .replaceFirst('{count}', '${items.length}')
                      .replaceFirst('{points}', '$points'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final x in items) _buildFinedViolationRow(context, x),
          const SizedBox(height: 8),
          _buildPenaltyNotes(context, items, total, asCompany),
        ],
      ),
    );
  }

  /// "23:00 - 05:00", with the end date added when the violation runs into
  /// another day.
  String _violationTimeRange(Violation v) {
    final start = v.start.toLocal();
    final end = v.end.toLocal();
    if (!end.isAfter(start)) return _hourMinute(start);
    final endText = _sameDate(start, end)
        ? _hourMinute(end)
        : '${_shortDate(end)} ${_hourMinute(end)}';
    return '${_hourMinute(start)} - $endText';
  }

  // Table styling shared by the penalty details and the score breakdown.
  TextStyle _tableLabelStyle(ColorScheme scheme) =>
      TextStyle(fontSize: 13, height: 1.3, color: scheme.onSurfaceVariant);

  TextStyle _tableValueStyle(ColorScheme scheme) => TextStyle(
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: scheme.onSurface,
  );

  Widget _tableCell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    child: child,
  );

  /// A bordered table with an optional [header] band and column titles.
  Widget _tableCard(
    BuildContext context, {
    Widget? header,
    List<String>? columnTitles,
    required Map<int, TableColumnWidth> columnWidths,
    required List<List<Widget>> rows,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final line = BorderSide(color: scheme.outlineVariant);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Container(
              color: scheme.surfaceContainer,
              padding: const EdgeInsets.all(10),
              child: header,
            ),
          Table(
            columnWidths: columnWidths,
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder(
              horizontalInside: line,
              top: header != null ? line : BorderSide.none,
            ),
            children: [
              if (columnTitles != null)
                TableRow(
                  decoration: BoxDecoration(color: scheme.surfaceContainer),
                  children: [
                    for (final title in columnTitles)
                      _tableCell(
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              for (final row in rows)
                TableRow(children: [for (final cell in row) _tableCell(cell)]),
            ],
          ),
        ],
      ),
    );
  }

  /// One violation as a table: when and what in the header, then its
  /// severity, legal basis, amounts, points and sanction.
  Widget _buildFinedViolationRow(BuildContext context, _FinedViolation item) {
    final scheme = Theme.of(context).colorScheme;
    final v = item.violation;
    final e = item.estimate;
    final label = _tableLabelStyle(scheme);
    final value = _tableValueStyle(scheme);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _tableCard(
        context,
        header: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_violationIcon(v.type), size: 20, color: scheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _violationTimeRange(v),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.error,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(_t(v.descriptionKey), style: value),
                ],
              ),
            ),
          ],
        ),
        columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(3)},
        rows: [
          if (e.euSeverity != null)
            [
              Text(_t('analysis.tableSeverity'), style: label),
              Align(
                alignment: Alignment.centerLeft,
                child: _euSeverityTag(context, e.euSeverity!),
              ),
            ],
          [
            Text(_t('analysis.tableLegalBasis'), style: label),
            Text(e.legalRef ?? '—', style: value),
          ],
          [
            Text(_t('analysis.tableTier'), style: label),
            Text(_t(e.tierLabelKey), style: value),
          ],
          [
            Text(_t('analysis.tableFine'), style: label),
            Text(
              _formatTl(e.amountTl!),
              style: value.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: scheme.error,
              ),
            ),
          ],
          [
            Text(_t('analysis.tableDiscounted'), style: label),
            Text(_formatTl(e.discountedAmountTl!), style: value),
          ],
          if (e.penaltyPoints != null)
            [
              Text(_t('analysis.tablePoints'), style: label),
              Text('${e.penaltyPoints}', style: value),
            ],
          if (e.sanctionKey != null)
            [
              Text(_t('analysis.tableSanction'), style: label),
              Text(_t(e.sanctionKey!), style: value),
            ],
        ],
      ),
    );
  }

  /// The rules behind the day's amounts, as a table: the 25% early-payment
  /// discount, the operator's double fine, penalty points and driving ban.
  Widget _buildPenaltyNotes(
    BuildContext context,
    List<_FinedViolation> items,
    int total,
    bool asCompany,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final value = _tableValueStyle(scheme);
    final discountedTotal = items.fold<int>(
      0,
      (sum, x) => sum + x.estimate.discountedAmountTl!,
    );
    final points = items.fold<int>(
      0,
      (sum, x) => sum + (x.estimate.penaltyPoints ?? 0),
    );
    final operatorValue = asCompany
        ? _t('analysis.noteDriverValue').replaceFirst(
            '{amount}',
            _formatTl(total ~/ PenaltyCalculator.companyMultiplier),
          )
        : _t('analysis.noteOperatorValue').replaceFirst(
            '{amount}',
            _formatTl(total * PenaltyCalculator.companyMultiplier),
          );

    Widget rule(String title, String body) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: value),
        const SizedBox(height: 3),
        Text(
          body,
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return _tableCard(
      context,
      header: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            _t('analysis.notesTitle'),
            style: value.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      columnTitles: [_t('analysis.notesColRule'), _t('analysis.notesColValue')],
      columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2)},
      rows: [
        [
          rule(
            _t('analysis.noteEarlyPaymentTitle'),
            _t('analysis.noteEarlyPaymentBody'),
          ),
          Text(
            _t('analysis.noteEarlyPaymentValue')
                .replaceFirst('{discounted}', _formatTl(discountedTotal))
                .replaceFirst('{full}', _formatTl(total)),
            style: value,
          ),
        ],
        [
          rule(
            _t('analysis.noteOperatorDoubleTitle'),
            _t(
              asCompany
                  ? 'analysis.noteOperatorDoubleCompany'
                  : 'analysis.noteOperatorDouble',
            ),
          ),
          Text(operatorValue, style: value),
        ],
        [
          rule(_t('analysis.notePointsTitle'), _t('analysis.notePointsBody')),
          Text(
            _t('analysis.notePointsValue').replaceFirst('{points}', '$points'),
            style: value,
          ),
        ],
        [
          rule(_t('analysis.noteBanTitle'), _t('analysis.noteBanBody')),
          Text(_t('analysis.noteBanValue'), style: value),
        ],
      ],
    );
  }

  /// The EU category as a coloured dot and coloured text; [short] shows only
  /// the code (e.g. "VSI").
  Widget _euSeverityTag(
    BuildContext context,
    EuSeverity severity, {
    bool short = false,
  }) {
    final color = _severityColors[severity]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            short ? severity.code : _t('analysis.euSeverity${severity.code}'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Risk score breakdown (opened by tapping the risk card)
  // ---------------------------------------------------------------------

  String _violationTypeLabelKey(ViolationType type) => switch (type) {
    ViolationType.continuousDrivingExceeded =>
      'violation.continuousDrivingExceeded',
    ViolationType.dailyDrivingExceeded => 'violation.dailyDrivingExceeded',
    ViolationType.weeklyDrivingExceeded => 'violation.weeklyDrivingExceeded',
    ViolationType.biWeeklyDrivingExceeded =>
      'violation.biWeeklyDrivingExceeded',
    ViolationType.dailyRestInsufficient => 'violation.dailyRestInsufficient',
    ViolationType.weeklyRestInsufficient => 'violation.weeklyRestInsufficient',
    ViolationType.missingRecord => 'violation.missingRecord',
  };

  /// Points with at most one decimal, e.g. "12,5" (TR/DE) or "12.5" (EN).
  String _formatPoints(double points) {
    final rounded = (points * 10).round() / 10;
    if (rounded == rounded.roundToDouble()) return '${rounded.toInt()}';
    final text = rounded.toStringAsFixed(1);
    final lang = AppStateProvider.of(context).selectedLanguage;
    return lang == 'EN' ? text : text.replaceFirst('.', ',');
  }

  void _openRiskBreakdownSheet(BuildContext context, RiskScoreResult risk) {
    final scheme = Theme.of(context).colorScheme;
    final label = _tableLabelStyle(scheme);
    final value = _tableValueStyle(scheme);
    final deductionStyle = value.copyWith(color: scheme.error);

    final byType = <ViolationType, int>{};
    for (final d in risk.deductions) {
      byType[d.violation.type] = (byType[d.violation.type] ?? 0) + 1;
    }
    final types = byType.keys.toList()
      ..sort(
        (a, b) => (risk.deductionByType[b] ?? 0).compareTo(
          risk.deductionByType[a] ?? 0,
        ),
      );
    final totalDeduction = risk.deductionByType.values.fold<double>(
      0,
      (sum, d) => sum + d,
    );
    final deductions = List<RiskDeduction>.of(risk.deductions)
      ..sort((a, b) => b.violation.start.compareTo(a.violation.start));

    Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (scrollContext, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _t('analysis.riskBreakdownTitle'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(sheetContext).pop(),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _tableCard(
                  context,
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(2),
                  },
                  rows: [
                    [
                      Text(_t('analysis.riskBreakdownStart'), style: label),
                      Text('100', style: value),
                    ],
                    [
                      Text(_t('analysis.riskBreakdownTotal'), style: label),
                      Text(
                        totalDeduction == 0
                            ? '0'
                            : '−${_formatPoints(totalDeduction)}',
                        style: totalDeduction == 0 ? value : deductionStyle,
                      ),
                    ],
                    [
                      Text(
                        _t('analysis.riskBreakdownScore'),
                        style: label.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${risk.score} / 100',
                        style: value.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _riskColorFor(risk.score),
                        ),
                      ),
                    ],
                  ],
                ),
                if (deductions.isEmpty) ...[
                  const SizedBox(height: 16),
                  Text(_t('analysis.riskBreakdownEmpty'), style: label),
                ] else ...[
                  sectionTitle(_t('analysis.riskBreakdownByType')),
                  _tableCard(
                    context,
                    columnTitles: [
                      _t('analysis.riskBreakdownColType'),
                      _t('analysis.riskBreakdownColCount'),
                      _t('analysis.riskBreakdownColPoints'),
                    ],
                    columnWidths: const {
                      0: FlexColumnWidth(5),
                      1: FixedColumnWidth(56),
                      2: FixedColumnWidth(86),
                    },
                    rows: [
                      for (final type in types)
                        [
                          Text(_t(_violationTypeLabelKey(type)), style: value),
                          Text('${byType[type]}', style: value),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '−${_formatPoints(risk.deductionByType[type] ?? 0)}',
                                style: deductionStyle,
                              ),
                              if (risk.isCapped(type))
                                Text(
                                  _t('analysis.riskBreakdownCapped'),
                                  style: label.copyWith(fontSize: 11),
                                ),
                            ],
                          ),
                        ],
                    ],
                  ),
                  sectionTitle(_t('analysis.riskBreakdownByViolation')),
                  _tableCard(
                    context,
                    columnTitles: [
                      _t('analysis.riskBreakdownColDate'),
                      _t('analysis.riskBreakdownColViolation'),
                      _t('analysis.riskBreakdownColPoints'),
                    ],
                    columnWidths: const {
                      0: FixedColumnWidth(70),
                      1: FlexColumnWidth(),
                      2: FixedColumnWidth(64),
                    },
                    rows: [
                      for (final d in deductions)
                        [
                          Text(
                            '${_shortDate(d.violation.start.toLocal())}\n${_hourMinute(d.violation.start.toLocal())}',
                            style: label,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(d.violation.descriptionKey),
                                style: value.copyWith(fontSize: 13),
                              ),
                              if (d.violation.euSeverity != null) ...[
                                const SizedBox(height: 4),
                                _euSeverityTag(
                                  context,
                                  d.violation.euSeverity!,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '−${_formatPoints(d.points)}',
                            style: deductionStyle,
                          ),
                        ],
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  _t('analysis.riskBreakdownNote'),
                  style: label.copyWith(fontSize: 12.5, height: 1.4),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// EU 2016/403 category colours: red, orange, yellow, green from the most
  /// to the least serious.
  static const Map<EuSeverity, Color> _severityColors = {
    EuSeverity.mostSerious: Color(0xFFE53935),
    EuSeverity.verySerious: Color(0xFFF57C00),
    EuSeverity.serious: Color(0xFFD4A000),
    EuSeverity.minor: Color(0xFF43A047),
  };

  // Non-breaking space and word joiner: keep "10 sa", "₺3.000" and the like
  // together on one line.
  static const _nbsp = '\u00A0';
  static const _wordJoiner = '\u2060';

  /// "13 sa 30 dk" (TR), "13 h 30 min" (EN), "13 Std. 30 Min." (DE), never
  /// split across lines.
  String _durationText(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final h = '$hours$_nbsp${_t('analysis.unitHourShort')}';
    return minutes == 0
        ? h
        : '$h$_nbsp$minutes$_nbsp${_t('analysis.unitMinuteShort')}';
  }

  /// "10–11 sa", "≥ 13 sa 30 dk", "< 7 sa", "3 sa + (7–8 sa)".
  String _bandRangeText(SeverityBand b) {
    final min = b.min;
    final max = b.max;
    String range;
    if (min != null && max != null) {
      final wholeHours = min.inMinutes % 60 == 0 && max.inMinutes % 60 == 0;
      range = wholeHours
          ? '${min.inHours}–$_wordJoiner${max.inHours}$_nbsp${_t('analysis.unitHourShort')}'
          : '${_durationText(min)}$_nbsp– ${_durationText(max)}';
    } else if (min != null) {
      range = '${b.minInclusive ? '≥' : '>'}$_nbsp${_durationText(min)}';
    } else if (max != null) {
      range = '${b.maxInclusive ? '≤' : '<'}$_nbsp${_durationText(max)}';
    } else {
      return _t('analysis.sevAnyCase');
    }
    final split = b.splitFirstPart;
    if (split != null) range = '${_durationText(split)}$_nbsp+$_nbsp($range)';
    final condition = b.conditionKey;
    if (condition != null) range = '$range, ${_t(condition)}';
    return range;
  }

  /// "₺3.000", or "₺10.000 + ₺3.000" when two fines are issued together.
  String _bandFineText(SeverityBand b) {
    final fine = b.fineTl;
    if (fine == null) return _t(b.fineNoteKey ?? 'analysis.sevNoTrPenalty');
    final extra = b.extraFineTl;
    return extra == null
        ? _formatTl(fine)
        : '${_formatTl(fine)} +$_nbsp${_formatTl(extra)}';
  }

  Widget _buildSeverityRuleTable(BuildContext context, SeverityRule rule) {
    final scheme = Theme.of(context).colorScheme;
    final value = _tableValueStyle(scheme).copyWith(fontSize: 13.5);
    return _tableCard(
      context,
      header: Text(
        _t(rule.titleKey),
        style: _tableValueStyle(scheme).copyWith(fontWeight: FontWeight.w700),
      ),
      columnTitles: [
        _t('analysis.sevColRange'),
        _t('analysis.sevColSeverity'),
        _t('analysis.sevColFine'),
      ],
      columnWidths: const {
        0: FlexColumnWidth(),
        1: FixedColumnWidth(66),
        2: FixedColumnWidth(136),
      },
      rows: [
        for (final b in rule.bands)
          [
            Text(_bandRangeText(b), style: value),
            _euSeverityTag(context, b.severity, short: true),
            Text(_bandFineText(b), style: value),
          ],
      ],
    );
  }

  /// The EU severity table of Annex III (driving and rest times): each row
  /// with its time range, colour-coded category and Turkish fine.
  void _openSeveritySheet(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = _tableLabelStyle(scheme);
    const footnotes = ['analysis.sevFootnoteFine'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (scrollContext, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _t('analysis.openSeverityListButton'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(sheetContext).pop(),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _t('analysis.sevIntro'),
                  style: label.copyWith(height: 1.4),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    for (final s in EuSeverity.values.reversed)
                      _euSeverityTag(context, s),
                  ],
                ),
                for (final group in severityReference) ...[
                  const SizedBox(height: 22),
                  _severitySectionHeader(context, _t(group.titleKey)),
                  const SizedBox(height: 10),
                  for (final rule in group.rules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildSeverityRuleTable(context, rule),
                    ),
                ],
                const SizedBox(height: 16),
                for (final key in footnotes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•  ', style: label),
                        Expanded(
                          child: Text(
                            _t(key),
                            style: label.copyWith(fontSize: 12.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _launchRegulationLink,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _t('analysis.regulationLinkLabel'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _severitySectionHeader(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }

  Future<void> _launchRegulationLink() async {
    final uri = Uri.parse(
      'https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32006R0561',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ---------------------------------------------------------------------
  // 5. Notifications toggle card
  // ---------------------------------------------------------------------

  Widget _buildNotificationsCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _softShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.primary,
            child: Icon(
              Icons.notifications_active,
              color: scheme.onPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('analysis.notificationsCardTitle'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _t('analysis.notificationsCardSubtitle'),
                  style: TextStyle(fontSize: 11, color: scheme.outline),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: _notificationsEnabled,
            onChanged: (v) => setState(() => _notificationsEnabled = v),
            activeThumbColor: scheme.primary,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 6. Insight carousel (real data-driven)
  // ---------------------------------------------------------------------

  List<_InsightCard> _buildInsightCards(
    List<Violation> weekViolations,
    DateTime weekStart,
  ) {
    final restViolations = weekViolations
        .where(
          (v) =>
              v.type == ViolationType.dailyRestInsufficient ||
              v.type == ViolationType.weeklyRestInsufficient,
        )
        .toList();
    final drivingViolations = weekViolations
        .where(
          (v) =>
              v.type == ViolationType.continuousDrivingExceeded ||
              v.type == ViolationType.dailyDrivingExceeded ||
              v.type == ViolationType.weeklyDrivingExceeded ||
              v.type == ViolationType.biWeeklyDrivingExceeded,
        )
        .toList();

    final cards = <_InsightCard>[];

    if (restViolations.isNotEmpty) {
      final perDay = List<int>.filled(7, 0);
      for (final v in restViolations) {
        final dayIndex = _dayIndexInWeek(weekStart, v.start);
        if (dayIndex < 0) continue;
        perDay[dayIndex] += (v.excessDuration?.inMinutes ?? 0).abs();
      }
      final totalMinutes = perDay.fold<int>(0, (a, b) => a + b);
      final avg = (totalMinutes / restViolations.length).round();
      cards.add(
        _InsightCard(
          title: _t('analysis.insightRestIssueTitle'),
          icon: Icons.front_hand,
          values: perDay,
          chartCaption: _t('analysis.insightRestChartCaption'),
          avgLabel:
              '${_t('analysis.insightAveragePrefix')}: $avg ${_t('analysis.minutesUnit')}',
          description: _t('analysis.insightRestDescription')
              .replaceFirst('{count}', '${restViolations.length}')
              .replaceFirst('{minutes}', '$avg'),
          isPositive: false,
          violations: restViolations,
        ),
      );
    }

    if (drivingViolations.isNotEmpty) {
      final perDay = List<int>.filled(7, 0);
      for (final v in drivingViolations) {
        final dayIndex = _dayIndexInWeek(weekStart, v.start);
        if (dayIndex < 0) continue;
        perDay[dayIndex] += 1;
      }
      cards.add(
        _InsightCard(
          title: _t('analysis.insightDrivingIssueTitle'),
          icon: Icons.speed,
          values: perDay,
          chartCaption: _t('analysis.insightDrivingChartCaption'),
          description: _t(
            'analysis.insightDrivingDescription',
          ).replaceFirst('{count}', '${drivingViolations.length}'),
          isPositive: false,
          violations: drivingViolations,
        ),
      );
    }

    if (cards.isEmpty) {
      cards.add(
        _InsightCard(
          title: _t('analysis.insightCleanTitle'),
          icon: Icons.verified,
          values: List<int>.filled(7, 0),
          chartCaption: _t('analysis.insightCleanChartCaption'),
          description: _t('analysis.insightCleanDescription'),
          isPositive: true,
          violations: const [],
        ),
      );
    }

    return cards;
  }

  Widget _buildInsightCarousel(
    BuildContext context,
    List<Violation> weekViolations,
    DateTime weekStart,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final lang = AppStateProvider.of(context).selectedLanguage;
    final cards = _buildInsightCards(weekViolations, weekStart);
    if (_insightIndex >= cards.length) _insightIndex = 0;
    final card = cards[_insightIndex];

    final bg = card.isPositive
        ? scheme.secondaryContainer
        : scheme.errorContainer;
    final onBg = card.isPositive
        ? scheme.onSecondaryContainer
        : scheme.onErrorContainer;
    final accent = card.isPositive ? scheme.primary : scheme.error;
    final onAccent = card.isPositive ? scheme.onPrimary : scheme.onError;
    final dayLabels = List.generate(
      7,
      (i) => _weekdayShort(weekStart.add(Duration(days: i)).weekday, lang),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: accent,
                    child: Icon(card.icon, size: 16, color: onAccent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      card.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: onBg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(4, 12, 12, 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 22, right: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              card.chartCaption,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.outline,
                              ),
                            ),
                          ),
                          if (card.avgLabel != null)
                            Text(
                              card.avgLabel!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    _MiniLineChart(
                      values: card.values,
                      dayLabels: dayLabels,
                      lineColor: accent,
                      gridColor: scheme.outlineVariant.withValues(alpha: 0.5),
                      labelColor: scheme.outline,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                card.description,
                style: TextStyle(fontSize: 12, color: onBg, height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (cards.length > 1)
                    Row(
                      children: [
                        for (var i = 0; i < cards.length; i++)
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            width: i == _insightIndex ? 14 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _insightIndex
                                  ? accent
                                  : onBg.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                      ],
                    )
                  else
                    const SizedBox.shrink(),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton(
                            onPressed: () =>
                                _openInsightDetailsDialog(context, card),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: onBg,
                              side: BorderSide(
                                color: onBg.withValues(alpha: 0.4),
                              ),
                              backgroundColor: scheme.surfaceContainerLowest,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: Text(
                              _t('analysis.insightDetailsButton'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => _openSeveritySheet(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: Text(
                              _t('analysis.insightFixPlanButton'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (cards.length > 1) ...[
          Positioned(
            left: -10,
            top: 0,
            bottom: 0,
            child: Center(
              child: _floatingNavButton(
                context,
                Icons.chevron_left,
                () => setState(
                  () => _insightIndex =
                      (_insightIndex - 1 + cards.length) % cards.length,
                ),
              ),
            ),
          ),
          Positioned(
            right: -10,
            top: 0,
            bottom: 0,
            child: Center(
              child: _floatingNavButton(
                context,
                Icons.chevron_right,
                () => setState(
                  () => _insightIndex = (_insightIndex + 1) % cards.length,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _floatingNavButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: scheme.onSurface),
        ),
      ),
    );
  }

  void _openInsightDetailsDialog(BuildContext context, _InsightCard card) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('analysis.insightDetailsDialogTitle')),
        content: SizedBox(
          width: 380,
          child: card.violations.isEmpty
              ? Text(
                  card.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final v in card.violations)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: scheme.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _t(v.descriptionKey),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      '${v.ruleReference} • ${_shortDateTime(v.start.toLocal())}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_t('settings.close')),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 7. Driving mode + backup/settings cards
  // ---------------------------------------------------------------------

  Widget _buildDrivingModeCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/driver-mode'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: _softShadow,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: scheme.primary,
                child: Icon(
                  Icons.directions_car,
                  color: scheme.onPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('driverMode.button'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _t('driverMode.buttonHint'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: scheme.outline),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackupSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: scheme.secondaryContainer,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.primary,
                  child: Icon(
                    Icons.download,
                    color: scheme.onPrimary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('analysis.backupSectionTitle'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _t('analysis.backupSectionSubtitle'),
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSecondaryContainer.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _softShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.sync,
                          size: 16,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t('analysis.autoDddTitle'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _t('analysis.autoDddSubtitle'),
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _autoDddDownload,
                        onChanged: (v) => setState(() => _autoDddDownload = v),
                        activeThumbColor: scheme.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _softShadow,
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: scheme.surfaceContainer,
                        child: Icon(
                          _driveUser != null
                              ? Icons.cloud_done
                              : Icons.cloud_off,
                          color: _driveUser != null
                              ? scheme.primary
                              : scheme.outline,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t('analysis.googleDriveTitle'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _driveUser != null
                                  ? scheme.primary
                                  : scheme.outline,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _driveUser != null
                                  ? (_driveUser!.email.isNotEmpty
                                        ? _driveUser!.email
                                        : _t('analysis.googleDriveConnected'))
                                  : _t('analysis.googleDriveNotConnected'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.outline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t('analysis.googleDriveDescription'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: scheme.outline),
                      ),
                      const SizedBox(height: 12),
                      if (_driveUser != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _t('analysis.googleDriveBackupToggleLabel'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                            Switch(
                              value: _isDriveBackupEnabled,
                              onChanged: (_) => _toggleDriveBackup(),
                              activeThumbColor: scheme.primary,
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _disconnectDrive,
                          icon: Icon(
                            Icons.link_off,
                            size: 16,
                            color: scheme.error,
                          ),
                          label: Text(
                            _t('analysis.googleDriveDisconnectButton'),
                            style: TextStyle(
                              color: scheme.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ] else
                        OutlinedButton.icon(
                          onPressed: _isDriveConnecting ? null : _connectDrive,
                          icon: _isDriveConnecting
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.primary,
                                  ),
                                )
                              : const Icon(Icons.add_link, size: 16),
                          label: Text(
                            _t('analysis.googleDriveConnectButton'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.onSurface,
                            side: BorderSide(color: scheme.outlineVariant),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                    ],
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

/// A small line chart with a visible Y-axis scale, horizontal gridlines and
/// X-axis weekday labels — used inside the insight carousel cards.
class _MiniLineChart extends StatelessWidget {
  final List<int> values;
  final List<String> dayLabels;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;

  const _MiniLineChart({
    required this.values,
    required this.dayLabels,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = values.fold<int>(0, (m, v) => v > m ? v : m);
    final niceMax = maxVal <= 0 ? 5 : (((maxVal + 4) ~/ 5) * 5);
    return SizedBox(
      height: 110,
      width: double.infinity,
      child: CustomPaint(
        painter: _MiniLineChartPainter(
          values: values,
          niceMax: niceMax,
          dayLabels: dayLabels,
          lineColor: lineColor,
          gridColor: gridColor,
          labelColor: labelColor,
        ),
      ),
    );
  }
}

class _MiniLineChartPainter extends CustomPainter {
  final List<int> values;
  final int niceMax;
  final List<String> dayLabels;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;

  _MiniLineChartPainter({
    required this.values,
    required this.niceMax,
    required this.dayLabels,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftGutter = 22.0;
    const bottomGutter = 16.0;
    const topGutter = 4.0;
    final plotLeft = leftGutter;
    final plotRight = size.width;
    final plotBottom = size.height - bottomGutter;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - topGutter;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final frac = i / 4;
      final y = plotBottom - plotHeight * frac;
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
      final labelValue = (niceMax * frac).round();
      final tp = TextPainter(
        text: TextSpan(
          text: '$labelValue',
          style: TextStyle(fontSize: 9, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    if (values.isEmpty) return;

    final stepX = values.length > 1 ? plotWidth / (values.length - 1) : 0.0;
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = plotLeft + stepX * i;
      final frac = niceMax > 0 ? (values[i] / niceMax).clamp(0.0, 1.0) : 0.0;
      final y = plotBottom - plotHeight * frac;
      points.add(Offset(x, y));
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = lineColor;
    for (final p in points) {
      canvas.drawCircle(p, 3, dotPaint);
    }

    for (var i = 0; i < dayLabels.length && i < points.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: dayLabels[i],
          style: TextStyle(fontSize: 9, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(points[i].dx - tp.width / 2, size.height - bottomGutter + 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniLineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.niceMax != niceMax ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}
