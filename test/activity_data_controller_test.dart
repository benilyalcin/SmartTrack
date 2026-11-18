import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/models/activity_segment.dart';
import 'package:smarttrack_mine/core/services/activity_data_controller.dart';
import 'package:smarttrack_mine/core/services/activity_store.dart';
import 'package:smarttrack_mine/core/services/driving_time_calculator.dart';
import 'package:smarttrack_mine/core/services/link/link_gate.dart';
import 'package:smarttrack_mine/core/services/link/link_scheduler.dart';
import 'package:smarttrack_mine/core/services/time/tacho_clock.dart';

void main() {
  final now = DateTime.utc(2026, 11, 18, 12);

  ActivityDataController controller() => ActivityDataController(
    clock: TachoClock(phoneNow: () => now),
    store: ActivityStore(backend: MemoryStoreBackend()),
    gate: LinkGate(),
    downloadCard: (_) async =>
        DddDownloadOutcome(bytes: Uint8List(0), downloadedAt: now),
    onCardData: (_) async {},
  );

  /// A card day [daysAgo] back: rest, the card out 08:00-12:00, driving.
  List<TachographActivity> cardDay(int daysAgo) {
    final d = DateTime.utc(now.year, now.month, now.day - daysAgo);
    TachographActivity a(ActivityType t, int from, int to) =>
        TachographActivity(
          type: t,
          startTime: d.add(Duration(hours: from)),
          endTime: d.add(Duration(hours: to)),
          recordPresenceCounter: 1,
        );
    return [
      a(ActivityType.rest, 0, 8),
      a(ActivityType.unknown, 8, 12),
      a(ActivityType.driving, 12, 24),
    ];
  }

  test('a stretch without a record older than the lookback stays on the '
      'timeline but is not asked about', () {
    final c = controller();
    c.importCard(
      fileId: 'f',
      records: [...cardDay(10), ...cardDay(2), ...cardDay(1)],
      downloadedAt: now,
    );

    final unrecorded = c
        .view('driver1')
        .where((s) => s.status == SegmentStatus.needsManual)
        .map((s) => s.startUtc.day)
        .toSet();
    // Still shown (purple) on the timeline, 10 days back included...
    expect(unrecorded, containsAll([now.day - 10, now.day - 2, now.day - 1]));
    // ...but only the ones that ended within 7 days are questions: not
    // the card-out stretch 10 days back. (The whole days without a record
    // between the card days are questions too, when recent.)
    final asked = c.questions('driver1').map((g) => g.start.day).toSet();
    expect(asked, isNot(contains(now.day - 10)));
    expect(asked, containsAll([now.day - 2, now.day - 1]));
    expect(
      c
          .questions('driver1')
          .every((g) => g.end.isAfter(now.subtract(const Duration(days: 7)))),
      isTrue,
    );
    c.dispose();
  });
}
