import 'package:flutter/material.dart';

import '../../core/localization/localization.dart';
import '../../core/models/vehicle_unit_data.dart' show VuOverspeedingEvent;
import '../../core/providers/app_state.dart';
import '../../core/services/driving_time_calculator.dart'
    show TachographActivity;
import '../../core/services/kline_protocol.dart' show DtcCodes;
import '../../core/services/violation_analyzer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/bluetooth_warning_banner.dart';
import '../../core/widgets/card_slot_warning_banner.dart';

class _AlertItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime? timestamp;

  const _AlertItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.timestamp,
  });
}

class _AlertCategory {
  final IconData icon;
  final String title;
  final String description;
  final String badgeText;
  final Color accentBg;
  final Color accentFg;
  final List<_AlertItem> items;
  final String emptyText;
  final Color dotColor;

  const _AlertCategory({
    required this.icon,
    required this.title,
    required this.description,
    required this.badgeText,
    required this.accentBg,
    required this.accentFg,
    required this.items,
    required this.emptyText,
    required this.dotColor,
  });
}

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final ViolationAnalyzer _violationAnalyzer = ViolationAnalyzer();

  DateTime? _referenceDate;

  String _t(String key) {
    return AppLocalizations.getText(
      AppStateProvider.of(context).selectedLanguage,
      key,
    );
  }

  List<dynamic> _realEvents(AppState appState, DateTime referenceDate) {
    final active = appState.activeDddFile;
    if (active == null || active.isSimulated) return const [];
    final data = appState.currentParsedData;
    if (data == null) return const [];
    bool sameDay(DateTime t) =>
        t.year == referenceDate.year &&
        t.month == referenceDate.month &&
        t.day == referenceDate.day;
    return [
      ...data.lastEvents.where((e) => sameDay(e.timestamp)),
      ...data.lastFaults.where((e) => sameDay(e.timestamp)),
    ];
  }

  bool _hasRealCardData(AppState appState) {
    final active = appState.activeDddFile;
    return active != null &&
        !active.isSimulated &&
        appState.currentParsedData != null;
  }

  List<VuOverspeedingEvent> _vuOverspeedingEvents(
    AppState appState,
    DateTime referenceDate,
  ) {
    final vuData = appState.activeVuData;
    if (vuData == null) return const [];
    return vuData.overspeedingEvents.where((e) {
      final t = e.beginTime;
      if (t == null) return false;
      return t.year == referenceDate.year &&
          t.month == referenceDate.month &&
          t.day == referenceDate.day;
    }).toList();
  }

  String _fmtDateTime(DateTime dt) {
    final ref = _referenceDate ?? DateTime.now();
    final isToday =
        dt.year == ref.year && dt.month == ref.month && dt.day == ref.day;
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (isToday) return time;
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} $time';
  }

  Future<void> _pickReferenceDate(DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('tr'),
    );
    if (picked != null) setState(() => _referenceDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isDesktop = isDesktopLayout(context);
    final activityLog = appState.activityLog;
    _referenceDate ??= activityLog.isNotEmpty
        ? activityLog.last.endTime
        : DateTime.now();
    final referenceDate = _referenceDate!;
    final padding = isDesktop
        ? const EdgeInsets.all(48)
        : const EdgeInsets.all(16);

    final categories = [
      _buildDrivingRestCategory(context, appState, activityLog, referenceDate),
      _buildCardUsageCategory(context, appState, referenceDate),
      _buildSpeedingCategory(context, appState, referenceDate),
      _buildSecurityCategory(context, appState, referenceDate),
      _buildHardwareCategory(context, appState, referenceDate),
      _buildMaintenanceCategory(context, appState, referenceDate),
    ];

    return Scaffold(
      backgroundColor: scheme.surface,
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
                  Text(
                    _t('alerts.pageTitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isDesktop ? 32 : 24,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('alerts.pageSubtitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(child: _buildReferenceDateRow(context, referenceDate)),
                  const SizedBox(height: 8),
                  Center(child: _buildReferenceDateNav(context, referenceDate)),
                  const SizedBox(height: 24),
                  _buildCategoryGrid(context, categories, isDesktop),
                  const SizedBox(height: 32),
                  _buildEventLog(context, categories),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReferenceDateRow(BuildContext context, DateTime referenceDate) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _pickReferenceDate(referenceDate),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.formatDate(
                AppStateProvider.of(context).selectedLanguage,
                referenceDate,
              ),
              style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceDateNav(BuildContext context, DateTime referenceDate) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDateNavButton(
          context,
          label: _t('timeline.prev'),
          icon: Icons.chevron_left,
          onTap: () {
            setState(
              () => _referenceDate = referenceDate.subtract(
                const Duration(days: 1),
              ),
            );
          },
        ),
        const SizedBox(width: 4),
        _buildDateNavButton(
          context,
          label: _t('timeline.today'),
          onTap: () => _pickReferenceDate(referenceDate),
        ),
        const SizedBox(width: 4),
        _buildDateNavButton(
          context,
          label: _t('timeline.next'),
          icon: Icons.chevron_right,
          isIconRight: true,
          onTap: () {
            setState(
              () => _referenceDate = referenceDate.add(const Duration(days: 1)),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDateNavButton(
    BuildContext context, {
    required String label,
    IconData? icon,
    bool isIconRight = false,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        backgroundColor: scheme.surface,
        side: BorderSide(color: scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null && !isIconRight) ...[
            Icon(icon, size: 18, color: scheme.onSurface),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          if (icon != null && isIconRight) ...[
            const SizedBox(width: 4),
            Icon(icon, size: 18, color: scheme.onSurface),
          ],
        ],
      ),
    );
  }

  String _formatFullDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _fmtFullDateTime(DateTime dt) {
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${_formatFullDate(dt)} $time';
  }

  String _fmtHm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  _AlertCategory _buildDrivingRestCategory(
    BuildContext context,
    AppState appState,
    List<TachographActivity> activityLog,
    DateTime referenceDate,
  ) {
    final scheme = Theme.of(context).colorScheme;

    final dayStart = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final endOfReferenceDay = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
      23,
      59,
      59,
      999,
    );

    final violations = _violationAnalyzer
        .analyze(activityLog, endOfReferenceDay)
        .where(
          (v) => v.start.isBefore(endOfReferenceDay) && v.end.isAfter(dayStart),
        )
        .toList();

    final hasAnyActivityThisDay = activityLog.any(
      (a) =>
          a.startTime.isBefore(endOfReferenceDay) &&
          a.endTime.isAfter(dayStart),
    );
    if (activityLog.isNotEmpty &&
        !hasAnyActivityThisDay &&
        !violations.any((v) => v.type == ViolationType.missingRecord)) {
      violations.add(
        Violation(
          type: ViolationType.missingRecord,
          severity: ViolationSeverity.warning,
          start: dayStart,
          end: endOfReferenceDay,
          descriptionKey: 'violation.missingRecord',
          ruleReference: 'EU 561/2006 Art. 15',
        ),
      );
    }
    final items = violations.map((v) {
      final isPointInTime =
          v.type == ViolationType.weeklyDrivingExceeded ||
          v.type == ViolationType.biWeeklyDrivingExceeded;
      final clippedStart = v.start.isBefore(dayStart) ? dayStart : v.start;
      final clippedEnd = v.end.isAfter(endOfReferenceDay)
          ? endOfReferenceDay
          : v.end;
      return _AlertItem(
        icon: Icons.warning_amber_rounded,
        title: _t(v.descriptionKey),
        subtitle: isPointInTime
            ? _fmtFullDateTime(v.start)
            : '${_fmtHm(clippedStart)} - ${_fmtHm(clippedEnd)}',
        timestamp: v.start,
      );
    }).toList();
    items.addAll(_timeRelatedStateItems(appState, maintenance: false));

    return _AlertCategory(
      icon: Icons.schedule,
      title: _t('alerts.drivingRestTitle'),
      description: _t('alerts.drivingRestDesc'),
      badgeText: items.isEmpty
          ? _t('alerts.badgeOk')
          : _t(
              'alerts.badgeActiveCount',
            ).replaceFirst('{count}', '${items.length}'),
      accentBg: scheme.tertiaryContainer,
      accentFg: scheme.onTertiaryContainer,
      items: items,
      emptyText: _t('compliance.noViolationsDesc'),
      dotColor: scheme.tertiary,
    );
  }

  ({String key, bool isMaintenance})? _timeRelatedStateInfo(int code) {
    switch (code) {
      case 1:
        return (key: 'alerts.trsContinuousPreWarning', isMaintenance: false);
      case 2:
        return (
          key: 'violation.continuousDrivingExceeded',
          isMaintenance: false,
        );
      case 3:
        return (key: 'alerts.trsDailyPreWarning', isMaintenance: false);
      case 4:
        return (key: 'violation.dailyDrivingExceeded', isMaintenance: false);
      case 5:
        return (key: 'alerts.trsRestPreWarning', isMaintenance: false);
      case 6:
        return (key: 'alerts.trsRestWarning', isMaintenance: false);
      case 7:
        return (key: 'alerts.trsWeeklyPreWarning', isMaintenance: false);
      case 8:
        return (key: 'violation.weeklyDrivingExceeded', isMaintenance: false);
      case 9:
        return (key: 'alerts.trsBiWeeklyPreWarning', isMaintenance: false);
      case 10:
        return (key: 'violation.biWeeklyDrivingExceeded', isMaintenance: false);
      case 11:
        return (key: 'alerts.trsCardExpiryWarning', isMaintenance: true);
      case 12:
        return (key: 'alerts.trsNextDownloadWarning', isMaintenance: true);
      case 13:
        return (key: 'alerts.trsOther', isMaintenance: false);
      default:
        return null;
    }
  }

  List<_AlertItem> _timeRelatedStateItems(
    AppState appState, {
    required bool maintenance,
  }) {
    final live = appState.tachographLiveData;
    final items = <_AlertItem>[];

    void addFor(int? code, String driverLabelKey) {
      if (code == null || code == 0) return;
      final info = _timeRelatedStateInfo(code);
      if (info == null || info.isMaintenance != maintenance) return;

      if (info.key.startsWith('violation.')) return;
      items.add(
        _AlertItem(
          icon: Icons.notifications_active,
          title: '${_t(info.key)} (${_t(driverLabelKey)})',
          subtitle: _t('alerts.deviceReported'),
          timestamp: DateTime.now(),
        ),
      );
    }

    addFor(live.driver1TimeRelatedState, 'dashboard.driver1Tab');
    addFor(live.driver2TimeRelatedState, 'dashboard.driver2Tab');
    return items;
  }

  _AlertCategory _buildCardUsageCategory(
    BuildContext context,
    AppState appState,
    DateTime referenceDate,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final items = <_AlertItem>[];

    final isDrivingNow = appState.currentActivity == 'dashboard.driving';
    final slot1 = appState.tachographLiveData.cardSlot1;
    if (isDrivingNow && slot1 != 1) {
      items.add(
        _AlertItem(
          icon: Icons.error,
          title: _t('alerts.cardlessDriving'),
          subtitle: _t('alerts.liveNow'),
          timestamp: DateTime.now(),
        ),
      );
    }

    for (final e in _realEvents(appState, referenceDate)) {
      const cardEventCodes = {1, 2, 4, 5, 6};
      final isCardIssue =
          (e.isFault == false && cardEventCodes.contains(e.code)) ||
          (e.isFault == true && e.code == 64);
      if (isCardIssue) {
        items.add(
          _AlertItem(
            icon: Icons.credit_card_off,
            title: e.description,
            subtitle: _fmtDateTime(e.timestamp),
            timestamp: e.timestamp,
          ),
        );
      }
    }

    return _AlertCategory(
      icon: Icons.credit_card_off,
      title: _t('alerts.cardUsageTitle'),
      description: _t('alerts.cardUsageDesc'),
      badgeText: items.isEmpty
          ? _t('alerts.badgeOk')
          : _t('alerts.badgeCritical'),
      accentBg: scheme.errorContainer,
      accentFg: scheme.onErrorContainer,
      items: items,
      emptyText: _t('alerts.cardUsageEmpty'),
      dotColor: scheme.error,
    );
  }

  _AlertCategory _buildSpeedingCategory(
    BuildContext context,
    AppState appState,
    DateTime referenceDate,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final items = <_AlertItem>[];
    final live = appState.tachographLiveData;

    if (live.speedLimitKmh > 0 && live.speedKmh > live.speedLimitKmh) {
      items.add(
        _AlertItem(
          icon: Icons.speed,
          title: _t('alerts.speedExceededLive')
              .replaceFirst('{speed}', '${live.speedKmh}')
              .replaceFirst('{limit}', '${live.speedLimitKmh}'),
          subtitle: _t('alerts.liveNow'),
          timestamp: DateTime.now(),
        ),
      );
    }

    for (final e in _realEvents(appState, referenceDate)) {
      if (e.isFault == false && e.code == 7) {
        items.add(
          _AlertItem(
            icon: Icons.speed,
            title: e.description,
            subtitle: _fmtDateTime(e.timestamp),
            timestamp: e.timestamp,
          ),
        );
      }
    }

    for (final e in _vuOverspeedingEvents(appState, referenceDate)) {
      items.add(
        _AlertItem(
          icon: Icons.speed,
          title: _t('alerts.speedExceededVu')
              .replaceFirst('{maxSpeed}', '${e.maxSpeedKmh}')
              .replaceFirst('{avgSpeed}', '${e.avgSpeedKmh}'),
          subtitle: _fmtDateTime(e.beginTime!),
          timestamp: e.beginTime!,
        ),
      );
    }

    return _AlertCategory(
      icon: Icons.speed,
      title: _t('alerts.speedingTitle'),
      description: _t('alerts.speedingDesc'),
      badgeText: items.isEmpty
          ? _t('alerts.badgeOk')
          : _t(
              'alerts.badgeActiveCount',
            ).replaceFirst('{count}', '${items.length}'),
      accentBg: scheme.errorContainer,
      accentFg: scheme.onErrorContainer,
      items: items,
      emptyText: _t('alerts.speedingDesc'),
      dotColor: scheme.error,
    );
  }

  _AlertCategory _buildSecurityCategory(
    BuildContext context,
    AppState appState,
    DateTime referenceDate,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final items = <_AlertItem>[];

    for (final e in _realEvents(appState, referenceDate)) {
      const securityEventCodes = {3, 10, 19};
      if (e.isFault == false && securityEventCodes.contains(e.code)) {
        items.add(
          _AlertItem(
            icon: Icons.security,
            title: e.description,
            subtitle: _fmtDateTime(e.timestamp),
            timestamp: e.timestamp,
          ),
        );
      }
    }

    final hasData = _hasRealCardData(appState);
    final badge = !hasData
        ? _t('alerts.badgeNoData')
        : (items.isEmpty
              ? _t('alerts.badgeSecure')
              : _t('alerts.badgeCritical'));

    return _AlertCategory(
      icon: Icons.gpp_maybe,
      title: _t('alerts.securityTitle'),
      description: _t('alerts.securityDesc'),
      badgeText: badge,
      accentBg: scheme.inverseSurface,
      accentFg: scheme.onInverseSurface,
      items: items,
      emptyText: hasData ? _t('alerts.securityEmpty') : _t('alerts.noDataDesc'),
      dotColor: scheme.onSurface,
    );
  }

  List<({String hex, String? description})> _parseDtcRecords(String hex) {
    if (hex.isEmpty) return const [];
    final bytes = hex
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => int.parse(s, radix: 16))
        .toList();
    final records = <({String hex, String? description})>[];
    for (var i = 0; i + 3 < bytes.length; i += 4) {
      final high = bytes[i], mid = bytes[i + 1], low = bytes[i + 2];
      records.add((
        hex: bytes
            .sublist(i, i + 4)
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(' '),
        description: DtcCodes.describe(high, mid, low),
      ));
    }
    return records;
  }

  _AlertCategory _buildHardwareCategory(
    BuildContext context,
    AppState appState,
    DateTime referenceDate,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final items = <_AlertItem>[];
    final dtcCount = appState.tachographLiveData.dtcCount;

    final now = DateTime.now();
    final isToday =
        referenceDate.year == now.year &&
        referenceDate.month == now.month &&
        referenceDate.day == now.day;
    if (isToday) {
      for (final dtc in _parseDtcRecords(
        appState.tachographLiveData.dtcRawHex,
      )) {
        items.add(
          _AlertItem(
            icon: Icons.build,
            title: dtc.description ?? 'Bilinmeyen arıza kodu',
            subtitle: dtc.hex,
            timestamp: now,
          ),
        );
      }
    }

    for (final e in _realEvents(appState, referenceDate)) {
      const hardwareEventCodes = {8, 9};
      final isHardwareIssue =
          (e.isFault == true && e.code != 64) ||
          (e.isFault == false && hardwareEventCodes.contains(e.code));
      if (isHardwareIssue) {
        items.add(
          _AlertItem(
            icon: Icons.build,
            title: e.description,
            subtitle: _fmtDateTime(e.timestamp),
            timestamp: e.timestamp,
          ),
        );
      }
    }

    final hasData = dtcCount != null || _hasRealCardData(appState);
    final badge = items.isNotEmpty
        ? _t('alerts.badgeTechnical')
        : (hasData ? _t('alerts.badgeOk') : _t('alerts.badgeNoData'));

    return _AlertCategory(
      icon: Icons.build,
      title: _t('alerts.hardwareTitle'),
      description: _t('alerts.hardwareDesc'),
      badgeText: badge,
      accentBg: scheme.surfaceContainerHighest,
      accentFg: scheme.onSurfaceVariant,
      items: items,
      emptyText: hasData ? _t('alerts.hardwareEmpty') : _t('alerts.noDataDesc'),
      dotColor: scheme.onSurfaceVariant,
    );
  }

  _AlertCategory _buildMaintenanceCategory(
    BuildContext context,
    AppState appState,
    DateTime referenceDate,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final items = <_AlertItem>[];
    var overdue = false;
    var dueSoon = false;

    final nextCalibration = appState.tachographLiveData.nextCalibrationDate;
    if (nextCalibration != null) {
      final daysLeft = nextCalibration.difference(referenceDate).inDays;
      final isOverdue = daysLeft < 0;
      final isDueSoon = !isOverdue && daysLeft < 30;
      overdue = overdue || isOverdue;
      dueSoon = dueSoon || isDueSoon;
      items.add(
        _AlertItem(
          icon: Icons.settings_suggest,
          title: _t('compliance.calibration'),
          subtitle: isOverdue
              ? _t('compliance.calibrationOverdue')
              : _t('alerts.daysLeftLabel').replaceFirst('{d}', '$daysLeft'),
        ),
      );
    }

    final expiry =
        appState.driverCardExpiryDate ??
        appState.currentParsedData?.cardExpiryDate;
    if (expiry != null) {
      final daysLeft = expiry.difference(referenceDate).inDays;
      final isOverdue = daysLeft < 0;
      final isDueSoon = !isOverdue && daysLeft < 30;
      overdue = overdue || isOverdue;
      dueSoon = dueSoon || isDueSoon;
      items.add(
        _AlertItem(
          icon: Icons.credit_card,
          title: _t('compliance.driverCard'),
          subtitle: isOverdue
              ? _t('compliance.driverCardExpired')
              : _t('alerts.daysLeftLabel').replaceFirst('{d}', '$daysLeft'),
        ),
      );
    }

    final deviceItems = _timeRelatedStateItems(appState, maintenance: true);
    if (deviceItems.isNotEmpty) dueSoon = true;
    items.addAll(deviceItems);

    final badge = overdue
        ? _t('compliance.calibrationOverdue')
        : (dueSoon
              ? _t('compliance.calibrationDueSoon')
              : (items.isEmpty
                    ? _t('alerts.badgeNoData')
                    : _t('alerts.badgeOk')));

    return _AlertCategory(
      icon: Icons.build_circle,
      title: _t('alerts.maintenanceTitle'),
      description: _t('alerts.maintenanceDesc'),
      badgeText: badge,
      accentBg: scheme.primaryContainer,
      accentFg: scheme.onPrimaryContainer,
      items: items,
      emptyText: _t('alerts.noDataDesc'),
      dotColor: scheme.primary,
    );
  }

  Widget _buildCategoryGrid(
    BuildContext context,
    List<_AlertCategory> categories,
    bool isDesktop,
  ) {
    if (!isDesktop) {
      return Column(
        children: [
          for (final c in categories) ...[
            _buildCategoryCard(context, c),
            const SizedBox(height: 16),
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < categories.length; i += 2) {
      final second = i + 1 < categories.length ? categories[i + 1] : null;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildCategoryCard(context, categories[i])),
              const SizedBox(width: 16),
              Expanded(
                child: second != null
                    ? _buildCategoryCard(context, second)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
      rows.add(const SizedBox(height: 16));
    }
    return Column(children: rows);
  }

  Widget _buildCategoryCard(BuildContext context, _AlertCategory category) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: category.accentBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(category.icon, color: category.accentFg, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: category.accentBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  category.badgeText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: category.accentFg,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            category.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            category.description,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (category.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                category.emptyText,
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
            )
          else
            ...category.items.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      item.icon,
                      size: 18,
                      color: category.accentFg == scheme.onInverseSurface
                          ? scheme.onSurface
                          : category.accentBg,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventLog(BuildContext context, List<_AlertCategory> categories) {
    final scheme = Theme.of(context).colorScheme;

    final rows = <(_AlertItem item, Color dot)>[];
    for (final c in categories) {
      for (final item in c.items) {
        if (item.timestamp != null) rows.add((item, c.dotColor));
      }
    }
    rows.sort((a, b) => b.$1.timestamp!.compareTo(a.$1.timestamp!));
    final topRows = rows.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('alerts.eventLogTitle'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: topRows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _t('alerts.eventLogEmpty'),
                    style: TextStyle(color: scheme.outline),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < topRows.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: i == 0
                              ? null
                              : Border(
                                  top: BorderSide(color: scheme.outlineVariant),
                                ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 76,
                              child: Text(
                                _fmtDateTime(topRows[i].$1.timestamp!),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: topRows[i].$2,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                topRows[i].$1.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurface,
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
    );
  }
}
