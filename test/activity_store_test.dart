import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/config/sync_config.dart';
import 'package:smarttrack_mine/core/models/activity_segment.dart';
import 'package:smarttrack_mine/core/services/activity_store.dart';
import 'package:smarttrack_mine/core/services/driving_time_calculator.dart';

DateTime _z(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

void main() {
  final segment = ActivitySegment(
    id: 'live:driver1:1',
    driverId: 'driver1',
    startUtc: _z(18, 6),
    endUtc: null,
    activityType: ActivityType.driving,
    source: SegmentSource.live,
    status: SegmentStatus.provisional,
    createdAt: _z(18, 6),
    slot: DriverSlot.coDriver,
    isCrew: true,
  );

  test('segments, sync states and corrections survive a reload', () async {
    final backend = MemoryStoreBackend();
    final store = ActivityStore(backend: backend);
    await store.replace(
      ActivityStoreState(
        segments: [segment],
        syncStates: {
          'driver1': SyncState(
            driverId: 'driver1',
            dddWatermarkUtc: _z(18, 5),
            lastDddDownloadAt: _z(18, 5, 30),
          ),
        },
        corrections: [
          CorrectionLogEntry(
            at: _z(18, 7),
            supersededId: 'live:driver1:0',
            supersededSource: SegmentSource.live,
            supersededType: ActivityType.work,
            startUtc: _z(18, 4),
            endUtc: _z(18, 5),
            dddSegmentIds: ['ddd:driver1:9'],
            differingTime: const Duration(minutes: 20),
          ),
        ],
      ),
    );

    final reloaded = ActivityStore(backend: backend);
    await reloaded.load();
    expect(reloaded.hadStoredState, isTrue);
    final s = reloaded.state.segments.single;
    expect(s.id, segment.id);
    expect(s.endUtc, isNull);
    expect(s.startUtc.isUtc, isTrue);
    expect(s.slot, DriverSlot.coDriver);
    expect(s.isCrew, isTrue);
    expect(reloaded.state.syncOf('driver1').dddWatermarkUtc, _z(18, 5));
    expect(reloaded.state.syncOf('driver2').dddWatermarkUtc, isNull);
    expect(
      reloaded.state.corrections.single.differingTime,
      const Duration(minutes: 20),
    );
  });

  test('superseded segments are kept but not active', () {
    final state = ActivityStoreState(
      segments: [
        segment,
        segment.copyWith(id: 'x', supersededBy: 'ddd:1'),
      ],
    );
    expect(state.segments, hasLength(2));
    expect(state.activeFor('driver1').map((s) => s.id), ['live:driver1:1']);
  });

  test('speed samples are kept for the retention period only', () async {
    final backend = MemoryStoreBackend();
    final store = ActivityStore(
      backend: backend,
      config: const SyncConfig(speedRetention: Duration(hours: 48)),
    );
    await store.addSpeedSample(SpeedSample(tsUtc: _z(15, 0), kmh: 80));
    await store.addSpeedSample(SpeedSample(tsUtc: _z(16, 12), kmh: 50));
    await store.addSpeedSample(SpeedSample(tsUtc: _z(18, 6), kmh: 0));

    expect(store.speedSamples.map((s) => s.kmh), [50, 0]);
    expect(store.lastSpeedAt(_z(17, 0))?.kmh, 50);

    final reloaded = ActivityStore(backend: backend);
    await reloaded.load();
    expect(reloaded.speedSamples.map((s) => s.kmh), [50, 0]);
  });
}
