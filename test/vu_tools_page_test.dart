import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttrack_mine/core/localization/localization.dart';
import 'package:smarttrack_mine/core/models/tachograph_type.dart';
import 'package:smarttrack_mine/core/providers/app_state.dart';
import 'package:smarttrack_mine/core/services/its/appendix7.dart';
import 'package:smarttrack_mine/core/services/its/download_generation_setting.dart';
import 'package:smarttrack_mine/features/ddd_files/ddd_files_page.dart';
import 'package:smarttrack_mine/features/its_advanced/its_advanced_page.dart';
import 'package:smarttrack_mine/features/its_download/its_download_page.dart';
import 'package:smarttrack_mine/features/rhmi/rhmi_page.dart';
import 'package:smarttrack_mine/features/vu_tools/vu_tools_page.dart';

String _t(String key) => AppLocalizations.getText('EN', key);

Finder _downloadChip(String key) => find.ancestor(
  of: find.descendant(
    of: find.byType(ItsDownloadPage),
    matching: find.text(_t(key)),
  ),
  matching: find.byType(FilterChip),
);

class _StoredToolsHarness extends StatefulWidget {
  const _StoredToolsHarness({super.key, required this.bucket});

  final PageStorageBucket bucket;

  @override
  State<_StoredToolsHarness> createState() => _StoredToolsHarnessState();
}

class _StoredToolsHarnessState extends State<_StoredToolsHarness> {
  bool visible = true;

  void showTools(bool value) => setState(() => visible = value);

  @override
  Widget build(BuildContext context) => PageStorage(
    bucket: widget.bucket,
    child: visible
        ? const VuToolsPage()
        : const SizedBox(key: PageStorageKey('its-tools')),
  );
}

