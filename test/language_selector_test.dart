import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/localization/localization.dart';
import 'package:smarttrack_mine/features/settings/widgets/language_selector.dart';

void main() {
  testWidgets(
    'holds the current locale during a drag and commits once at rest',
    (tester) async {
      final harness = await _pumpSelector(tester);
      final gesture = await _startDrag(tester, const Offset(-104, 0));
      await tester.pump(const Duration(milliseconds: 300));

      expect(harness.currentState!.changes, isEmpty);
      expect(harness.currentState!.language, 'TR');

      await gesture.up();
      await tester.pumpAndSettle();

      expect(harness.currentState!.language, 'EN');
      expect(harness.currentState!.changes, ['EN']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a drag can reverse direction and wrap before committing', (
    tester,
  ) async {
    final harness = await _pumpSelector(tester);
    final gesture = await _startDrag(tester, const Offset(-104, 0));
    await tester.pump(const Duration(milliseconds: 32));
    await gesture.moveBy(const Offset(208, 0));
    await tester.pump(const Duration(milliseconds: 300));

    expect(harness.currentState!.changes, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(harness.currentState!.language, AppLocalizations.languages.last);
    expect(harness.currentState!.changes, [AppLocalizations.languages.last]);

    await _swipeOneLanguage(tester, const Offset(-104, 0));
    expect(harness.currentState!.language, 'TR');
    expect(harness.currentState!.changes, [
      AppLocalizations.languages.last,
      'TR',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizing keeps the selected language centered and usable', (
    tester,
  ) async {
    final harness = await _pumpSelector(tester, language: 'DE');
    final selector = find.byType(LanguageSelector);
    final selectedLabel = find
        .ancestor(
          of: find.text(AppLocalizations.languageNames['DE']!),
          matching: find.byType(Row),
        )
        .first;

    // Measure the flag and text together: fitting the complete label on a
    // narrower control can legitimately change the text's individual offset.
    final offsetBefore =
        tester.getCenter(selectedLabel).dx - tester.getCenter(selector).dx;

    harness.currentState!.setWidth(240);
    await tester.pumpAndSettle();

    final offsetAfter =
        tester.getCenter(selectedLabel).dx - tester.getCenter(selector).dx;
    expect(offsetAfter, closeTo(offsetBefore, 1));
    expect(harness.currentState!.language, 'DE');
    expect(harness.currentState!.changes, isEmpty);

    await _swipeOneLanguage(tester, const Offset(-104, 0));
    expect(harness.currentState!.language, 'RU');
    expect(harness.currentState!.changes, ['RU']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the latest external language wins over a pending gesture', (
    tester,
  ) async {
    final harness = await _pumpSelector(tester);
    final gesture = await _startDrag(tester, const Offset(-104, 0));
    await tester.pump(const Duration(milliseconds: 32));

    harness.currentState!.setLanguage('DE');
    await tester.pump();
    harness.currentState!.setLanguage('PL');
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(harness.currentState!.language, 'PL');
    expect(harness.currentState!.changes, isEmpty);

    await _swipeOneLanguage(tester, const Offset(-104, 0));
    expect(harness.currentState!.language, 'RO');
    expect(harness.currentState!.changes, ['RO']);
    expect(tester.takeException(), isNull);
  });
}

Future<GlobalKey<_SelectorHarnessState>> _pumpSelector(
  WidgetTester tester, {
  String language = 'TR',
}) async {
  final key = GlobalKey<_SelectorHarnessState>();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: _SelectorHarness(key: key, initialLanguage: language),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

Future<void> _swipeOneLanguage(WidgetTester tester, Offset offset) async {
  final gesture = await _startDrag(tester, offset);
  // Let pointer velocity expire so the assertion covers snapping one step,
  // independently of platform-specific fling friction.
  await tester.pump(const Duration(milliseconds: 300));
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<TestGesture> _startDrag(WidgetTester tester, Offset offset) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(LanguageSelector)),
  );
  // Native scrolling accepts the gesture after touch slop. Move again after
  // acceptance so the requested travel reaches the scroll position.
  await gesture.moveBy(Offset(offset.dx.sign * 24, 0));
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.moveBy(offset);
  await tester.pump(const Duration(milliseconds: 16));
  return gesture;
}

class _SelectorHarness extends StatefulWidget {
  const _SelectorHarness({super.key, required this.initialLanguage});

  final String initialLanguage;

  @override
  State<_SelectorHarness> createState() => _SelectorHarnessState();
}

class _SelectorHarnessState extends State<_SelectorHarness> {
  late String language;
  double width = 320;
  final changes = <String>[];

  @override
  void initState() {
    super.initState();
    language = widget.initialLanguage;
  }

  void setLanguage(String value) => setState(() => language = value);

  void setWidth(double value) => setState(() => width = value);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: LanguageSelector(
      selectedLanguage: language,
      onChanged: (value) {
        changes.add(value);
        setState(() => language = value);
      },
    ),
  );
}
