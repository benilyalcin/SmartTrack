import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/dev_flags.dart';
import '../models/role_permissions.dart';
import '../providers/app_state.dart';
import '../localization/localization.dart';
import '../services/bluetooth_service.dart';
import '../services/violation_analyzer.dart';
import '../utils/responsive.dart';
import 'animated_bell_button.dart';
import 'animated_profile_avatar.dart';
import 'app_snackbar.dart';
import 'compliance_notice_listener.dart';
import 'continuous_driving_limit_dialog.dart';
import 'free_screen_viewer.dart';
import 'gap_fill_dialog.dart';
import 'popup_coordinator.dart';
import 'system_notification_bridge.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final lang = appState.selectedLanguage;

    final isDesktop = isDesktopLayout(context);

    return Scaffold(
      appBar: _buildTopAppBar(context, lang, appState),

      body: Stack(
        children: [
          Row(
            children: [
              if (isDesktop) _buildSideNav(context, lang),
              if (isDesktop) const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: SystemNotificationBridge(
                  child: ComplianceNoticeListener(
                    child: ContinuousDrivingLimitListener(
                      child: appState.freeScreenMode
                          ? FreeScreenViewer(
                              child: GapDetectionListener(child: child),
                            )
                          : GapDetectionListener(child: child),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: isDesktop ? null : _buildBottomNav(context, lang),
    );
  }

  AppBar _buildTopAppBar(BuildContext context, String lang, AppState appState) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: Theme.of(context).colorScheme.outlineVariant,
          height: 1,
        ),
      ),
      title: Row(
        children: [
          AnimatedProfileAvatar(
            onOpenSettings: () => context.go('/settings'),
            onOpenAbout: () => context.push('/about'),
            // Back to choosing a tachograph, with the link to this one closed.
            onLogout: () {
              AppBluetoothService.instance.disconnect();
              appState.setBluetoothConnected(false);
              context.go('/select-device');
            },
          ),
          const SizedBox(width: 12),

          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                AppLocalizations.getGreeting(
                  lang,
                  _greetingName(lang, appState),
                ),
                maxLines: 1,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Developer builds only; the full-screen log with its share button.
        if (kDeveloperBuild)
          IconButton(
            tooltip: 'Log',
            onPressed: () => context.push('/kline-log'),
            icon: Icon(
              Icons.terminal,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        if (appState.isBluetoothConnected)
          _RefreshDataButton(appState: appState, lang: lang),
        _ConnectionButton(appState: appState, lang: lang),
        _NotificationBell(appState: appState, lang: lang),
        const SizedBox(width: 8),
      ],
    );
  }

  String _greetingName(String lang, AppState appState) {
    final isDriver1 = appState.activeDriver == 'driver1';
    final realName = isDriver1
        ? appState.tachographLiveData.driver1Name
        : appState.tachographLiveData.driver2Name;
    return realName.isNotEmpty ? realName : '-';
  }

  /// The tabs, in order. The tachograph tools tab (Remote HMI, download,
  /// calibration) is for an ATC 8256 only; the Log tab exists only in a
  /// developer build.
  static List<_NavTab> _tabsFor(BuildContext context) {
    final hasIts = AppStateProvider.of(context).tachographType?.hasIts ?? false;
    return [
      for (final tab in _tabs)
        if (tab.path != '/vu' || hasIts) tab,
    ];
  }

  static const List<_NavTab> _tabs = [
    _NavTab(
      '/dashboard',
      'nav.dashboard',
      Icons.dashboard_outlined,
      Icons.dashboard,
    ),
    _NavTab(
      '/logs',
      'nav.alerts',
      Icons.warning_amber_outlined,
      Icons.warning_amber,
    ),
    _NavTab(
      '/timeline',
      'nav.timeline',
      Icons.timeline_outlined,
      Icons.timeline,
    ),
    _NavTab(
      '/analysis',
      'nav.analysis',
      Icons.analytics_outlined,
      Icons.analytics,
    ),
    _NavTab('/ddd-files', 'nav.dddFiles', Icons.folder_outlined, Icons.folder),
    _NavTab('/vu', 'nav.vu', Icons.handyman_outlined, Icons.handyman),
    _NavTab(
      '/settings',
      'nav.settings',
      Icons.settings_outlined,
      Icons.settings,
    ),
  ];

  Widget _buildBottomNav(BuildContext context, String lang) {
    return NavigationBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      indicatorColor: Theme.of(context).colorScheme.secondaryContainer,
      selectedIndex: _calculateSelectedIndex(context),
      onDestinationSelected: (int index) => _onItemTapped(index, context),
      destinations: [
        for (final tab in _tabsFor(context))
          NavigationDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.selectedIcon),
            label: tab.label(lang),
          ),
      ],
    );
  }

  Widget _buildSideNav(BuildContext context, String lang) {
    return NavigationRail(
      backgroundColor: Theme.of(context).colorScheme.surface,
      indicatorColor: Theme.of(context).colorScheme.secondaryContainer,
      selectedIndex: _calculateSelectedIndex(context),
      onDestinationSelected: (int index) => _onItemTapped(index, context),
      labelType: NavigationRailLabelType.all,
      destinations: [
        for (final tab in _tabsFor(context))
          NavigationRailDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.selectedIcon),
            label: Text(tab.label(lang)),
          ),
      ],
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    final index = _tabsFor(
      context,
    ).indexWhere((tab) => location.startsWith(tab.path));
    return index < 0 ? 0 : index;
  }

  void _onItemTapped(int index, BuildContext context) {
    context.go(_tabsFor(context)[index].path);
  }
}

