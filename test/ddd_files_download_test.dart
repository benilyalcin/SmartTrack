import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttrack_mine/core/models/tachograph_type.dart';
import 'package:smarttrack_mine/core/providers/app_state.dart';
import 'package:smarttrack_mine/features/ddd_files/ddd_files_page.dart';

/// The files screen keeps an animation running, so it never settles: step
/// the clock past the sheet and dialog transitions instead.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  Future<void> pumpFilesPage(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const AppStateProvider(child: MaterialApp(home: DddFilesPage())),
    );
    await tester.pump();
    AppStateProvider.of(
      tester.element(find.byType(DddFilesPage)),
    ).setTachographType(TachographType.stc8255);
    await tester.pump();
  }

  testWidgets('STC download offers the vehicle unit blocks and the card', (
    tester,
  ) async {
    await pumpFilesPage(tester);

    await tester.tap(find.text('.ddd Verisi Al'));
    await settle(tester);

    expect(find.text('.ddd verisi indir'), findsOneWidget);
    expect(find.text('Araç ünitesi (takograf)'), findsOneWidget);
    expect(find.text('Sürücü kartı'), findsOneWidget);
    expect(find.text('Aktivite verisi'), findsOneWidget);
    expect(find.text('Son 30 gün'), findsOneWidget);
    expect(find.text('Olaylar ve arızalar'), findsOneWidget);
    expect(find.text('Detaylı hız'), findsOneWidget);
    expect(find.text('Teknik veri'), findsOneWidget);

    // The blocks belong to the vehicle unit: they go when it is unticked.
    await tester.tap(find.text('Araç ünitesi (takograf)'));
    await tester.pump();
    expect(find.text('Olaylar ve arızalar'), findsNothing);

    // With neither the unit nor the card there is nothing to download.
    await tester.tap(find.text('Sürücü kartı'));
    await tester.pump();
    final download = find.widgetWithText(FilledButton, 'İndir');
    expect(tester.widget<FilledButton>(download).onPressed, isNull);

    // The activity range has its own chooser.
    await tester.tap(find.text('Araç ünitesi (takograf)'));
    await tester.pump();
    await tester.tap(find.text('Aktivite verisi'));
    await settle(tester);
    expect(find.text('Son 7 gün'), findsOneWidget);
    await tester.tap(find.text('Son 7 gün'));
    await settle(tester);
    expect(find.text('Son 7 gün'), findsOneWidget);
    expect(find.text('Son 30 gün'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
