import 'package:flutter/material.dart';
import '../../core/providers/app_state.dart';
import '../../core/localization/localization.dart';
import '../../core/services/driving_time_calculator.dart';
import '../../core/services/violation_analyzer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/bluetooth_warning_banner.dart';
import '../../core/widgets/card_slot_warning_banner.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  DateTime _selectedDate = DateTime.now();

  bool _isDriver1Selected = true;

  static const _breakColor = Color(0xFFE53935);
  static const _workColor = Color(0xFFFBC02D);
  static const _availableColor = Color(0xFF000000);
  static const _unknownColor = Color(0xFF7E57C2);

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
                  const CardSlotWarningBanner(),

                  _buildPageHeader(context, isDesktop),
                  _buildLiveOnlyDataNote(context),
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
    return InkWell(
      onTap: () => _pickDate(context),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDate(_selectedDate),
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
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
        const SizedBox(width: 4),
        _buildNavButton(
          context,
          label: _t('timeline.today'),
          onTap: () {
            _pickDate(context);
          },
        ),
        const SizedBox(width: 4),
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

  Widget _buildLiveOnlyDataNote(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appState = AppStateProvider.of(context);
    final file = appState.activeDddFile;
    final usingDdd = file != null && !file.isSimulated;
    final text = usingDdd
        ? _t('timeline.showingFileNote').replaceFirst(
            '{file}',
            file.cardHolderName.isNotEmpty
                ? file.cardHolderName
                : _formatDate(file.downloadedAt),
          )
        : _t('timeline.liveOnlyDataNote');
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            usingDdd ? Icons.folder_open_outlined : Icons.verified_outlined,
            size: 16,
            color: scheme.outline,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (int i = 0; i <= 24; i += 2)
                  Text(
                    i.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.outline,
                    ),
                  ),
              ],
            ),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    final dayStart = DateTime.utc(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dayActivities = _activitiesForSelectedDay(appState);
    final dayViolations = _liveOnlyViolations(
      appState,
    ).where((v) => _overlapsSelectedDay(v.start, v.end)).toList();

    final totalDriving = dayActivities
        .where((a) => a.type == ActivityType.driving)
        .fold(
          Duration.zero,
          (sum, a) =>
              sum + _clippedToDay(a.startTime, a.endTime, dayStart, dayEnd),
        );
    final restActivities = dayActivities
        .where((a) => a.type == ActivityType.rest)
        .toList();
    final totalBreak = restActivities.fold(
      Duration.zero,
      (sum, a) => sum + _clippedToDay(a.startTime, a.endTime, dayStart, dayEnd),
    );
    final totalWork = dayActivities
        .where((a) => a.type == ActivityType.work)
        .fold(
          Duration.zero,
          (sum, a) =>
              sum + _clippedToDay(a.startTime, a.endTime, dayStart, dayEnd),
        );
    final totalAvailable = dayActivities
        .where((a) => a.type == ActivityType.available)
        .fold(
          Duration.zero,
          (sum, a) =>
              sum + _clippedToDay(a.startTime, a.endTime, dayStart, dayEnd),
        );
    final violationTime = dayViolations.fold(
      Duration.zero,
      (sum, v) => sum + _clippedToDay(v.start, v.end, dayStart, dayEnd),
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
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedLogList(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appState = AppStateProvider.of(context);
    final dayStart = DateTime.utc(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dayActivities = _activitiesForSelectedDay(appState)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final dayViolations = _liveOnlyViolations(
      appState,
    ).where((v) => _overlapsSelectedDay(v.start, v.end)).toList();

    final rows = <Widget>[
      for (final a in dayActivities) _buildActivityLogRow(context, a),
      for (final v in dayViolations)
        _buildViolationLogRow(context, v, dayStart, dayEnd),
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

  IconData _activityRowIcon(ActivityType type) {
    switch (type) {
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

  Widget _buildActivityLogRow(BuildContext context, TachographActivity a) {
    final scheme = Theme.of(context).colorScheme;
    final color = _activityColor(context, a);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(_activityRowIcon(a.type), size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_fmtHm(a.startTime)} - ${_fmtHm(a.endTime)}',
              style: TextStyle(color: color),
            ),
          ),
          Text(
            _activityLabel(context, a),
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
          if (a.isCrew) ...[
            const SizedBox(width: 6),
            Tooltip(
              message:
                  '${_t('ddd.crewBadge')} · ${a.slot == DriverSlot.coDriver ? _t('ddd.slotCoDriver') : _t('ddd.slotDriver')}',
              child: Icon(Icons.people_alt, size: 16, color: scheme.tertiary),
            ),
          ],
          if (a.isManualEntry) ...[
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.warning, size: 18, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(timeText, style: TextStyle(color: scheme.error)),
          ),
          Text(
            _t(v.descriptionKey),
            style: TextStyle(fontWeight: FontWeight.w600, color: scheme.error),
          ),
        ],
      ),
    );
  }

  List<TachographActivity> _selectedDriverLog(AppState appState) {
    if (_isDriver1Selected) return appState.activityLog;

    final file = appState.activeDddFile;
    final parsed = appState.currentParsedData;
    if (file != null && !file.isSimulated && parsed != null) {
      final coDriverLog = parsed.activityLog
          .where((a) => a.slot == DriverSlot.coDriver)
          .toList();
      if (coDriverLog.isNotEmpty) return coDriverLog;
    }
    return appState.liveOnlyActivityLog2;
  }

  List<TachographActivity> _activitiesForSelectedDay(AppState appState) {
    final dayStart = DateTime.utc(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _selectedDriverLog(appState)
        .where(
          (a) => a.startTime.isBefore(dayEnd) && a.endTime.isAfter(dayStart),
        )
        .toList();
  }

  List<Violation> _liveOnlyViolations(AppState appState) {
    return _violationAnalyzer.analyze(
      _selectedDriverLog(appState),
      DateTime.now(),
    );
  }

  bool _overlapsSelectedDay(DateTime start, DateTime end) {
    final dayStart = DateTime.utc(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    return start.isBefore(dayEnd) && end.isAfter(dayStart);
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
    final dayStart = DateTime.utc(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));

    final gapColor = _unknownColor;

    final dayActivities =
        _activitiesForSelectedDay(appState)
            .map(
              (a) => TachographActivity(
                type: a.type,
                startTime: a.startTime.isBefore(dayStart)
                    ? dayStart
                    : a.startTime,
                endTime: a.endTime.isAfter(dayEnd) ? dayEnd : a.endTime,
                isManualEntry: a.isManualEntry,
              ),
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final segments = <Widget>[];
    DateTime cursor = dayStart;
    for (final a in dayActivities) {
      final gapMinutes = a.startTime.difference(cursor).inMinutes;
      if (gapMinutes > 0) {
        segments.add(
          _buildBarSegment(
            context,
            flex: gapMinutes,
            color: gapColor,
            tooltip:
                '${_fmtHm(cursor)} - ${_fmtHm(a.startTime)} (${_t('violation.missingRecord')})',
            hasBorderLeft: segments.isNotEmpty,
          ),
        );
      }
      final durationMinutes = a.endTime.difference(a.startTime).inMinutes;
      if (durationMinutes > 0) {
        segments.add(
          _buildBarSegment(
            context,
            flex: durationMinutes,
            color: _activityColor(context, a),
            tooltip:
                '${_fmtHm(a.startTime)} - ${_fmtHm(a.endTime)} (${_activityLabel(context, a)})',
            hasBorderLeft: segments.isNotEmpty,
          ),
        );
      }
      cursor = a.endTime;
    }
    final trailingGap = dayEnd.difference(cursor).inMinutes;
    if (trailingGap > 0) {
      segments.add(
        _buildBarSegment(
          context,
          flex: trailingGap,
          color: gapColor,
          tooltip: '${_fmtHm(cursor)} - 24:00',
          hasBorderLeft: segments.isNotEmpty,
        ),
      );
    }

    if (segments.isEmpty) {
      segments.add(
        _buildBarSegment(
          context,
          flex: 1440,
          color: gapColor,
          tooltip: _t('timeline.noData'),
        ),
      );
    }
    return segments;
  }

  Color _activityColor(BuildContext context, TachographActivity a) {
    switch (a.type) {
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

  String _activityLabel(BuildContext context, TachographActivity a) {
    switch (a.type) {
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

  String _fmtHm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _fmtDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${h}s ${m}d';
  }
}
