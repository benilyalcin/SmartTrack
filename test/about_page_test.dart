import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttrack_mine/core/localization/localization.dart';
import 'package:smarttrack_mine/core/providers/app_state.dart';
import 'package:smarttrack_mine/features/about/about_page.dart';

void main() {
  // A small phone with the system font enlarged, and a desktop width: the
  // page used to overflow on the first. Every language, since some run long.
  for (final (width, scale) in const [(320.0, 1.3), (1200.0, 1.0)]) {
    for (final lang in AppLocalizations.languages) {
      testWidgets('no overflow at $width px, text x$scale, $lang', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({'selectedLanguage': lang});
        tester.view.physicalSize = Size(width, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          AppStateProvider(
            child: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 2400),
                textScaler: TextScaler.linear(scale),
              ),
              child: const MaterialApp(home: AboutPage()),
            ),
          ),
        );
        // The road scenes keep moving, so the page never settles: step the
        // clock past every one-off animation instead.
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 800));
        }

        expect(tester.takeException(), isNull);
        expect(find.text('Aselsan STC-8255'), findsOneWidget);
        // The figures count up and land on the real value.
        expect(find.text('100.000+'), findsOneWidget);
        expect(find.text('300+'), findsOneWidget);
      });
    }
  }
}
