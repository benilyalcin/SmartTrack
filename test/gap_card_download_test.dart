import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttrack_mine/core/providers/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState appState;
  late int downloads;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    appState = AppState();
    await pumpEventQueue();
    downloads = 0;
  });

  tearDown(() => AppState.cardDownloader = null);

  test('a long gap asks the unit for its card before asking the driver', () async {
    AppState.cardDownloader = () async {
      downloads++;
      expect(appState.pendingRealGap, isNull);
      return null;
    };

    await appState.simulateTestReconnect(
      simulateAbsence: const Duration(hours: 5),
    );
    await pumpEventQueue();

    expect(downloads, 1);
    // No card came back and there was no card file, so all of it is asked.
    final gap = appState.pendingRealGap!;
    expect(gap.duration.inMinutes, closeTo(300, 1));
  });

  test('a failed card download still leaves the gap for the driver', () async {
    AppState.cardDownloader = () async {
      downloads++;
      throw StateError('kanal açılamadı');
    };

    await appState.simulateTestReconnect(
      simulateAbsence: const Duration(hours: 2),
    );
    await pumpEventQueue();

    expect(downloads, 1);
    expect(appState.pendingRealGap, isNotNull);
  });

  test('a short drop downloads nothing and asks nothing', () async {
    AppState.cardDownloader = () async {
      downloads++;
      return null;
    };

    await appState.simulateTestReconnect(
      simulateAbsence: const Duration(minutes: 10),
    );
    await pumpEventQueue();

    expect(downloads, 0);
    expect(appState.pendingRealGap, isNull);
  });
}
