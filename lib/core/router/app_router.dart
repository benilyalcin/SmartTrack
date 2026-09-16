import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/main_layout.dart';
import '../../features/about/about_page.dart';
import '../../features/alerts/alerts_page.dart';
import '../../features/analysis/analysis_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/dashboard/driver_mode_page.dart';
import '../../features/ddd_files/ddd_file_detail_page.dart';
import '../../features/ddd_files/ddd_files_page.dart';
import '../../features/ddd_files/ddd_trash_page.dart';
import '../../features/debug/dongle_download_results_page.dart';
import '../../features/debug/dongle_log_page.dart';
import '../../features/debug/dongle_values_debug_page.dart';
import '../../features/debug/kline_log_page.dart';
import '../../features/debug/values_debug_page.dart';
import '../../features/settings/bluetooth_scan_page.dart';
import '../../features/splash/splash_page.dart';
import '../../features/timeline/timeline_page.dart';
import '../../features/settings/settings_page.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: SplashPage()),
    ),
    GoRoute(
      path: '/login',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: LoginPage()),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DashboardPage()),
        ),
        GoRoute(
          path: '/logs',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AlertsPage()),
        ),
        GoRoute(
          path: '/timeline',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TimelinePage()),
        ),
        GoRoute(
          path: '/analysis',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AnalysisPage()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsPage()),
        ),
        GoRoute(
          path: '/ddd-files',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DddFilesPage()),
        ),
        GoRoute(
          path: '/ddd-files/trash',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DddTrashPage()),
        ),
        GoRoute(
          path: '/ddd-files/:id',
          pageBuilder: (context, state) => NoTransitionPage(
            child: DddFileDetailPage(fileId: state.pathParameters['id']!),
          ),
        ),
      ],
    ),

    GoRoute(
      path: '/bluetooth-scan',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => const MaterialPage(
        fullscreenDialog: true,
        child: BluetoothScanPage(),
      ),
    ),

    GoRoute(
      path: '/driver-mode',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) =>
          const MaterialPage(fullscreenDialog: true, child: DriverModePage()),
    ),

    GoRoute(
      path: '/about',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AboutPage(),
    ),
    GoRoute(
      path: '/kline-log',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) =>
          const MaterialPage(fullscreenDialog: true, child: KLineLogPage()),
    ),
    GoRoute(
      path: '/debug-values',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) =>
          const MaterialPage(fullscreenDialog: true, child: ValuesDebugPage()),
    ),
    GoRoute(
      path: '/dongle-values',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => const MaterialPage(
        fullscreenDialog: true,
        child: DongleValuesDebugPage(),
      ),
    ),
    GoRoute(
      path: '/dongle-log',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) =>
          const MaterialPage(fullscreenDialog: true, child: DongleLogPage()),
    ),
    GoRoute(
      path: '/dongle-download-results',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => const MaterialPage(
        fullscreenDialog: true,
        child: DongleDownloadResultsPage(),
      ),
    ),
  ],
);
