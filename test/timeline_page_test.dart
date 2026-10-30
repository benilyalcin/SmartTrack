import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttrack_mine/core/providers/app_state.dart';
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
}
