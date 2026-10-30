import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/driving_time_calculator.dart';
import 'package:smarttrack_mine/core/services/violation_analyzer.dart';

DateTime _t(int day, int hour, [int minute = 0, int second = 0]) =>
    DateTime(2026, 10, day, hour, minute, second);

TachographActivity _a(ActivityType type, DateTime start, DateTime end) =>
    TachographActivity(type: type, startTime: start, endTime: end);

void main() {
  // The gap in the screenshot that prompted this: 17:04 one day to 11:31 the
  // next.
  final gap = ActivityGap(start: _t(11, 17, 4), end: _t(12, 11, 31));

  test('with no card records the whole gap is left for the driver', () {
    final coverage = GapCoverage.of(gap, const []);

    expect(coverage.covered, isEmpty);
    expect(coverage.holes, hasLength(1));
    expect(coverage.holes.single.start, gap.start);
    expect(coverage.holes.single.end, gap.end);
  });

  test('records covering the whole gap leave nothing to ask, clipped to it', () {
    final coverage = GapCoverage.of(gap, [
      _a(ActivityType.driving, _t(11, 15), _t(11, 19)),
      _a(ActivityType.rest, _t(11, 19), _t(12, 8)),
      _a(ActivityType.driving, _t(12, 8), _t(12, 13)),
    ]);

    expect(coverage.holes, isEmpty);
    expect(coverage.covered.map((a) => a.type), [
      ActivityType.driving,
      ActivityType.rest,
      ActivityType.driving,
    ]);
    expect(coverage.covered.first.startTime, gap.start);
    expect(coverage.covered.last.endTime, gap.end);
  });

  test('only the stretches without records are left, before and after', () {
    final coverage = GapCoverage.of(gap, [
      _a(ActivityType.rest, _t(11, 20), _t(12, 6)),
    ]);

    expect(coverage.covered, hasLength(1));
    expect(coverage.covered.single.type, ActivityType.rest);
    expect(coverage.holes, hasLength(2));
    expect(coverage.holes[0].start, gap.start);
    expect(coverage.holes[0].end, _t(11, 20));
    expect(coverage.holes[1].start, _t(12, 6));
    expect(coverage.holes[1].end, gap.end);
  });

  test('a hole between two records is left for the driver', () {
    final coverage = GapCoverage.of(gap, [
      _a(ActivityType.driving, _t(11, 17), _t(11, 21)),
      _a(ActivityType.rest, _t(11, 23), _t(12, 12)),
    ]);

    expect(coverage.holes, hasLength(1));
    expect(coverage.holes.single.start, _t(11, 21));
    expect(coverage.holes.single.end, _t(11, 23));
  });

  test('a record of unknown activity counts as no record', () {
    final coverage = GapCoverage.of(gap, [
      _a(ActivityType.unknown, _t(11, 17), _t(12, 12)),
    ]);

    expect(coverage.covered, isEmpty);
    expect(coverage.holes, hasLength(1));
  });

  test('overlapping records are not counted twice', () {
    final coverage = GapCoverage.of(gap, [
      _a(ActivityType.rest, _t(11, 17), _t(12, 9)),
      _a(ActivityType.rest, _t(11, 22), _t(12, 3)),
      _a(ActivityType.driving, _t(12, 8), _t(12, 12)),
    ]);

    expect(coverage.holes, isEmpty);
    expect(coverage.covered.map((a) => a.type), [
      ActivityType.rest,
      ActivityType.driving,
    ]);
    expect(coverage.covered[1].startTime, _t(12, 9));
    for (var i = 1; i < coverage.covered.length; i++) {
      expect(
        coverage.covered[i].startTime.isBefore(coverage.covered[i - 1].endTime),
        isFalse,
      );
    }
  });

  test('nothing after the download is taken from the file', () {
    // Downloaded at 21:30; the card ends that day's last activity at
    // midnight, which is not a record of what happened after 21:30.
    final coverage = GapCoverage.of(gap, [
      _a(ActivityType.driving, _t(11, 15), _t(11, 19)),
      _a(ActivityType.rest, _t(11, 19), _t(12, 0)),
    ], recordedUntil: _t(11, 21, 30));

    expect(coverage.covered.last.endTime, _t(11, 21, 30));
    expect(coverage.holes, hasLength(1));
    expect(coverage.holes.single.start, _t(11, 21, 30));
    expect(coverage.holes.single.end, gap.end);
  });

  test('a file downloaded before the gap tells nothing about it', () {
    final coverage = GapCoverage.of(gap, [
      _a(ActivityType.rest, _t(11, 12), _t(12, 0)),
    ], recordedUntil: _t(11, 16));

    expect(coverage.covered, isEmpty);
    expect(coverage.holes.single.start, gap.start);
    expect(coverage.holes.single.end, gap.end);
  });

  test('seconds lost to records kept in whole minutes are not a hole', () {
    final gapWithSeconds = ActivityGap(
      start: _t(11, 17, 4, 40),
      end: _t(11, 20, 30, 10),
    );
    final coverage = GapCoverage.of(gapWithSeconds, [
      _a(ActivityType.driving, _t(11, 17, 5), _t(11, 20, 30)),
    ]);

    expect(coverage.holes, isEmpty);
  });
}
