import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/config/sync_config.dart';

void main() {
  test('a quiet window is never shorter than a card download', () {
    const config = SyncConfig(
      cardDownloadEstDuration: Duration(minutes: 7),
      quietSpeedZeroFor: Duration(minutes: 5),
    );
    expect(config.effectiveQuietSpeedZeroFor, const Duration(minutes: 7));
  });

  test('a longer configured stop is kept', () {
    const config = SyncConfig(
      cardDownloadEstDuration: Duration(minutes: 3),
      quietSpeedZeroFor: Duration(minutes: 10),
    );
    expect(config.effectiveQuietSpeedZeroFor, const Duration(minutes: 10));
  });

  test('vehicle unit downloads are off by default', () {
    expect(SyncConfig.defaults.vuDownloadEnabled, isFalse);
  });
}
