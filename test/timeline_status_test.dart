import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarttrack_mine/core/models/activity_segment.dart';
import 'package:smarttrack_mine/core/providers/app_state.dart';
import 'package:smarttrack_mine/core/services/activity_store.dart';
import 'package:smarttrack_mine/core/services/driving_time_calculator.dart';
import 'package:smarttrack_mine/core/services/link/link_gate.dart';
import 'package:smarttrack_mine/core/services/time/display_time.dart';
import 'package:smarttrack_mine/features/timeline/timeline_page.dart';

const display = DisplayTime(Duration(hours: 3));

ActivitySegment seg(
  String id,
  DateTime start,
  DateTime end,
  ActivityType type,
  SegmentSource source,
  SegmentStatus status,
) => ActivitySegment(
  id: id,
  driverId: 'driver1',
  startUtc: start,
  endUtc: end,
  activityType: type,
  source: source,
  status: status,
  createdAt: end,
);

Future<void> pumpTimeline(WidgetTester tester, List<ActivitySegment> s) async {
  SharedPreferences.setMockInitialValues({
    ActivityStore.stateKey: jsonEncode(
      ActivityStoreState(segments: s).toJson(),
    ),
  });
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AppStateProvider(child: const MaterialApp(home: TimelinePage())),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump();
}

void main() {
  // Yesterday in the display zone, so all of it is in the past.
  final today = display.displayDay(DateTime.now());
  final yesterday = display.dayRangeUtc(
    DateTime.utc(today.year, today.month, today.day - 1),
  );
  DateTime at(int minutes) => yesterday.start.add(Duration(minutes: minutes));

  testWidgets('the day and the times are local; statuses have their labels', (
    tester,
  ) async {
    await pumpTimeline(tester, [
      // 00:30-02:00 local is the UTC day before: still on this local day.
      seg(
        'ddd:1',
        at(30),
        at(120),
        ActivityType.rest,
        SegmentSource.ddd,
        SegmentStatus.confirmed,
      ),
      seg(
        'gap:1',
        at(120),
        at(180),
        ActivityType.unknown,
        SegmentSource.live,
        SegmentStatus.pendingGap,
      ),
      seg(
        'live:1',
        at(180),
        at(240),
        ActivityType.driving,
        SegmentSource.live,
        SegmentStatus.provisional,
      ),
    ]);
    await tester.tap(find.text('Önceki'));
    await tester.pump();

    expect(find.text('00:30 - 02:00'), findsOneWidget);
    expect(find.text('02:00 - 03:00'), findsOneWidget);
    expect(find.text('DDD bekleniyor'), findsWidgets);
    expect(find.text('03:00 - 04:00'), findsOneWidget);
    expect(find.byIcon(Icons.sensors), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a card download shows "verifying" with the last known data', (
    tester,
  ) async {
    await pumpTimeline(tester, const []);
    final release = Completer<void>();
    final download = LinkGate.instance.runDdd(() => release.future);
    await tester.pump();
    expect(find.text('Takograf verisi doğrulanıyor'), findsOneWidget);

    release.complete();
    await tester.runAsync(() => download);
    await tester.pump();
    expect(find.text('Takograf verisi doğrulanıyor'), findsNothing);
  });
}