void main() {
  late String previousLanguage;

  setUp(() {
    previousLanguage = AppLocalizations.current;
    DownloadGenerationSetting.value.value =
        DownloadGenerationSetting.recommended;
  });

  tearDown(() {
    AppLocalizations.current = previousLanguage;
  });

  Future<void> pumpToolsPage(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const AppStateProvider(child: MaterialApp(home: VuToolsPage())),
    );
  }

  Future<void> pumpAtcPage(WidgetTester tester, {GoRouter? router}) async {
    SharedPreferences.setMockInitialValues({'selectedLanguage': 'EN'});
    AppLocalizations.current = 'EN';
    await tester.pumpWidget(
      AppStateProvider(
        child: router == null
            ? const MaterialApp(home: Scaffold(body: VuToolsPage()))
            : MaterialApp.router(routerConfig: router),
      ),
    );
    // Before a type is selected the files view has a repeating warning
    // animation; switch to ATC before waiting for animations to finish.
    await tester.pump();
    AppStateProvider.of(
      tester.element(find.byType(VuToolsPage)),
    ).setTachographType(TachographType.atc8256);
    await tester.pumpAndSettle();
  }

  testWidgets('STC 8255 opens downloaded files from the ITS tab', (
    tester,
  ) async {
    await pumpToolsPage(tester);
    AppStateProvider.of(
      tester.element(find.byType(VuToolsPage)),
    ).setTachographType(TachographType.stc8255);
    await tester.pump();

    expect(find.byType(DddFilesPage), findsOneWidget);
    expect(find.text('İndirilen dosyalar'), findsNothing);
  });

  testWidgets('ATC tools and remote controls share one scroll at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpAtcPage(tester);

    expect(find.byType(DddFilesPage), findsNothing);
    expect(find.byType(RhmiPage), findsOneWidget);
    expect(find.byType(ItsDownloadPage), findsOneWidget);
    expect(find.byType(ItsAdvancedPage), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(Scrollable), findsOneWidget);
    for (final key in [
      'its.toolRhmiTitle',
      'its.toolDownloadTitle',
      'its.toolAdvancedTitle',
      'rhmi.ui.secPairing',
      'rhmi.ui.secLive',
      'rhmi.ui.secWarnings',
      'rhmi.ui.secPrintout',
      'rhmi.ui.secWithdraw',
      'rhmi.ui.secManual',
    ]) {
      expect(find.text(_t(key)), findsOneWidget);
    }

    final liveEntries = find.text(_t('rhmi.ui.secLive'));
    await tester.ensureVisible(liveEntries);
    await tester.tap(liveEntries);
    await tester.pumpAndSettle();
    for (final key in [
      'rhmi.ui.rest',
      'rhmi.ui.placeLabel',
      'rhmi.ui.ferryBegin',
      'rhmi.ui.oosBegin',
      'rhmi.ui.load',
    ]) {
      expect(
        find.descendant(
          of: find.byType(RhmiPage),
          matching: find.text(_t(key)),
        ),
        findsOneWidget,
      );
    }

    final generation = find.text(_t('its.advGenerationTitle'));
    await tester.ensureVisible(generation);
    await tester.pumpAndSettle();
    expect(generation.hitTestable(), findsOneWidget);
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('download selection and dates survive scrolling to advanced', (
    tester,
  ) async {
    await pumpAtcPage(tester);
    final downloadState = tester.state(find.byType(ItsDownloadPage));
    final activities = _downloadChip('its.transferActivities');
    await tester.ensureVisible(activities);
    if (!tester.widget<FilterChip>(activities).selected) {
      await tester.tap(activities);
      await tester.pumpAndSettle();
    }

    final startDate = find.textContaining(RegExp(r'^Start \d{4}-\d{2}-\d{2}$'));
    await tester.ensureVisible(startDate);
    await tester.tap(startDate);
    await tester.pumpAndSettle();
    final dialog = find.byType(DatePickerDialog);
    final material = MaterialLocalizations.of(tester.element(dialog));
    await tester.tap(find.byTooltip(material.inputDateModeButtonLabel));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)),
      '02/03/2001',
    );
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextButton, material.okButtonLabel),
      ),
    );
    await tester.pumpAndSettle();

    final chosenDate = find.text(
      _t('its.fromDate').replaceAll('{date}', '2001-02-03'),
    );
    expect(chosenDate, findsOneWidget);
    await tester.ensureVisible(find.text(_t('its.advGenerationTitle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(chosenDate);
    await tester.pumpAndSettle();

    expect(tester.widget<FilterChip>(activities).selected, isTrue);
    expect(chosenDate.hitTestable(), findsOneWidget);
    expect(tester.state(find.byType(ItsDownloadPage)), same(downloadState));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'generation changes apply without leaving or resetting download',
    (tester) async {
      await pumpAtcPage(tester);
      final downloadState = tester.state(find.byType(ItsDownloadPage));
      final activities = _downloadChip('its.transferActivities');
      await tester.ensureVisible(activities);
      if (!tester.widget<FilterChip>(activities).selected) {
        await tester.tap(activities);
        await tester.pumpAndSettle();
      }

      await tester.ensureVisible(find.text('Gen 1'));
      await tester.tap(find.text('Gen 1'));
      await tester.pumpAndSettle();
      expect(DownloadGenerationSetting.value.value, DownloadGeneration.gen1);
      expect(find.text(_t('its.advNotRecommended')), findsOneWidget);
      expect(
        find.text(
          _t(
            'its.trtpNote',
          ).replaceAll('{overview}', '0x01').replaceAll('{activities}', '0x02'),
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(activities);
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(activities).selected, isTrue);
      expect(find.text(_t('its.activitiesCard')), findsOneWidget);
      expect(tester.state(find.byType(ItsDownloadPage)), same(downloadState));
      expect(find.byType(Scrollable), findsOneWidget);

      await tester.ensureVisible(find.text('Gen 2 v2'));
      await tester.tap(find.text('Gen 2 v2'));
      await tester.pumpAndSettle();
      expect(
        DownloadGenerationSetting.value.value,
        DownloadGenerationSetting.recommended,
      );
      expect(find.text(_t('its.advRecommended')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('calibration remains reachable from the unified ITS page', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/vu',
      routes: [
        GoRoute(
          path: '/vu',
          builder: (context, state) => const Scaffold(body: VuToolsPage()),
        ),
        GoRoute(
          path: '/vu/calibration',
          builder: (context, state) =>
              const Scaffold(body: Text('Calibration destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpAtcPage(tester, router: router);

    final calibration = find.text(_t('its.calibrationTitle'));
    await tester.ensureVisible(calibration);
    await tester.tap(calibration);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/vu/calibration');
    expect(find.text('Calibration destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scroll and section states restore independently on return', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'selectedLanguage': 'EN'});
    AppLocalizations.current = 'EN';
    final harness = GlobalKey<_StoredToolsHarnessState>();
    await tester.pumpWidget(
      AppStateProvider(
        child: MaterialApp(
          home: Scaffold(
            body: _StoredToolsHarness(
              key: harness,
              bucket: PageStorageBucket(),
            ),
          ),
        ),
      ),
    );
    AppStateProvider.of(
      tester.element(find.byType(VuToolsPage)),
    ).setTachographType(TachographType.atc8256);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(_t('rhmi.ui.secPairing')));
    await tester.tap(find.text(_t('rhmi.ui.secPairing')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(_t('rhmi.ui.secLive')));
    await tester.tap(find.text(_t('rhmi.ui.secLive')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(_t('its.advGenerationTitle')));
    await tester.pumpAndSettle();
    final scrollOffset = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position
        .pixels;
    expect(scrollOffset, greaterThan(0));

    harness.currentState!.showTools(false);
    await tester.pumpAndSettle();
    harness.currentState!.showTools(true);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      closeTo(scrollOffset, 1),
    );
    expect(find.text(_t('rhmi.ui.pair')), findsNothing);
    expect(find.text(_t('rhmi.ui.rest')), findsOneWidget);
  });

  testWidgets('legacy shared storage values do not break the ITS page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'selectedLanguage': 'EN'});
    AppLocalizations.current = 'EN';
    final bucket = PageStorageBucket();
    final harness = GlobalKey<_StoredToolsHarnessState>();
    await tester.pumpWidget(
      AppStateProvider(
        child: MaterialApp(
          home: Scaffold(
            body: _StoredToolsHarness(key: harness, bucket: bucket),
          ),
        ),
      ),
    );
    AppStateProvider.of(
      tester.element(find.byType(VuToolsPage)),
    ).setTachographType(TachographType.atc8256);
    await tester.pumpAndSettle();

    for (final oldValue in <Object>[true, 120.0]) {
      harness.currentState!.showTools(false);
      await tester.pumpAndSettle();
      bucket.writeState(
        tester.element(find.byKey(const PageStorageKey('its-tools'))),
        oldValue,
      );
      harness.currentState!.showTools(true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(RhmiPage), findsOneWidget);
    }
  });
}
