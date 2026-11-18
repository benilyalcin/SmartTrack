import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttrack_mine/core/providers/app_state.dart';
import 'package:smarttrack_mine/core/services/time/display_time.dart';
import 'package:smarttrack_mine/features/dashboard/dashboard_page.dart';

/// The live counter cards (cumulative break, continuous, daily, weekly,
/// bi-weekly driving) show only what the unit read; offline, the last value
/// with the local time it was read, faded; never read, a dash.
Future<void> pumpDashboard(
  WidgetTester tester,
  Map<String, Object> prefs,
) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AppStateProvider(
      child: const MaterialApp(home: Scaffold(body: DashboardPage())),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump();
}

Finder cardText(String text) => find.descendant(
  of: find
      .ancestor(
        of: find.text('Kümülatif mola süresi'),
        matching: find.byType(Column),
      )
      .first,
  matching: find.text(text),
);

void main() {
  testWidgets('never read: a dash', (tester) async {
    await pumpDashboard(tester, {});
    expect(cardText('-'), findsOneWidget);
  });

  testWidgets('offline: the last value read and when', (tester) async {
    final readAt = DateTime.utc(2026, 11, 18, 11, 32);
    await pumpDashboard(tester, {
      'liveComplianceSnapshot': jsonEncode({
        'totalBreakTimeMs': const Duration(minutes: 35).inMilliseconds,
        'totalBreakTimeReadAt': readAt.toIso8601String(),
      }),
    });
    expect(cardText('00:35 sa'), findsOneWidget);
    expect(
      cardText('son: ${DisplayTime.fromConfig().hm(readAt)}'),
      findsOneWidget,
    );
    expect(cardText('son: 14:32'), findsOneWidget);
  });

  testWidgets('a value saved without a read time is not shown', (tester) async {
    await pumpDashboard(tester, {
      'liveComplianceSnapshot': jsonEncode({
        'totalBreakTimeMs': const Duration(hours: 31).inMilliseconds,
      }),
    });
    expect(cardText('-'), findsOneWidget);
  });

  testWidgets('offline: driving counters show the unit value and when', (
    tester,
  ) async {
    final readAt = DateTime.utc(2026, 11, 18, 9, 5);
    await pumpDashboard(tester, {
      'liveComplianceSnapshot': jsonEncode({
        'drivingRules': {
          'continuous': const Duration(minutes: 150).inMilliseconds,
          'weekly': const Duration(hours: 20).inMilliseconds,
        },
        'drivingRulesReadAt': {
          'continuous': readAt.toIso8601String(),
          'weekly': readAt.toIso8601String(),
        },
      }),
    });
    expect(find.text('02:30 sa'), findsOneWidget);
    expect(find.text('son: 12:05'), findsNWidgets(2));
  });

  testWidgets('a counter saved without a read time is not shown', (
    tester,
  ) async {
    await pumpDashboard(tester, {
      'liveComplianceSnapshot': jsonEncode({
        'drivingRules': {
          'continuous': const Duration(minutes: 150).inMilliseconds,
        },
      }),
    });
    expect(find.text('02:30 sa'), findsNothing);
    expect(find.textContaining('son: '), findsNothing);
  });

  testWidgets('a card file does not overwrite the unit counters', (
    tester,
  ) async {
    final readAt = DateTime.utc(2026, 11, 18, 9, 5);
    final now = DateTime.now();
    await pumpDashboard(tester, {
      'liveComplianceSnapshot': jsonEncode({
        'drivingRules': {
          'continuous': const Duration(minutes: 150).inMilliseconds,
        },
        'drivingRulesReadAt': {'continuous': readAt.toIso8601String()},
      }),
      // Four hours of driving in the app's own log: its own calculation
      // would say 04:00.
      'liveActivityLog': jsonEncode([
        {
          'type': 3,
          'start': now
              .subtract(const Duration(hours: 4))
              .toUtc()
              .toIso8601String(),
          'end': now.toUtc().toIso8601String(),
        },
      ]),
    });
    expect(find.text('02:30 sa'), findsOneWidget);
    expect(find.text('04:00 sa'), findsNothing);
  });
}