/// Reads the vehicle unit now - the way to get fresh data when the automatic
/// refresh is slow or off (Settings > Automatic Data Refresh).
class _RefreshDataButton extends StatelessWidget {
  final AppState appState;
  final String lang;

  const _RefreshDataButton({required this.appState, required this.lang});

  Future<void> _refresh(BuildContext context) async {
    final ok = await AppBluetoothService.instance.refreshNow(appState);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      AppLocalizations.getText(
        lang,
        ok ? 'live.refreshed' : 'live.refreshFailed',
      ),
      type: ok ? AppSnackBarType.success : AppSnackBarType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return ValueListenableBuilder<bool>(
      valueListenable: AppBluetoothService.instance.refreshing,
      builder: (context, busy, _) => IconButton(
        tooltip: AppLocalizations.getText(lang, 'live.refresh'),
        onPressed: busy ? null : () => _refresh(context),
        icon: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Icon(Icons.refresh, color: color),
      ),
    );
  }
}

/// Where the link is managed from anywhere in the app: connected, a tap asks
/// to disconnect; not connected, a tap opens the connection screen. Leaving
/// the app does not end the link - this does.
class _ConnectionButton extends StatelessWidget {
  final AppState appState;
  final String lang;

  const _ConnectionButton({required this.appState, required this.lang});

  String _t(String key) => AppLocalizations.getText(lang, key);

  Future<void> _disconnect(BuildContext context) async {
    final device = appState.connectedDeviceName ?? '-';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('conn.disconnectTitle')),
        content: Text(_t('conn.disconnectBody').replaceAll('{device}', device)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('conn.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_t('conn.disconnect')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await AppBluetoothService.instance.disconnect();
    appState.setBluetoothConnected(false);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      _t('conn.disconnected'),
      type: AppSnackBarType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connected = appState.isBluetoothConnected;
    return IconButton(
      tooltip: _t(connected ? 'conn.connectedTooltip' : 'conn.connectTooltip'),
      onPressed: connected
          ? () => _disconnect(context)
          : () => context.push('/bluetooth-scan'),
      icon: Icon(
        connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
        color: connected ? scheme.primary : scheme.outline,
      ),
    );
  }
}

class _NavTab {
  final String path;

  /// Localization key; null for the developer-only Log tab.
  final String? labelKey;
  final IconData icon;
  final IconData selectedIcon;

  const _NavTab(this.path, this.labelKey, this.icon, this.selectedIcon);

  String label(String lang) {
    final key = labelKey;
    return key == null ? 'Log' : AppLocalizations.getText(lang, key);
  }
}

class _NotificationBell extends StatefulWidget {
  final AppState appState;
  final String lang;
  const _NotificationBell({required this.appState, required this.lang});

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  int _lastSeenCount = 0;

