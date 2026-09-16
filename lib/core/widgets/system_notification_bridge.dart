import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/localization.dart';
import '../providers/app_state.dart';
import '../services/notification_service.dart';

class SystemNotificationBridge extends StatefulWidget {
  final Widget child;
  const SystemNotificationBridge({super.key, required this.child});

  @override
  State<SystemNotificationBridge> createState() =>
      _SystemNotificationBridgeState();
}

class _SystemNotificationBridgeState extends State<SystemNotificationBridge> {
  static const _lastViolationCountKey = 'notif_last_violation_count_v1';
  static const _lastNoticeIdKey = 'notif_last_notice_id_v1';
  static const _lastCompDebtWeekKey = 'notif_last_comp_debt_week_v1';

  static const _violationSummaryNotificationId = 9001;
  static const _complianceNoticeNotificationId = 9002;
  static const _compensationDebtNotificationId = 9003;

  int _lastViolationCount = 0;
  String? _lastNoticeId;
  String? _lastCompDebtWeek;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.init();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _lastViolationCount = prefs.getInt(_lastViolationCountKey) ?? 0;
      _lastNoticeId = prefs.getString(_lastNoticeIdKey);
      _lastCompDebtWeek = prefs.getString(_lastCompDebtWeekKey);
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    if (_loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync(appState));
    }
    return widget.child;
  }

  void _sync(AppState appState) {
    final lang = appState.selectedLanguage;
    String t(String key) => AppLocalizations.getText(lang, key);

    _syncViolations(appState, t);
    _syncComplianceNotice(appState, t);
    _syncCompensationDebts(appState, t);
  }

  Future<void> _syncViolations(
    AppState appState,
    String Function(String) t,
  ) async {
    final count = appState.violations.length;
    if (count == _lastViolationCount) return;
    if (count > _lastViolationCount) {
      await NotificationService.instance.notify(
        id: _violationSummaryNotificationId,
        title: t('notifications.violationTitle'),
        body: t(
          'notifications.violationSummaryBody',
        ).replaceFirst('{count}', '$count'),
      );
    }
    _lastViolationCount = count;
    (await SharedPreferences.getInstance()).setInt(
      _lastViolationCountKey,
      count,
    );
  }

  Future<void> _syncComplianceNotice(
    AppState appState,
    String Function(String) t,
  ) async {
    final notice = appState.pendingComplianceNotice;
    final id = notice?.id;
    if (id == _lastNoticeId) return;
    if (notice != null) {
      await NotificationService.instance.notify(
        id: _complianceNoticeNotificationId,
        title: t('notifications.noticeTitle'),
        body: notice.message,
      );
    }
    _lastNoticeId = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_lastNoticeIdKey);
    } else {
      await prefs.setString(_lastNoticeIdKey, id);
    }
  }

  Future<void> _syncCompensationDebts(
    AppState appState,
    String Function(String) t,
  ) async {
    final now = DateTime.now();
    if (now.weekday != DateTime.friday) return;
    final debts = appState.activeCompensationDebts;
    if (debts.isEmpty) return;

    final weekKey = '${now.year}-W${_isoWeekNumber(now)}';
    if (weekKey == _lastCompDebtWeek) return;

    await NotificationService.instance.notify(
      id: _compensationDebtNotificationId,
      title: t('notifications.compensationDebtTitle'),
      body: t('notifications.compensationDebtBody'),
    );
    _lastCompDebtWeek = weekKey;
    (await SharedPreferences.getInstance()).setString(
      _lastCompDebtWeekKey,
      weekKey,
    );
  }

  int _isoWeekNumber(DateTime date) {
    final thursday = date.add(Duration(days: 3 - ((date.weekday + 6) % 7)));
    final firstThursday = DateTime(thursday.year, 1, 4);
    final diff = thursday.difference(firstThursday);
    return 1 + (diff.inDays / 7).floor();
  }
}
