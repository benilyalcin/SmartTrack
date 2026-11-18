import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/config/sync_config.dart';
import 'package:smarttrack_mine/core/models/activity_segment.dart';
import 'package:smarttrack_mine/core/services/activity_merge_engine.dart';
import 'package:smarttrack_mine/core/services/activity_store.dart';
import 'package:smarttrack_mine/core/services/driving_time_calculator.dart';

const d1 = 'driver1';
const engine = ActivityMergeEngine(SyncConfig.defaults);

DateTime z(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

TachographActivity rec(
  ActivityType type,
  DateTime start,
  DateTime end, {
  int counter = 1,
}) => TachographActivity(
  type: type,
  startTime: start,
  endTime: end,
  recordPresenceCounter: counter,
);

DddImport card(
  List<TachographActivity> records,
  DateTime downloadedAt, {
  String id = 'f1',
}) => DddImport(
  fileId: id,
  driverId: d1,
  records: records,
  downloadedAt: downloadedAt,
);

/// The view as "type start-end status", for readable comparisons.
List<String> show(ActivityStoreState s, DateTime now) => [
  for (final v in engine.view(s, d1, now))
    '${v.activityType.name} ${_hm(v.startUtc)}-'
        '${v.endUtc == null ? 'open' : _hm(v.endUtc!)} ${v.status.name}',
];

String _hm(DateTime t) =>
    '${t.day}/${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

ActivityStoreState live(
  ActivityStoreState s,
  ActivityType type,
  DateTime at, {
  DateTime? changedAt,
}) => engine.recordLive(
  s,
  driverId: d1,
  type: type,
  at: at,
  changedAt: changedAt,
);

void main() {
  const empty = ActivityStoreState();

  group('live data', () {
    test('a change closes the open segment and opens the next', () {
      var s = live(empty, ActivityType.driving, z(18, 6));
      s = live(s, ActivityType.driving, z(18, 7));
      s = live(s, ActivityType.rest, z(18, 8));
      expect(show(s, z(18, 9)), [
        'driving 18/06:00-18/08:00 provisional',
        'rest 18/08:00-open provisional',
      ]);
    });

    test('the unit\'s own start of the activity is used when known', () {
      var s = live(empty, ActivityType.driving, z(18, 6));
      s = live(s, ActivityType.rest, z(18, 8), changedAt: z(18, 7, 40));
      expect(show(s, z(18, 9)).first, 'driving 18/06:00-18/07:40 provisional');
    });
  });

  group('disconnect and reconnect', () {
    test('lost contact leaves a pending gap from the last sample', () {
      var s = live(empty, ActivityType.driving, z(18, 6));
      s = live(s, ActivityType.driving, z(18, 7));
      s = engine.markLinkDown(
        s,
        driverId: d1,
        at: z(18, 7, 10),
        reason: GapReason.disconnect,
      );
      expect(show(s, z(18, 8)), [
        'driving 18/06:00-18/07:00 provisional',
        'unknown 18/07:00-open pendingGap',
      ]);

      // Back at 09:00; the unit says rest began 08:20.
      s = live(s, ActivityType.rest, z(18, 9), changedAt: z(18, 8, 20));
      expect(show(s, z(18, 9, 30)), [
        'driving 18/06:00-18/07:00 provisional',
        'unknown 18/07:00-18/08:20 pendingGap',
        'rest 18/08:20-open provisional',
      ]);
    });

    test('the same activity all through the gap closes it', () {
      var s = live(empty, ActivityType.rest, z(18, 6));
      s = engine.markLinkDown(
        s,
        driverId: d1,
        at: z(18, 7),
        reason: GapReason.disconnect,
      );
      s = live(s, ActivityType.rest, z(18, 10), changedAt: z(18, 6));
      expect(show(s, z(18, 11)), ['rest 18/06:00-open provisional']);
    });

    test('a disconnect gap becomes a question only after the wait', () {
      var s = live(empty, ActivityType.work, z(18, 6));
      s = engine.markLinkDown(
        s,
        driverId: d1,
        at: z(18, 6),
        reason: GapReason.disconnect,
      );
      s = live(s, ActivityType.work, z(18, 9), changedAt: z(18, 8));

      expect(
        engine.classifyGaps(s, z(18, 20)),
        same(s),
        reason: 'not yet ${SyncConfig.defaults.manualEntryAfter}',
      );
      final later = engine.classifyGaps(s, z(19, 9));
      expect(show(later, z(19, 9)), [
        'unknown 18/06:00-18/08:00 needsManual',
        'work 18/08:00-open provisional',
      ]);
    });
  });

  group('card data wins over live data', () {
    test('live segments before the watermark are superseded and logged', () {
      var s = live(empty, ActivityType.driving, z(18, 6));
      s = live(s, ActivityType.rest, z(18, 8));
      s = live(s, ActivityType.work, z(18, 9));

      final out = engine.importDdd(
        s,
        card([
          rec(ActivityType.rest, z(18, 0), z(18, 6)),
          rec(ActivityType.driving, z(18, 6), z(18, 7, 30)),
          rec(ActivityType.rest, z(18, 7, 30), z(18, 9)),
          rec(ActivityType.work, z(18, 9), z(19, 0)),
        ], z(18, 10)),
        now: z(18, 10),
      );

      expect(out.changed, isTrue);
      expect(show(out.state, z(18, 10)), [
        'rest 18/00:00-18/06:00 confirmed',
        'driving 18/06:00-18/07:30 confirmed',
        'rest 18/07:30-18/09:00 confirmed',
        // After the watermark (the last change, 09:00): still live.
        'work 18/09:00-open provisional',
      ]);
      // Live said driving until 08:00; the card says rest from 07:30.
      final driving = out.newCorrections.firstWhere(
        (c) => c.supersededType == ActivityType.driving,
      );
      expect(driving.differingTime, const Duration(minutes: 30));
      expect(out.notify, isTrue);
      expect(out.state.syncOf(d1).dddWatermarkUtc, z(18, 9));
      // Superseded, not deleted.
      expect(
        out.state.segments.where((x) => x.isSuperseded).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('a segment across UTC midnight keeps its part after the card', () {
      var s = live(empty, ActivityType.driving, z(17, 22));
      s = live(s, ActivityType.rest, z(18, 2));

      final out = engine.importDdd(
        s,
        card([
          rec(ActivityType.driving, z(17, 21), z(18, 0)),
          rec(ActivityType.driving, z(18, 0), z(18, 1), counter: 2),
          rec(ActivityType.rest, z(18, 1), z(19, 0), counter: 2),
        ], z(18, 1, 30)),
        now: z(18, 3),
      );

      expect(show(out.state, z(18, 3)), [
        'driving 17/21:00-18/00:00 confirmed',
        'driving 18/00:00-18/01:00 confirmed',
        'driving 18/01:00-18/02:00 provisional',
        'rest 18/02:00-open provisional',
      ]);
    });

    test('the same file twice changes nothing', () {
      final file = card([
        rec(ActivityType.rest, z(18, 0), z(18, 6)),
        rec(ActivityType.driving, z(18, 6), z(19, 0)),
      ], z(18, 8));
      final once = engine.importDdd(
        live(empty, ActivityType.work, z(18, 5)),
        file,
        now: z(18, 8),
      );
      final twice = engine.importDdd(once.state, file, now: z(18, 9));

      expect(twice.changed, isFalse);
      expect(twice.newCorrections, isEmpty);
      expect(jsonEncode(twice.state.toJson()), jsonEncode(once.state.toJson()));
    });

    test('an older file never replaces a newer one', () {
      final newer = card(
        [
          rec(ActivityType.rest, z(18, 0), z(18, 6)),
          rec(ActivityType.driving, z(18, 6), z(18, 9)),
          rec(ActivityType.rest, z(18, 9), z(19, 0)),
        ],
        z(18, 10),
        id: 'new',
      );
      final older = card(
        [
          rec(ActivityType.rest, z(18, 0), z(18, 6)),
          rec(ActivityType.driving, z(18, 6), z(19, 0)),
        ],
        z(18, 7),
        id: 'old',
      );

      final a = engine.importDdd(empty, newer, now: z(18, 10)).state;
      final b = engine.importDdd(a, older, now: z(18, 11));
      expect(show(b.state, z(18, 11)), show(a, z(18, 11)));
      expect(b.state.syncOf(d1).dddWatermarkUtc, z(18, 9));
    });

    test('a newer file replaces the end of an older one', () {
      final older = card(
        [
          rec(ActivityType.rest, z(18, 0), z(18, 6)),
          rec(ActivityType.driving, z(18, 6), z(18, 8)),
          rec(ActivityType.work, z(18, 8), z(19, 0)),
        ],
        z(18, 8, 30),
        id: 'old',
      );
      final newer = card(
        [
          rec(ActivityType.rest, z(18, 0), z(18, 6)),
          rec(ActivityType.driving, z(18, 6), z(18, 8)),
          rec(ActivityType.work, z(18, 8), z(18, 9)),
          rec(ActivityType.rest, z(18, 9), z(19, 0)),
        ],
        z(18, 10),
        id: 'new',
      );

      final a = engine.importDdd(empty, older, now: z(18, 9)).state;
      final b = engine.importDdd(a, newer, now: z(18, 10)).state;
      expect(show(b, z(18, 10)), [
        'rest 18/00:00-18/06:00 confirmed',
        'driving 18/06:00-18/08:00 confirmed',
        'work 18/08:00-18/09:00 confirmed',
      ]);
    });
  });

  group('manual entries', () {
    test('a later card record supersedes a manual entry', () {
      var s = engine.addManual(
        empty,
        driverId: d1,
        type: ActivityType.work,
        start: z(18, 2),
        end: z(18, 5),
        now: z(18, 6),
      );
      expect(show(s, z(18, 6)), ['work 18/02:00-18/05:00 provisional']);

      final out = engine.importDdd(
        s,
        card([
          rec(ActivityType.rest, z(18, 0), z(18, 4)),
          rec(ActivityType.driving, z(18, 4), z(19, 0)),
        ], z(18, 7)),
        now: z(18, 7),
      );
      expect(show(out.state, z(18, 7)), [
        'rest 18/00:00-18/04:00 confirmed',
        // After the watermark (04:00, the last change) the entry stands.
        'work 18/04:00-18/05:00 provisional',
      ]);
      final c = out.newCorrections.single;
      expect(c.supersededSource, SegmentSource.manual);
      expect(c.differingTime, const Duration(hours: 2));
    });

    test('a manual entry stands where the card had no record', () {
      final imported = engine.importDdd(
        empty,
        card([
          rec(ActivityType.rest, z(18, 0), z(18, 4)),
          rec(ActivityType.unknown, z(18, 4), z(18, 8)),
          rec(ActivityType.driving, z(18, 8), z(19, 0)),
        ], z(18, 9)),
        now: z(18, 9),
      );
      expect(
        show(imported.state, z(18, 9))[1],
        'unknown 18/04:00-18/08:00 needsManual',
      );

      final filled = engine.addManual(
        imported.state,
        driverId: d1,
        type: ActivityType.work,
        start: z(18, 3),
        end: z(18, 8),
        now: z(18, 10),
      );
      // Not over the card's rest record; only the stretch it has nothing on.
      expect(show(filled, z(18, 10)), [
        'rest 18/00:00-18/04:00 confirmed',
        'work 18/04:00-18/08:00 provisional',
      ]);

      // Importing the same file again keeps the manual entry.
      final again = engine.importDdd(
        filled,
        card([
          rec(ActivityType.rest, z(18, 0), z(18, 4)),
          rec(ActivityType.unknown, z(18, 4), z(18, 8)),
          rec(ActivityType.driving, z(18, 8), z(19, 0)),
        ], z(18, 9)),
        now: z(18, 11),
      );
      expect(show(again.state, z(18, 11)), show(filled, z(18, 11)));
    });

    test('a manual entry fills a pending gap', () {
      var s = live(empty, ActivityType.rest, z(18, 1));
      s = engine.markLinkDown(
        s,
        driverId: d1,
        at: z(18, 2),
        reason: GapReason.disconnect,
      );
      s = live(s, ActivityType.work, z(18, 6), changedAt: z(18, 6));
      s = engine.addManual(
        s,
        driverId: d1,
        type: ActivityType.available,
        start: z(18, 3),
        end: z(18, 6),
        now: z(18, 7),
      );
      expect(show(s, z(18, 7)), [
        'unknown 18/01:00-18/03:00 pendingGap',
        'available 18/03:00-18/06:00 provisional',
        'work 18/06:00-open provisional',
      ]);
    });
  });

  group('gap left by a card download', () {
    test('stays pending, never a question, and the next card fills it', () {
      var s = live(empty, ActivityType.rest, z(18, 10));
      s = live(s, ActivityType.rest, z(18, 10, 55));
      s = engine.markLinkDown(
        s,
        driverId: d1,
        at: z(18, 11),
        reason: GapReason.dddMode,
      );
      s = live(s, ActivityType.driving, z(18, 11, 5), changedAt: z(18, 11, 5));
      s = live(s, ActivityType.rest, z(18, 13));
      expect(show(s, z(18, 14)), [
        'rest 18/10:00-18/10:55 provisional',
        'unknown 18/10:55-18/11:05 pendingGap',
        'driving 18/11:05-18/13:00 provisional',
        'rest 18/13:00-open provisional',
      ]);

      // Days later, still no card download: still pending.
      s = engine.classifyGaps(s, z(21, 0));
      expect(show(s, z(21, 0))[1], 'unknown 18/10:55-18/11:05 pendingGap');

      final out = engine.importDdd(
        s,
        card([
          rec(ActivityType.rest, z(18, 0), z(18, 10, 30)),
          rec(ActivityType.work, z(18, 10, 30), z(18, 11, 2)),
          rec(ActivityType.driving, z(18, 11, 2), z(18, 13)),
          rec(ActivityType.rest, z(18, 13), z(19, 0)),
        ], z(21, 1)),
        now: z(21, 1),
      );
      expect(show(out.state, z(21, 1)), [
        'rest 18/00:00-18/10:30 confirmed',
        'work 18/10:30-18/11:02 confirmed',
        'driving 18/11:02-18/13:00 confirmed',
        'rest 18/13:00-open provisional',
      ]);
    });

    test('with no change since, the activity under way fills it', () {
      var s = live(empty, ActivityType.rest, z(18, 10));
      s = live(s, ActivityType.rest, z(18, 10, 55));
      s = engine.markLinkDown(
        s,
        driverId: d1,
        at: z(18, 11),
        reason: GapReason.dddMode,
      );
      // Imported straight after the download, before live data is back.
      // The card's last change is the rest from 09:00.
      final out = engine.importDdd(
        s,
        card([
          rec(ActivityType.driving, z(18, 6), z(18, 9)),
          rec(ActivityType.rest, z(18, 9), z(19, 0)),
        ], z(18, 11, 8)),
        now: z(18, 11, 8),
      );
      expect(show(out.state, z(18, 11, 9)), [
        'driving 18/06:00-18/09:00 confirmed',
        'rest 18/10:00-18/10:55 provisional',
        'rest 18/10:55-18/11:08 provisional',
        'unknown 18/11:08-open pendingGap',
      ]);
      expect(
        engine
            .view(out.state, d1, z(18, 11, 9))
            .firstWhere((v) => v.startUtc == z(18, 10, 55))
            .source,
        SegmentSource.ddd,
      );
    });
  });

  test('activities hold card stretches without a record, not app gaps', () {
    var s = live(empty, ActivityType.rest, z(18, 1));
    s = live(s, ActivityType.rest, z(18, 1, 50));
    s = engine.markLinkDown(
      s,
      driverId: d1,
      at: z(18, 2),
      reason: GapReason.disconnect,
    );
    final list = engine.activities(s, d1, z(18, 3));
    expect(list.map((a) => a.type), [ActivityType.rest]);
  });
}
