import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttrack_mine/core/providers/app_state.dart';
import 'package:smarttrack_mine/features/analysis/analysis_page.dart';

/// Hosts the analysis page under a key that the test can change, which
/// disposes the page and builds a fresh one, as a route rebuild does.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int generation = 0;

  void replacePage() => setState(() => generation++);

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: ValueKey(generation), child: const AnalysisPage());
}

void main() {
  testWidgets(
    'the penalties sheet keeps working after the page under it is rebuilt',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const AppStateProvider(child: MaterialApp(home: _Host())),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final button = find.text('Cezalar ve Ciddiyetleri');
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Sürüş süreleri'), findsOneWidget);

      // Dispose the page under the open sheet, then make the sheet rebuild
      // (a screen size change rebuilds every route).
      tester.state<_HostState>(find.byType(_Host)).replacePage();
      await tester.pump();
      tester.view.physicalSize = const Size(1080, 2300);
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Sürüş süreleri'), findsOneWidget);
    },
  );
}
