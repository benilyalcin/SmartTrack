import 'package:flutter/material.dart';
import '../../core/providers/app_state.dart';
import '../../core/localization/localization.dart';
import '../../core/models/activity_segment.dart';
import '../../core/services/driving_time_calculator.dart';
import '../../core/services/time/display_time.dart';
import '../../core/services/violation_analyzer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/bluetooth_warning_banner.dart';
import '../../core/widgets/link_status_banner.dart';
import '../../core/widgets/card_slot_warning_banner.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  /// Times and calendar days are shown in the display zone; the data stays
  /// in UTC (a display day spans two UTC days).
  final DisplayTime _display = DisplayTime.fromConfig();

  /// The display calendar day shown (date fields only).
  late DateTime _selectedDate = _display.displayDay(DateTime.now());

  bool _isDriver1Selected = true;

  static const _breakColor = Color(0xFFE53935);
  static const _workColor = Color(0xFFFBC02D);
  static const _availableColor = Color(0xFF000000);
  static const _unknownColor = Color(0xFF7E57C2);

  /// No live record, but the unit kept recording: the next card download
  /// fills it.
  static const _pendingColor = Color(0xFF9E9E9E);

  /// Live and manual data are provisional until a card file confirms them.
  static const _provisionalAlpha = 0.5;

  final ViolationAnalyzer _violationAnalyzer = ViolationAnalyzer();

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
                  const LinkStatusBanner(),
                  const CardSlotWarningBanner(),

                  _buildPageHeader(context, isDesktop),
                  const SizedBox(height: 40),

                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildTimelineChart(context)),
                        const SizedBox(width: 24),
                        Expanded(flex: 1, child: _buildSummaryCard(context)),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTimelineChart(context),
                        const SizedBox(height: 24),
                        _buildSummaryCard(context),
                      ],
                    ),

                  const SizedBox(height: 40),

                  _buildDetailedLogList(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderTitle(context, isDesktop),
        const SizedBox(height: 12),

        Center(child: _buildDateRow(context)),
        const SizedBox(height: 8),
        Center(child: _buildHeaderNavigation(context)),
      ],
    );
  }

  Widget _buildHeaderTitle(BuildContext context, bool isDesktop) {
    return Text(
      _t('timeline.title'),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: isDesktop ? 32 : 24,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
        letterSpacing: isDesktop ? -0.64 : -0.24,
      ),
    );
  }

  Widget _buildDateRow(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => InkWell(
        onTap: () => _pickDate(context),
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: constraints.maxWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _formatDate(_selectedDate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('tr'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildHeaderNavigation(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        _buildNavButton(
          context,
          label: _t('timeline.prev'),
          icon: Icons.chevron_left,
          onTap: () {
            setState(() {
              _selectedDate = _selectedDate.subtract(const Duration(days: 1));
            });
          },
        ),
        _buildNavButton(
          context,
          label: _t('timeline.today'),
          onTap: () {
            _pickDate(context);
          },
        ),
        _buildNavButton(
          context,
          label: _t('timeline.next'),
          icon: Icons.chevron_right,
          isIconRight: true,
          onTap: () {
            setState(() {
              _selectedDate = _selectedDate.add(const Duration(days: 1));
            });
          },
        ),
      ],
    );
  }

  Widget _buildNavButton(
    BuildContext context, {
    required String label,
    IconData? icon,
    bool isIconRight = false,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        backgroundColor: Theme.of(context).colorScheme.surface,
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null && !isIconRight) ...[
            Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (icon != null && isIconRight) ...[
            const SizedBox(width: 4),
            Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineChart(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t('timeline.activity'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Center(child: _buildDriverToggle(context)),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildLegendItem(
                context,
                Theme.of(context).colorScheme.primary,
                _t('timeline.driving'),
              ),
              _buildLegendItem(context, _breakColor, _t('timeline.break_')),
              _buildLegendItem(context, _workColor, _t('timeline.otherWork')),
              _buildLegendItem(
                context,
                _availableColor,
                _t('timeline.available'),
              ),
              _buildLegendItem(
                context,
                _unknownColor,
                _t('violation.missingRecord'),
              ),
              _buildLegendItem(
                context,
                _pendingColor,
                _t('timeline.pendingDdd'),
              ),
              _buildLegendItem(
                context,
                Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: _provisionalAlpha),
                _t('timeline.provisional'),
              ),
              _buildLegendItem(
                context,
                Theme.of(context).colorScheme.error.withValues(alpha: 0.9),
                _t('timeline.violation'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(children: _buildChartSegments(context)),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final tickStyle = TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.outline,
              );
              final textScaler = MediaQuery.textScalerOf(context);
              final textDirection = Directionality.of(context);
              final widths = <int, double>{
                for (var hour = 0; hour <= 24; hour += 2)
                  hour: (TextPainter(
                    text: TextSpan(
                      text: hour.toString().padLeft(2, '0'),
                      style: tickStyle,
                    ),
                    textDirection: textDirection,
                    textScaler: textScaler,
                  )..layout()).width,
              };
              final interval = [2, 4, 6, 8, 12, 24].firstWhere((step) {
                final requiredWidth = [
                  for (var hour = 0; hour <= 24; hour += step) widths[hour]!,
                ].fold<double>(0, (total, width) => total + width);
                return requiredWidth <= constraints.maxWidth - 8;
              }, orElse: () => 24);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var hour = 0; hour <= 24; hour += interval)
                      Text(hour.toString().padLeft(2, '0'), style: tickStyle),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDriverToggle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.surfaceContainerHigh),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 2,
        runSpacing: 2,
        children: [
          _buildDriverToggleOption(
            context,
            label: _t('dashboard.mainDriver'),
            selected: _isDriver1Selected,
            onTap: () => setState(() => _isDriver1Selected = true),
          ),
          _buildDriverToggleOption(
            context,
            label: _t('dashboard.backupDriver'),
            selected: !_isDriver1Selected,
            onTap: () => setState(() => _isDriver1Selected = false),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverToggleOption(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarSegment(
    BuildContext context, {
    required int flex,
    required Color color,
    required String tooltip,
    bool hasBorderLeft = false,
    bool hasBorderRight = false,
  }) {
    return Expanded(
      flex: flex,
      child: Tooltip(
        message: tooltip,
        preferBelow: false,
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 3),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            border: Border(
              left: hasBorderLeft
                  ? BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.2),
                      width: 1,
                    )
                  : BorderSide.none,
              right: hasBorderRight
                  ? BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.2),
                      width: 1,
                    )
                  : BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appState = AppStateProvider.of(context);
    final rows = _dayRows(appState);
    final day = _dayRange;

    Duration total(ActivityType type) => rows
        .where((r) => !r.isGap && r.type == type)
        .fold(Duration.zero, (sum, r) => sum + r.end.difference(r.start));
    final totalDriving = total(ActivityType.driving);
    final totalBreak = total(ActivityType.rest);
    final totalWork = total(ActivityType.work);
    final totalAvailable = total(ActivityType.available);
    final violationTime = _dayViolations(appState).fold(
      Duration.zero,
      (sum, v) => sum + _clippedToDay(v.start, v.end, day.start, day.end),
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t('timeline.summary'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            context,
            icon: Icons.directions_car,
            iconColor: Theme.of(context).colorScheme.primary,
            title: _t('timeline.totalDriving'),
            value: _fmtDuration(totalDriving),
          ),
          _buildSummaryRow(
            context,
            icon: Icons.bed,
            iconColor: _breakColor,
            title: _t('timeline.totalBreak'),
            value: _fmtDuration(totalBreak),
          ),
          _buildSummaryRow(
            context,
            icon: Icons.engineering,
            iconColor: _workColor,
            title: _t('timeline.otherWork'),
            value: _fmtDuration(totalWork),
          ),
          _buildSummaryRow(
            context,
            icon: Icons.event_available,
            iconColor: _availableColor,
            title: _t('timeline.available'),
            value: _fmtDuration(totalAvailable),
          ),
          _buildSummaryRow(
            context,
            icon: Icons.warning,
            iconColor: Theme.of(context).colorScheme.error,
            title: _t('timeline.violationTime'),
            value: _fmtDuration(violationTime),
            valueColor: Theme.of(context).colorScheme.error,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    Color? valueColor,
    bool isLast = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedLogList(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appState = AppStateProvider.of(context);
    final day = _dayRange;
    final rows = <Widget>[
      for (final r in _dayRows(appState)) _buildActivityLogRow(context, r),
      for (final v in _dayViolations(appState))
        _buildViolationLogRow(context, v, day.start, day.end),
    ];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Text(
              _t('timeline.detailedLog'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _t('timeline.noData'),
                style: TextStyle(color: scheme.outline),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            ),
        ],
      ),
    );
  }

  IconData _rowIcon(_DayRow r) {
    if (r.status == SegmentStatus.pendingGap) return Icons.hourglass_empty;
    switch (r.type) {
      case ActivityType.driving:
        return Icons.directions_car;
      case ActivityType.rest:
        return Icons.hotel;
      case ActivityType.work:
        return Icons.engineering;
      case ActivityType.available:
        return Icons.event_available;
      case ActivityType.unknown:
        return Icons.help_outline;
    }
  }

  Widget _buildActivityLogRow(BuildContext context, _DayRow r) {
    final scheme = Theme.of(context).colorScheme;
    final color = _rowColor(context, r, forText: true);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(_rowIcon(r), size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_fmtHm(r.start)} - ${_fmtHm(r.end)}',
              style: TextStyle(color: color),
            ),
          ),
          Flexible(
            child: Text(
              _rowLabel(r),
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
          ),
          if (r.isCrew) ...[
            const SizedBox(width: 6),
            Tooltip(
              message:
                  '${_t('ddd.crewBadge')} · ${r.slot == DriverSlot.coDriver ? _t('ddd.slotCoDriver') : _t('ddd.slotDriver')}',
              child: Icon(Icons.people_alt, size: 16, color: scheme.tertiary),
            ),
          ],
          if (r.source == SegmentSource.live && !r.isGap) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: _t('timeline.provisional'),
              child: Icon(Icons.sensors, size: 16, color: scheme.outline),
            ),
          ],
          if (r.source == SegmentSource.manual) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: _t('ddd.manualEntryBadge'),
              child: Icon(Icons.edit_note, size: 16, color: scheme.outline),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildViolationLogRow(
    BuildContext context,
    Violation v,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    final scheme = Theme.of(context).colorScheme;

    final isRange = v.type == ViolationType.missingRecord;
    final clippedStart = v.start.isBefore(dayStart) ? dayStart : v.start;
    final clippedEnd = v.end.isAfter(dayEnd) ? dayEnd : v.end;
    final timeText = isRange
        ? '${_fmtHm(clippedStart)} - ${_fmtHm(clippedEnd)}'
        : _fmtHm(v.start);
    // Time above, description below: a long description wraps instead of
    // squeezing the time into a one-character column.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning, size: 18, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(timeText, style: TextStyle(color: scheme.error)),
                const SizedBox(height: 2),
                Text(
                  _t(v.descriptionKey),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The selected display day as a UTC range.
  ({DateTime start, DateTime end}) get _dayRange =>
      _display.dayRangeUtc(_selectedDate);

  /// The co-driver's activities: their card records when the card file has
  /// any, otherwise the live data.
  ({List<TachographActivity> log, bool fromCard}) _coDriverLog(
    AppState appState,
  ) {
    final file = appState.activeDddFile;
    final parsed = appState.currentParsedData;
    if (file != null && !file.isSimulated && parsed != null) {
      final coDriverLog = parsed.activityLog
          .where((a) => a.slot == DriverSlot.coDriver)
          .toList();
      if (coDriverLog.isNotEmpty) return (log: coDriverLog, fromCard: true);
    }
    return (log: appState.liveOnlyActivityLog2, fromCard: false);
  }

  /// The selected driver's activities, for the violation check.
  List<TachographActivity> _selectedDriverLog(AppState appState) =>
      _isDriver1Selected ? appState.activityLog : _coDriverLog(appState).log;

  /// The selected day, cut to it, oldest first. The main driver's comes
  /// from the merged view (card records first, then live, then manual, and
  /// the gaps with their status); nothing is shown past now.
  List<_DayRow> _dayRows(AppState appState) {
    final day = _dayRange;
    final now = DateTime.now().toUtc();
    final end = now.isBefore(day.end) ? now : day.end;
    if (!end.isAfter(day.start)) return const [];

    final rows = <_DayRow>[];
    void add(
      DateTime s,
      DateTime e, {
      required ActivityType type,
      required SegmentStatus status,
      required SegmentSource source,
      bool isCrew = false,
      DriverSlot slot = DriverSlot.driver,
    }) {
      final from = s.isBefore(day.start) ? day.start : s;
      final to = e.isAfter(end) ? end : e;
      if (to.difference(from).inMinutes < 1) return;
      rows.add(
        _DayRow(
          start: from,
          end: to,
          type: type,
          status: status,
          source: source,
          isCrew: isCrew,
          slot: slot,
        ),
      );
    }

    if (_isDriver1Selected) {
      for (final seg in appState.activityData.view('driver1')) {
        add(
          seg.startUtc,
          seg.endOr(now),
          type: seg.activityType,
          status: seg.status,
          source: seg.source,
          isCrew: seg.isCrew,
          slot: seg.slot,
        );
      }
    } else {
      final (:log, :fromCard) = _coDriverLog(appState);
      for (final a in log) {
        add(
          a.startTime,
          a.endTime,
          type: a.type,
          status: !fromCard
              ? SegmentStatus.provisional
              : (a.type == ActivityType.unknown
                    ? SegmentStatus.needsManual
                    : SegmentStatus.confirmed),
          source: fromCard
              ? SegmentSource.ddd
              : (a.isManualEntry ? SegmentSource.manual : SegmentSource.live),
          isCrew: a.isCrew,
          slot: a.slot,
        );
      }
    }
    rows.sort((a, b) => a.start.compareTo(b.start));
    return rows;
  }

  /// The day's violations. A stretch with no record that a card download
  /// will still fill (pendingGap) is no violation: it is shown as a gap
  /// row, not as a missing record.
  List<Violation> _dayViolations(AppState appState) {
    final day = _dayRange;
    final pending = _dayRows(
      appState,
    ).where((r) => r.status == SegmentStatus.pendingGap).toList();
    return _violationAnalyzer
        .analyze(_selectedDriverLog(appState), DateTime.now())
        .where((v) => v.start.isBefore(day.end) && v.end.isAfter(day.start))
        .where(
          (v) =>
              v.type != ViolationType.missingRecord ||
              !pending.any(
                (r) => v.start.isBefore(r.end) && v.end.isAfter(r.start),
              ),
        )
        .toList();
  }

  Duration _clippedToDay(
    DateTime start,
    DateTime end,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    final clippedStart = start.isBefore(dayStart) ? dayStart : start;
    final clippedEnd = end.isAfter(dayEnd) ? dayEnd : end;
    final duration = clippedEnd.difference(clippedStart);
    return duration.isNegative ? Duration.zero : duration;
  }

  List<Widget> _buildChartSegments(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final day = _dayRange;
    // Stretches with no row at all (no data, or still to come) stay empty.
    final emptyColor = Theme.of(context).colorScheme.outlineVariant;

    final segments = <Widget>[];
    var cursor = day.start;
    void addEmpty(DateTime until) {
      final minutes = until.difference(cursor).inMinutes;
      if (minutes <= 0) return;
      segments.add(
        _buildBarSegment(
          context,
          flex: minutes,
          color: emptyColor,
          tooltip:
              '${_fmtHm(cursor)} - ${_fmtHm(until)} (${_t('timeline.noData')})',
          hasBorderLeft: segments.isNotEmpty,
        ),
      );
    }

    for (final r in _dayRows(appState)) {
      addEmpty(r.start);
      final minutes = r.end.difference(r.start).inMinutes;
      if (minutes > 0) {
        segments.add(
          _buildBarSegment(
            context,
            flex: minutes,
            color: _rowColor(context, r),
            tooltip: '${_fmtHm(r.start)} - ${_fmtHm(r.end)} (${_rowLabel(r)})',
            hasBorderLeft: segments.isNotEmpty,
          ),
        );
      }
      cursor = r.end;
    }
    addEmpty(day.end);
    return segments;
  }

  Color _typeColor(BuildContext context, ActivityType type) {
    switch (type) {
      case ActivityType.driving:
        return Theme.of(context).colorScheme.primary;
      case ActivityType.rest:
        return _breakColor;
      case ActivityType.work:
        return _workColor;
      case ActivityType.available:
        return _availableColor;
      case ActivityType.unknown:
        return _unknownColor;
    }
  }

  /// Gaps by status; live and manual data faded on the chart, as a later
  /// card file may still change them.
  Color _rowColor(BuildContext context, _DayRow r, {bool forText = false}) {
    if (r.status == SegmentStatus.pendingGap) return _pendingColor;
    if (r.status == SegmentStatus.needsManual) return _unknownColor;
    final color = _typeColor(context, r.type);
    if (forText || r.status != SegmentStatus.provisional) return color;
    return color.withValues(alpha: _provisionalAlpha);
  }

  String _rowLabel(_DayRow r) {
    if (r.status == SegmentStatus.pendingGap) return _t('timeline.pendingDdd');
    if (r.status == SegmentStatus.needsManual) {
      return _t('violation.missingRecord');
    }
    switch (r.type) {
      case ActivityType.driving:
        return _t('timeline.driving');
      case ActivityType.rest:
        return _t('timeline.break_');
      case ActivityType.work:
        return _t('timeline.work');
      case ActivityType.available:
        return _t('timeline.available');
      case ActivityType.unknown:
        return _t('violation.missingRecord');
    }
  }

  /// HH:mm in the display zone.
  String _fmtHm(DateTime dt) => _display.hm(dt);

  String _fmtDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${h}s ${m}d';
  }
}

/// One stretch of the selected day, cut to it.
class _DayRow {
  const _DayRow({
    required this.start,
    required this.end,
    required this.type,
    required this.status,
    required this.source,
    this.isCrew = false,
    this.slot = DriverSlot.driver,
  });

  final DateTime start;
  final DateTime end;
  final ActivityType type;
  final SegmentStatus status;
  final SegmentSource source;
  final bool isCrew;
  final DriverSlot slot;

  bool get isGap =>
      status == SegmentStatus.pendingGap || status == SegmentStatus.needsManual;
}
