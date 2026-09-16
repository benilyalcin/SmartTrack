import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/driving_time_calculator.dart';

TachographActivity _act(ActivityType type, DateTime start, Duration duration) {
  return TachographActivity(
    type: type,
    startTime: start,
    endTime: start.add(duration),
  );
}

void main() {
  final calc = DrivingTimeCalculator();

  final monday = DateTime(2026, 1, 5, 0, 0);

  group('satisfiesArticle7BreakRequirement', () {
    test('a single 45+ minute break satisfies it on its own', () {
      expect(
        DrivingTimeCalculator.satisfiesArticle7BreakRequirement([
          const Duration(minutes: 45),
        ]),
        isTrue,
      );
      expect(
        DrivingTimeCalculator.satisfiesArticle7BreakRequirement([
          const Duration(minutes: 44),
        ]),
        isFalse,
      );
    });

    test('15 then 30 (correct split order) satisfies it', () {
      expect(
        DrivingTimeCalculator.satisfiesArticle7BreakRequirement([
          const Duration(minutes: 15),
          const Duration(minutes: 30),
        ]),
        isTrue,
      );
    });

    test('30 then 15 (reversed split order) does NOT satisfy it', () {
      expect(
        DrivingTimeCalculator.satisfiesArticle7BreakRequirement([
          const Duration(minutes: 30),
          const Duration(minutes: 15),
        ]),
        isFalse,
      );
    });

    test('two short breaks under both thresholds never satisfy it', () {
      expect(
        DrivingTimeCalculator.satisfiesArticle7BreakRequirement([
          const Duration(minutes: 10),
          const Duration(minutes: 10),
        ]),
        isFalse,
      );
    });
  });

  group('continuous driving (4h30 limit)', () {
    test('accumulates driving time across a day with no breaks', () {
      final activities = [
        _act(
          ActivityType.driving,
          monday.add(const Duration(hours: 8)),
          const Duration(hours: 3),
        ),
      ];
      final result = calc.calculate(
        activities,
        monday.add(const Duration(hours: 12)),
      )['continuous']!;
      expect(result.used, const Duration(hours: 3));
      expect(result.isExceeded, isFalse);
    });

    test('a qualifying break (45min) resets the continuous counter', () {
      final start = monday.add(const Duration(hours: 8));
      final activities = [
        _act(ActivityType.driving, start, const Duration(hours: 4)),
        _act(
          ActivityType.rest,
          start.add(const Duration(hours: 4)),
          const Duration(minutes: 45),
        ),
        _act(
          ActivityType.driving,
          start.add(const Duration(hours: 4, minutes: 45)),
          const Duration(hours: 1),
        ),
      ];
      final result = calc.calculate(
        activities,
        monday.add(const Duration(hours: 14)),
      )['continuous']!;

      expect(result.used, const Duration(hours: 1));
    });

    test('a non-qualifying break (10min) does NOT reset the counter', () {
      final start = monday.add(const Duration(hours: 8));
      final activities = [
        _act(ActivityType.driving, start, const Duration(hours: 2)),
        _act(
          ActivityType.rest,
          start.add(const Duration(hours: 2)),
          const Duration(minutes: 10),
        ),
        _act(
          ActivityType.driving,
          start.add(const Duration(hours: 2, minutes: 10)),
          const Duration(hours: 1),
        ),
      ];
      final result = calc.calculate(
        activities,
        monday.add(const Duration(hours: 12)),
      )['continuous']!;
      expect(result.used, const Duration(hours: 3));
    });

    test('exceeding 4h30 continuous driving is flagged', () {
      final start = monday.add(const Duration(hours: 8));
      final activities = [
        _act(ActivityType.driving, start, const Duration(hours: 5)),
      ];
      final result = calc.calculate(
        activities,
        monday.add(const Duration(hours: 14)),
      )['continuous']!;
      expect(result.isExceeded, isTrue);
      expect(result.remaining, Duration.zero);
    });
  });

  group('daily driving (9h limit)', () {
    test(
      'a 9h+ rest resets the daily counter (walked backwards from latest)',
      () {
        final activities = [
          _act(
            ActivityType.driving,
            monday.add(const Duration(hours: 6)),
            const Duration(hours: 4),
          ),
          _act(
            ActivityType.rest,
            monday.add(const Duration(hours: 10)),
            const Duration(hours: 10),
          ),
          _act(
            ActivityType.driving,
            monday.add(const Duration(hours: 20)),
            const Duration(hours: 2),
          ),
        ];
        final result = calc.calculate(
          activities,
          monday.add(const Duration(hours: 23)),
        )['daily']!;
        expect(result.used, const Duration(hours: 2));
      },
    );

    test('exceeding 9h daily driving is flagged', () {
      final activities = [
        _act(
          ActivityType.driving,
          monday.add(const Duration(hours: 6)),
          const Duration(hours: 9, minutes: 30),
        ),
      ];
      final result = calc.calculate(
        activities,
        monday.add(const Duration(hours: 16)),
      )['daily']!;
      expect(result.isExceeded, isTrue);
    });
  });

  group('weekly driving (56h limit, Monday-anchored)', () {
    test('driving before this Monday does not count toward this week', () {
      final lastSunday = monday.subtract(const Duration(hours: 6));
      final activities = [
        _act(ActivityType.driving, lastSunday, const Duration(hours: 5)),
        _act(
          ActivityType.driving,
          monday.add(const Duration(hours: 8)),
          const Duration(hours: 3),
        ),
      ];
      final result = calc.calculate(
        activities,
        monday.add(const Duration(hours: 12)),
      )['weekly']!;
      expect(result.used, const Duration(hours: 3));
    });

    test(
      'an activity spanning the week boundary is clipped to the overlap',
      () {
        final activities = [
          _act(
            ActivityType.driving,
            monday.subtract(const Duration(hours: 1)),
            const Duration(hours: 3),
          ),
        ];
        final result = calc.calculate(
          activities,
          monday.add(const Duration(hours: 12)),
        )['weekly']!;
        expect(result.used, const Duration(hours: 2));
      },
    );
  });

  group('bi-weekly driving (90h limit)', () {
    test('driving in the previous calendar week still counts', () {
      final activities = [
        _act(
          ActivityType.driving,
          monday.subtract(const Duration(days: 3)),
          const Duration(hours: 10),
        ),
        _act(
          ActivityType.driving,
          monday.add(const Duration(hours: 8)),
          const Duration(hours: 5),
        ),
      ];
      final result = calc.calculate(
        activities,
        monday.add(const Duration(hours: 12)),
      )['bi_weekly']!;
      expect(result.used, const Duration(hours: 15));
    });

    test('driving two full weeks ago (outside the window) does not count', () {
      final activities = [
        _act(
          ActivityType.driving,
          monday.subtract(const Duration(days: 10)),
          const Duration(hours: 10),
        ),
      ];
      final result = calc.calculate(
        activities,
        monday.add(const Duration(hours: 12)),
      )['bi_weekly']!;
      expect(result.used, Duration.zero);
    });
  });

  group('compensationDeadlineRemaining', () {
    test(
      'a debt from last week is due by the end of this week (3-week rule)',
      () {
        final now = monday.add(const Duration(hours: 10));
        final remaining = calc.compensationDeadlineRemaining(1, now);

        final expectedDeadline = monday.add(const Duration(days: 14));
        expect(now.add(remaining), expectedDeadline);
      },
    );

    test('a debt from 2 weeks before last has the soonest deadline', () {
      final now = monday.add(const Duration(hours: 10));
      final remaining1 = calc.compensationDeadlineRemaining(1, now);
      final remaining2 = calc.compensationDeadlineRemaining(2, now);
      final remaining3 = calc.compensationDeadlineRemaining(3, now);
      expect(remaining3, lessThan(remaining2));
      expect(remaining2, lessThan(remaining1));
    });

    test('a deadline already in the past clamps to zero, not negative', () {
      final now = monday.add(const Duration(days: 3, hours: 10));
      final remaining = calc.compensationDeadlineRemaining(3, now);
      expect(remaining, Duration.zero);
    });
  });

  group('segmentsFullyCoverRange (real-card gap-fill safety check)', () {
    final gapStart = monday.add(const Duration(hours: 8));
    final gapEnd = monday.add(const Duration(hours: 12));

    test('empty segment list never covers a gap', () {
      expect(
        DrivingTimeCalculator.segmentsFullyCoverRange([], gapStart, gapEnd),
        isFalse,
      );
    });

    test('one segment spanning the whole gap covers it', () {
      final segments = [
        _act(ActivityType.driving, gapStart, const Duration(hours: 4)),
      ];
      expect(
        DrivingTimeCalculator.segmentsFullyCoverRange(
          segments,
          gapStart,
          gapEnd,
        ),
        isTrue,
      );
    });

    test(
      'a segment starting after the gap start leaves the beginning uncovered',
      () {
        final segments = [
          _act(
            ActivityType.driving,
            gapStart.add(const Duration(minutes: 30)),
            const Duration(hours: 3, minutes: 30),
          ),
        ];
        expect(
          DrivingTimeCalculator.segmentsFullyCoverRange(
            segments,
            gapStart,
            gapEnd,
          ),
          isFalse,
        );
      },
    );

    test('a segment ending before the gap end leaves the end uncovered', () {
      final segments = [
        _act(ActivityType.driving, gapStart, const Duration(hours: 3)),
      ];
      expect(
        DrivingTimeCalculator.segmentsFullyCoverRange(
          segments,
          gapStart,
          gapEnd,
        ),
        isFalse,
      );
    });

    test('two contiguous segments (back to back) fully cover the gap', () {
      final segments = [
        _act(ActivityType.driving, gapStart, const Duration(hours: 2)),
        _act(
          ActivityType.rest,
          gapStart.add(const Duration(hours: 2)),
          const Duration(hours: 2),
        ),
      ];
      expect(
        DrivingTimeCalculator.segmentsFullyCoverRange(
          segments,
          gapStart,
          gapEnd,
        ),
        isTrue,
      );
    });

    test('a sub-gap between two segments is correctly rejected', () {
      final segments = [
        _act(ActivityType.driving, gapStart, const Duration(hours: 1)),

        _act(
          ActivityType.rest,
          gapStart.add(const Duration(hours: 2)),
          const Duration(hours: 2),
        ),
      ];
      expect(
        DrivingTimeCalculator.segmentsFullyCoverRange(
          segments,
          gapStart,
          gapEnd,
        ),
        isFalse,
      );
    });

    test(
      'overlapping segments still cover correctly (no double-counting bug)',
      () {
        final segments = [
          _act(ActivityType.driving, gapStart, const Duration(hours: 3)),
          _act(
            ActivityType.rest,
            gapStart.add(const Duration(hours: 1)),
            const Duration(hours: 3),
          ),
        ];
        expect(
          DrivingTimeCalculator.segmentsFullyCoverRange(
            segments,
            gapStart,
            gapEnd,
          ),
          isTrue,
        );
      },
    );
  });
}
