import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttrack_mine/core/providers/app_state.dart';
import 'package:smarttrack_mine/core/services/kline_protocol.dart';
import 'package:smarttrack_mine/features/dashboard/driver_mode_page.dart';

void main() {
  /// A phone on its side: 360 high, the status bar taking some of it.
  Future<void> pumpDriverMode(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppStateProvider(
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: const MaterialApp(home: DriverModePage()),
        ),
      ),
    );
    await tester.pump();
  }

  for (final size in const [Size(780, 360), Size(640, 300), Size(900, 400)]) {
    testWidgets('disconnected on a ${size.width.toInt()}x'
        '${size.height.toInt()} landscape screen: one screen, no scrolling', (
      tester,
    ) async {
      await pumpDriverMode(tester, size);

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsNothing);
      // Everything at a glance: speed, time to the break, daily, weekly,
      // next rest and distance.
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.byIcon(Icons.bedtime_outlined), findsOneWidget);
      expect(find.byIcon(Icons.route_outlined), findsOneWidget);
      // The connection state sits in the header.
      expect(find.byIcon(Icons.bluetooth_disabled), findsOneWidget);
    });
  }

  testWidgets('a name the unit fills with question marks is not shown', (
    tester,
  ) async {
    await pumpDriverMode(tester, const Size(780, 360));
    final context = tester.element(find.byType(DriverModePage));
    AppStateProvider.of(
      context,
    ).setTachographLiveData(TachographLiveData(driver1Name: '?????????????'));
    await tester.pump();

    expect(find.textContaining('???'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