  List<Violation> _drivingRestViolations(AppState appState) {
    return appState.violations
        .where((v) => v.type != ViolationType.missingRecord)
        .toList();
  }

  bool _hasContinuousPreWarning(AppState appState) {
    return appState.pendingComplianceNotice?.id == 'continuous-prewarning';
  }

  @override
  Widget build(BuildContext context) {
    final violations = _drivingRestViolations(widget.appState);
    final hasPreWarning = _hasContinuousPreWarning(widget.appState);
    final count = violations.length + (hasPreWarning ? 1 : 0);
    final unseenCount = count > _lastSeenCount ? count : 0;

    return AnimatedBellButton(
      tooltip: AppLocalizations.getText(widget.lang, 'notifications.title'),
      badgeCount: unseenCount,
      onPressed: () {
        setState(() => _lastSeenCount = count);
        _showNotificationsDialog(context, widget.appState, widget.lang);
      },
    );
  }

  void _showNotificationsDialog(
    BuildContext context,
    AppState appState,
    String lang,
  ) {
    final violations = _drivingRestViolations(appState)
      ..sort((a, b) => b.start.compareTo(a.start));
    final preWarningMessage = _hasContinuousPreWarning(appState)
        ? appState.pendingComplianceNotice!.message
        : null;
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.getText(lang, 'notifications.title')),
        content: SizedBox(
          width: 380,
          child: (violations.isEmpty && preWarningMessage == null)
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    AppLocalizations.getText(lang, 'notifications.empty'),
                    style: TextStyle(fontSize: 13, color: scheme.outline),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (preWarningMessage != null)
                        _notificationRow(
                          context,
                          icon: Icons.info_outline,
                          iconColor: scheme.secondary,
                          title: preWarningMessage,
                          subtitle: null,
                        ),
                      for (final v in violations)
                        _notificationRow(
                          context,
                          icon: Icons.warning_amber_rounded,
                          iconColor: scheme.error,
                          title: AppLocalizations.getText(
                            lang,
                            v.descriptionKey,
                          ),
                          subtitle:
                              '${v.ruleReference} · ${_fmtHm(v.start)} ${AppLocalizations.getText(lang, 'notifications.since')}',
                        ),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.getText(lang, 'settings.close')),
          ),
        ],
      ),
    );
  }

  Widget _notificationRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtHm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class GapDetectionListener extends StatefulWidget {
  final Widget child;
  const GapDetectionListener({super.key, required this.child});

  @override
  State<GapDetectionListener> createState() => _GapDetectionListenerState();
}

class _GapDetectionListenerState extends State<GapDetectionListener> {
  bool _dialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShowGapDialog(context, appState),
    );
    return widget.child;
  }

  void _maybeShowGapDialog(BuildContext context, AppState appState) {
    if (_dialogOpen || !mounted) return;
    if (appState.activeRole != AppRole.driver) return;

    final gap = appState.pendingRealGap;
    if (gap == null) return;

    _dialogOpen = true;
    PopupCoordinator.instance.requestDialog(
      id: 'gap-fill',

      priority: 0,
      show: () =>
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => GapFillDialog(gap: gap),
          ).then((_) {
            _dialogOpen = false;
          }),
    );
  }
}

class ContinuousDrivingLimitListener extends StatefulWidget {
  final Widget child;
  const ContinuousDrivingLimitListener({super.key, required this.child});

  @override
  State<ContinuousDrivingLimitListener> createState() =>
      _ContinuousDrivingLimitListenerState();
}

class _ContinuousDrivingLimitListenerState
    extends State<ContinuousDrivingLimitListener> {
  bool _dialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShowDialog(context, appState),
    );
    return widget.child;
  }

  void _maybeShowDialog(BuildContext context, AppState appState) {
    if (_dialogOpen || !mounted) return;
    final message = appState.pendingContinuousLimitDialogMessage;
    if (message == null) return;

    _dialogOpen = true;
    PopupCoordinator.instance.requestDialog(
      id: 'continuous-driving-limit',

      priority: 10,
      show: () =>
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => ContinuousDrivingLimitDialog(
              message: message,
              onAcknowledge: appState.acknowledgeContinuousLimitDialog,
            ),
          ).then((_) {
            _dialogOpen = false;
          }),
    );
  }
}
