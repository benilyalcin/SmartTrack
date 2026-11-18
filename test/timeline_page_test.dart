import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttrack_mine/core/providers/app_state.dart';
import 'package:smarttrack_mine/core/services/driving_time_calculator.dart';
import 'package:smarttrack_mine/features/timeline/timeline_page.dart';

void main() {
  testWidgets('timeline chart does not overflow on a narrow screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppStateProvider(
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(1.5),
          ),
          child: const MaterialApp(home: TimelinePage()),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a long violation text wraps instead of overflowing', (
    tester,
  ) async {
    // Eight days of work with no rest: the weekly rest is late until now.
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'liveActivityLog': jsonEncode([
        {
          'type': ActivityType.work.index,
          'start': now.subtract(const Duration(days: 8)).toIso8601String(),
          'end': now.toIso8601String(),
        },
      ]),
    });
    tester.view.physicalSize = const Size(360, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppStateProvider(
        child: const MediaQuery(
          data: MediaQueryData(size: Size(360, 3000)),
          child: MaterialApp(home: TimelinePage()),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(
      find.text('Haftalık dinlenme geç başladı (6×24 saat aşıldı)'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}
