import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttrack_mine/core/providers/app_state.dart';
import 'package:smarttrack_mine/core/services/driving_time_calculator.dart';
import 'package:smarttrack_mine/core/widgets/gap_fill_dialog.dart';

/// Opens the dialog for the app's pending gap and hands the test the state.
Future<AppState> _openDialog(WidgetTester tester, Duration absence) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);

  late AppState appState;
  await tester.pumpWidget(
    AppStateProvider(
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            appState = AppStateProvider.of(context);
            return Scaffold(
              body: TextButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => GapFillDialog(gap: appState.pendingRealGap!),
                ),
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));

  // No card file, so the whole absence is left for the driver.
  await appState.simulateTestReconnect(simulateAbsence: absence);
  expect(appState.pendingRealGap, isNotNull);

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return appState;
}

/// Scrolls the dialog to [finder] first; its content is taller than a phone.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a gap split in two is saved as two activities back to back', (
    tester,
  ) async {
    final appState = await _openDialog(tester, const Duration(hours: 6));
    final gap = appState.pendingRealGap!;

    await _tap(tester, find.text('Aralığı böl'));
    expect(find.byType(ChoiceChip), findsNWidgets(8));

    await _tap(tester, find.widgetWithText(ChoiceChip, 'Sürüş').at(0));
    await _tap(tester, find.widgetWithText(ChoiceChip, 'Mola').at(1));
    await _tap(tester, find.text('Kaydet'));

    expect(find.byType(GapFillDialog), findsNothing);
    expect(appState.pendingRealGap, isNull);

    final manual = appState.liveOnlyActivityLog
        .where((a) => a.isManualEntry)
        .toList();
    expect(manual.map((a) => a.type), [
      ActivityType.driving,
      ActivityType.rest,
    ]);
    expect(manual.first.startTime, gap.start);
    expect(manual.first.endTime, manual.last.startTime);
    expect(manual.last.endTime, gap.end);
  });

  testWidgets('saving asks for an activity on every part first', (
    tester,
  ) async {
    final appState = await _openDialog(tester, const Duration(hours: 2));

    await _tap(tester, find.text('Aralığı böl'));
    await _tap(tester, find.widgetWithText(ChoiceChip, 'Çalışma').at(0));
    await _tap(tester, find.text('Kaydet'));

    expect(find.text('Her parça için bir aktivite seçin.'), findsOneWidget);
    expect(find.byType(GapFillDialog), findsOneWidget);
    expect(appState.pendingRealGap, isNotNull);
  });

  testWidgets('removing a part gives its time back to the part before it', (
    tester,
  ) async {
    final appState = await _openDialog(tester, const Duration(hours: 4));

    await _tap(tester, find.text('Aralığı böl'));
    await _tap(tester, find.byTooltip('Bu parçayı kaldır').at(1));
    expect(find.byType(ChoiceChip), findsNWidgets(4));

    await _tap(tester, find.widgetWithText(ChoiceChip, 'Hazır Bulunma'));
    await _tap(tester, find.text('Kaydet'));

    final manual = appState.liveOnlyActivityLog
        .where((a) => a.isManualEntry)
        .toList();
    expect(manual, hasLength(1));
    expect(manual.single.type, ActivityType.available);
  });
}
