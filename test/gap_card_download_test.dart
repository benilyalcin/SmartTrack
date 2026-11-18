import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttrack_mine/core/providers/app_state.dart';
import 'package:smarttrack_mine/core/services/link/link_scheduler.dart';

/// AppState with the activity store and the link scheduler behind it:
/// losing contact is not a question for the driver, it is card data to
/// fetch in the next quiet window.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState appState;
  late int downloads;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    downloads = 0;
    AppState.cardDownloader = (cancel, clock) async {
      downloads++;
      return DddDownloadOutcome(
        bytes: Uint8List(0),
        problem: 'no card',
        downloadedAt: clock.nowUtc(),
      );
    };
    appState = AppState();
    await pumpEventQueue();
  });

  tearDown(() => AppState.cardDownloader = null);

  test('losing contact asks the driver nothing and downloads nothing', () async {
    appState.setBluetoothConnected(true, deviceName: 'unit');
    appState.setLiveComplianceData(workingStateCode: 3);
    appState.setBluetoothConnected(false);
    await pumpEventQueue();

    appState.setBluetoothConnected(true, deviceName: 'unit');
    appState.checkForRealGap();
    await pumpEventQueue();

    expect(appState.pendingRealGap, isNull);
    expect(downloads, 0, reason: 'never while driving');
    expect(appState.activityData.scheduler.queue.hasCardJob, isTrue);
  });

  test('the card download waits for a quiet window', () async {
    appState.setBluetoothConnected(true, deviceName: 'unit');
    // Driving: no download.
    appState.setLiveComplianceData(workingStateCode: 3);
    await pumpEventQueue();
    expect(downloads, 0);

    // A break: the window is quiet, the queued card job runs.
    appState.setLiveComplianceData(workingStateCode: 0);
    await pumpEventQueue();
    expect(downloads, 1);
  });

  test('a gap no card download explains becomes a question', () async {
    await appState.simulateTestReconnect(
      simulateAbsence: const Duration(hours: 5),
    );
    await pumpEventQueue();

    final gap = appState.pendingRealGap!;
    expect(gap.duration.inMinutes, closeTo(300, 1));
  });
}
