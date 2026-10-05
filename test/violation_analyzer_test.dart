import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/driving_time_calculator.dart';
import 'package:smarttrack_mine/core/services/violation_analyzer.dart';

const _drive = ActivityType.driving;
const _rest = ActivityType.rest;
const _work = ActivityType.work;

Duration _h(int hours, [int minutes = 0]) =>
    Duration(hours: hours, minutes: minutes);

/// Back-to-back activities starting at [start].
List<TachographActivity> _seq(
  DateTime start,
  List<(ActivityType, Duration)> parts,
) {
  var t = start;
  final out = <TachographActivity>[];
  for (final (type, d) in parts) {
    out.add(TachographActivity(type: type, startTime: t, endTime: t.add(d)));
    t = t.add(d);
  }
  return out;
}

/// [cycle] repeated [times] times.
List<(ActivityType, Duration)> _repeat(
  List<(ActivityType, Duration)> cycle,
  int times,
) => [for (var i = 0; i < times; i++) ...cycle];

List<Violation> _ofType(List<Violation> all, ViolationType type) =>
    all.where((v) => v.type == type).toList();

DateTime _end(List<TachographActivity> acts) => acts.last.endTime;

void main() {
  final analyzer = ViolationAnalyzer();
  final monday = DateTime(2026, 1, 5, 6);

  group('daily rest (Art. 8.2)', () {
    test('a 45-minute break is not a daily rest violation', () {
      final acts = _seq(monday, [
        (_drive, _h(4)),
        (_rest, _h(0, 45)),
        (_drive, _h(4)),
        (_work, _h(1)),
        (_rest, _h(11)),
        (_drive, _h(4)),
        (_rest, _h(0, 45)),
        (_drive, _h(4)),
        (_rest, _h(11)),
      ]);
      final violations = analyzer.analyze(acts, _end(acts));
      expect(violations, isEmpty);
    });

    test('a 6h rest in the 24h period is a very serious violation', () {
      final acts = _seq(monday, [
        (_drive, _h(4)),
        (_rest, _h(0, 45)),
        (_drive, _h(4)),
        (_work, _h(8, 15)),
        (_rest, _h(6)), // Mon 23:00 – Tue 05:00
        (_drive, _h(4)),
        (_rest, _h(12)),
      ]);
      final rest = _ofType(
        analyzer.analyze(acts, _end(acts)),
        ViolationType.dailyRestInsufficient,
      );
      expect(rest, hasLength(1));
      expect(rest.single.start, DateTime(2026, 1, 5, 23));
      expect(rest.single.excessDuration, _h(3));
      expect(rest.single.euSeverity, EuSeverity.verySerious);
    });

    test('three reduced 9h rests are allowed, the fourth is not', () {
      final acts = _seq(
        monday,
        _repeat([
          (_drive, _h(4)),
          (_rest, _h(0, 45)),
          (_drive, _h(4)),
          (_work, _h(5, 45)),
          (_rest, _h(9, 30)),
        ], 5),
      );
      final rest = _ofType(
        analyzer.analyze(acts, _end(acts)),
        ViolationType.dailyRestInsufficient,
      );
      // Mon–Wed use the three reductions; Thu and Fri needed 11h.
      expect(rest, hasLength(2));
      expect(rest.map((v) => v.start.day), containsAll([8, 9]));
      expect(rest.first.euSeverity, EuSeverity.serious);
    });

    test('a split rest of 3h + 9h counts as a regular daily rest', () {
      final acts = _seq(
        monday,
        _repeat([
          (_drive, _h(4)),
          (_rest, _h(3)),
          (_drive, _h(4)),
          (_work, _h(1)),
          (_rest, _h(9)),
        ], 6),
      );
      final rest = _ofType(
        analyzer.analyze(acts, _end(acts)),
        ViolationType.dailyRestInsufficient,
      );
      expect(rest, isEmpty);
    });
  });

  group('weekly rest (Art. 8.6)', () {
    test('no 24h rest within six 24h periods is a delayed weekly rest', () {
      final acts = _seq(
        monday,
        _repeat([
          (_drive, _h(4)),
          (_rest, _h(0, 45)),
          (_drive, _h(4)),
          (_work, _h(4, 15)),
          (_rest, _h(11)),
        ], 8),
      );
      final weekly = _ofType(
        analyzer.analyze(acts, _end(acts)),
        ViolationType.weeklyRestInsufficient,
      );
      expect(weekly, hasLength(1));
      // Deadline: Mon 06:00 + 6×24h = Sun 06:00.
      expect(weekly.single.start, DateTime(2026, 1, 11, 6));
      expect(weekly.single.descriptionKey, 'violation.weeklyRestDelayed');
      expect(weekly.single.euSeverity, EuSeverity.verySerious);
    });

    test('a gap in the data never produces a rest violation', () {
      final first = _seq(monday, [
        (_drive, _h(4)),
        (_rest, _h(0, 45)),
        (_drive, _h(4)),
      ]);
      final second = _seq(DateTime(2026, 1, 8, 6), [
        (_drive, _h(4)),
        (_rest, _h(0, 45)),
        (_drive, _h(4)),
      ]);
      final acts = [...first, ...second];
      final violations = analyzer.analyze(acts, _end(acts).add(_h(1)));
      expect(_ofType(violations, ViolationType.dailyRestInsufficient), isEmpty);
      expect(
        _ofType(violations, ViolationType.weeklyRestInsufficient),
        isEmpty,
      );
      expect(_ofType(violations, ViolationType.missingRecord), isNotEmpty);
    });
  });

  group('driving limits', () {
    final nineAndAHalfHourDay = [
      (_drive, _h(4, 30)),
      (_rest, _h(0, 45)),
      (_drive, _h(4, 30)),
      (_rest, _h(0, 45)),
      (_drive, _h(0, 30)),
      (_rest, _h(13)),
    ];

    test('exactly 4h30 continuous and 9h daily driving is allowed', () {
      final acts = _seq(monday, [
        (_drive, _h(4, 30)),
        (_rest, _h(0, 45)),
        (_drive, _h(4, 30)),
        (_rest, _h(11)),
      ]);
      expect(analyzer.analyze(acts, _end(acts)), isEmpty);
    });

    test('two 10h extensions per week are allowed, the third is not', () {
      final acts = _seq(monday, _repeat(nineAndAHalfHourDay, 3));
      final daily = _ofType(
        analyzer.analyze(acts, _end(acts)),
        ViolationType.dailyDrivingExceeded,
      );
      expect(daily, hasLength(1));
      expect(daily.single.start.day, 7);
      expect(daily.single.excessDuration, _h(0, 30));
      expect(daily.single.descriptionKey, 'violation.dailyDrivingExceeded');
      expect(daily.single.euSeverity, EuSeverity.minor);
    });

    test('an extended day is measured against 10h', () {
      final acts = _seq(monday, [
        (_drive, _h(4, 30)),
        (_rest, _h(0, 45)),
        (_drive, _h(4, 30)),
        (_rest, _h(0, 45)),
        (_drive, _h(1, 30)),
        (_rest, _h(11)),
      ]);
      final daily = _ofType(
        analyzer.analyze(acts, _end(acts)),
        ViolationType.dailyDrivingExceeded,
      );
      expect(daily, hasLength(1));
      expect(daily.single.excessDuration, _h(0, 30));
      expect(
        daily.single.descriptionKey,
        'violation.dailyDrivingExceededExtended',
      );
    });

    test('a past week over 56h is found even when viewed weeks later', () {
      final acts = _seq(
        monday,
        _repeat([
          (_drive, _h(4, 30)),
          (_rest, _h(0, 45)),
          (_drive, _h(4, 30)),
          (_rest, _h(14, 15)),
        ], 7),
      );
      final weekly = _ofType(
        analyzer.analyze(acts, DateTime(2026, 1, 25, 12)),
        ViolationType.weeklyDrivingExceeded,
      );
      expect(weekly, hasLength(1));
      expect(weekly.single.excessDuration, _h(7));
      expect(weekly.single.start.toLocal().day, 11);
      expect(weekly.single.euSeverity, EuSeverity.serious);
    });
  });

  group('EU 2016/403 thresholds (Takograf_Ceza_Listesi_2026.xlsx)', () {
    test('continuous driving', () {
      expect(
        ViolationAnalyzer.continuousDrivingSeverity(_h(4, 45)),
        EuSeverity.minor,
      );
      expect(
        ViolationAnalyzer.continuousDrivingSeverity(_h(5)),
        EuSeverity.serious,
      );
      expect(
        ViolationAnalyzer.continuousDrivingSeverity(_h(6)),
        EuSeverity.verySerious,
      );
    });

    test('daily driving, with and without extension', () {
      const nine = Duration(hours: 9);
      const ten = Duration(hours: 10);
      expect(
        ViolationAnalyzer.dailyDrivingSeverity(_h(10), limit: nine),
        EuSeverity.serious,
      );
      expect(
        ViolationAnalyzer.dailyDrivingSeverity(_h(11), limit: nine),
        EuSeverity.verySerious,
      );
      expect(
        ViolationAnalyzer.dailyDrivingSeverity(_h(13, 30), limit: nine),
        EuSeverity.mostSerious,
      );
      expect(
        ViolationAnalyzer.dailyDrivingSeverity(_h(11), limit: ten),
        EuSeverity.serious,
      );
      expect(
        ViolationAnalyzer.dailyDrivingSeverity(_h(12), limit: ten),
        EuSeverity.verySerious,
      );
      expect(
        ViolationAnalyzer.dailyDrivingSeverity(_h(15), limit: ten),
        EuSeverity.mostSerious,
      );
    });

    test('weekly and bi-weekly driving', () {
      expect(
        ViolationAnalyzer.weeklyDrivingSeverity(_h(60)),
        EuSeverity.serious,
      );
      expect(
        ViolationAnalyzer.weeklyDrivingSeverity(_h(65)),
        EuSeverity.verySerious,
      );
      expect(
        ViolationAnalyzer.weeklyDrivingSeverity(_h(70)),
        EuSeverity.mostSerious,
      );
      expect(
        ViolationAnalyzer.biWeeklyDrivingSeverity(_h(100)),
        EuSeverity.serious,
      );
      expect(
        ViolationAnalyzer.biWeeklyDrivingSeverity(_h(105)),
        EuSeverity.verySerious,
      );
      expect(
        ViolationAnalyzer.biWeeklyDrivingSeverity(_h(112, 30)),
        EuSeverity.mostSerious,
      );
    });

    test('daily rest, reducible and regular', () {
      expect(
        ViolationAnalyzer.dailyRestSeverity(_h(8), reducible: true),
        EuSeverity.minor,
      );
      expect(
        ViolationAnalyzer.dailyRestSeverity(_h(7), reducible: true),
        EuSeverity.serious,
      );
      expect(
        ViolationAnalyzer.dailyRestSeverity(_h(6, 59), reducible: true),
        EuSeverity.verySerious,
      );
      expect(
        ViolationAnalyzer.dailyRestSeverity(_h(10), reducible: false),
        EuSeverity.minor,
      );
      expect(
        ViolationAnalyzer.dailyRestSeverity(_h(8, 30), reducible: false),
        EuSeverity.serious,
      );
      expect(
        ViolationAnalyzer.dailyRestSeverity(_h(8, 29), reducible: false),
        EuSeverity.verySerious,
      );
    });

    test('weekly rest', () {
      expect(
        ViolationAnalyzer.weeklyRestShortSeverity(_h(42)),
        EuSeverity.minor,
      );
      expect(
        ViolationAnalyzer.weeklyRestShortSeverity(_h(36)),
        EuSeverity.serious,
      );
      expect(
        ViolationAnalyzer.weeklyRestShortSeverity(_h(35)),
        EuSeverity.verySerious,
      );
      expect(
        ViolationAnalyzer.weeklyRestDelaySeverity(_h(2)),
        EuSeverity.minor,
      );
      expect(
        ViolationAnalyzer.weeklyRestDelaySeverity(_h(3)),
        EuSeverity.serious,
      );
      expect(
        ViolationAnalyzer.weeklyRestDelaySeverity(_h(12)),
        EuSeverity.verySerious,
      );
    });
  });
}
