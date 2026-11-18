import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttrack_mine/core/providers/app_state.dart';
import 'package:smarttrack_mine/core/services/time/display_time.dart';
import 'package:smarttrack_mine/features/dashboard/dashboard_page.dart';

/// The cumulative break card shows only what the unit read (0xF925);
/// offline, the last value with the time it was read.
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
}
