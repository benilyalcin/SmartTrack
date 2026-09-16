import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/role_permissions.dart';
import '../providers/app_state.dart';
import '../localization/localization.dart';
import '../services/violation_analyzer.dart';
import '../utils/responsive.dart';
import 'animated_bell_button.dart';
import 'animated_profile_avatar.dart';
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
            onLogout: () => context.go('/login'),
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
        IconButton(
          icon: Icon(
            Icons.terminal,
            color: Theme.of(context).colorScheme.primary,
          ),
          tooltip: 'Log',
          onPressed: () => context.push('/kline-log'),
        ),
        IconButton(
          icon: Icon(
            Icons.fact_check_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          tooltip: 'Ham Değerler',
          onPressed: () => context.push('/debug-values'),
        ),
        IconButton(
          icon: Icon(
            Icons.developer_board,
            color: Theme.of(context).colorScheme.primary,
          ),
          tooltip: 'Dongle — Ham Değerler',
          onPressed: () => context.push('/dongle-values'),
        ),
        IconButton(
          icon: Icon(
            Icons.history,
            color: Theme.of(context).colorScheme.primary,
          ),
          tooltip: 'Dongle Log',
          onPressed: () => context.push('/dongle-log'),
        ),
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

  Widget _buildBottomNav(BuildContext context, String lang) {
    return NavigationBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      indicatorColor: Theme.of(context).colorScheme.secondaryContainer,
      selectedIndex: _calculateSelectedIndex(context),
      onDestinationSelected: (int index) => _onItemTapped(index, context),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard),
          label: AppLocalizations.getText(lang, 'nav.dashboard'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.warning_amber_outlined),
          selectedIcon: const Icon(Icons.warning_amber),
          label: AppLocalizations.getText(lang, 'nav.alerts'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.timeline_outlined),
          selectedIcon: const Icon(Icons.timeline),
          label: AppLocalizations.getText(lang, 'nav.timeline'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.analytics_outlined),
          selectedIcon: const Icon(Icons.analytics),
          label: AppLocalizations.getText(lang, 'nav.analysis'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.folder_outlined),
          selectedIcon: const Icon(Icons.folder),
          label: AppLocalizations.getText(lang, 'nav.dddFiles'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: AppLocalizations.getText(lang, 'nav.settings'),
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
        NavigationRailDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard),
          label: Text(AppLocalizations.getText(lang, 'nav.dashboard')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.warning_amber_outlined),
          selectedIcon: const Icon(Icons.warning_amber),
          label: Text(AppLocalizations.getText(lang, 'nav.alerts')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.timeline_outlined),
          selectedIcon: const Icon(Icons.timeline),
          label: Text(AppLocalizations.getText(lang, 'nav.timeline')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.analytics_outlined),
          selectedIcon: const Icon(Icons.analytics),
          label: Text(AppLocalizations.getText(lang, 'nav.analysis')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.folder_outlined),
          selectedIcon: const Icon(Icons.folder),
          label: Text(AppLocalizations.getText(lang, 'nav.dddFiles')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: Text(AppLocalizations.getText(lang, 'nav.settings')),
        ),
      ],
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/logs')) return 1;
    if (location.startsWith('/timeline')) return 2;
    if (location.startsWith('/analysis')) return 3;
    if (location.startsWith('/ddd-files')) return 4;
    if (location.startsWith('/settings')) return 5;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/logs');
        break;
      case 2:
        context.go('/timeline');
        break;
      case 3:
        context.go('/analysis');
        break;
      case 4:
        context.go('/ddd-files');
        break;
      case 5:
        context.go('/settings');
        break;
    }
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
