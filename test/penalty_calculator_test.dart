import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/penalty_calculator.dart';
import 'package:smarttrack_mine/core/services/violation_analyzer.dart';

Violation _violation(ViolationType type, {Duration? excessDuration}) {
  final now = DateTime(2026, 1, 5, 12);
  return Violation(
    type: type,
    severity: ViolationSeverity.violation,
    start: now,
    end: now,
    descriptionKey: 'violation.x',
    ruleReference: 'EU 561/2006',
    excessDuration: excessDuration,
  );
}

void main() {
  final calc = PenaltyCalculator();

  group('driving-limit tiers (continuous/daily)', () {
    test('exceeded by exactly 1 hour uses the low tier', () {
      final v = _violation(
        ViolationType.continuousDrivingExceeded,
        excessDuration: const Duration(hours: 1),
      );
      expect(calc.estimate(v).amountTl, PenaltyCalculator.drivingOverageLowTl);
    });

    test('exceeded by more than 1 hour uses the high tier', () {
      final v = _violation(
        ViolationType.dailyDrivingExceeded,
        excessDuration: const Duration(hours: 1, minutes: 1),
      );
      expect(calc.estimate(v).amountTl, PenaltyCalculator.drivingOverageHighTl);
    });
  });

  group('weekly/bi-weekly driving tiers', () {
    test('exceeded by exactly 4 hours uses tier 1', () {
      final v = _violation(
        ViolationType.weeklyDrivingExceeded,
        excessDuration: const Duration(hours: 4),
      );
      expect(calc.estimate(v).amountTl, PenaltyCalculator.weeklyOverageTier1Tl);
    });

    test('exceeded by 10 hours uses tier 2', () {
      final v = _violation(
        ViolationType.biWeeklyDrivingExceeded,
        excessDuration: const Duration(hours: 10),
      );
      expect(calc.estimate(v).amountTl, PenaltyCalculator.weeklyOverageTier2Tl);
    });

    test(
      'exceeded by exactly 15 hours uses tier 3 (boundary is inclusive at the top)',
      () {
        final v = _violation(
          ViolationType.weeklyDrivingExceeded,
          excessDuration: const Duration(hours: 15),
        );
        expect(
          calc.estimate(v).amountTl,
          PenaltyCalculator.weeklyOverageTier3Tl,
        );
      },
    );
  });

  group('rest-insufficient flat rates', () {
    test(
      'daily rest insufficient is a flat amount regardless of excessDuration',
      () {
        final v = _violation(
          ViolationType.dailyRestInsufficient,
          excessDuration: const Duration(hours: 5),
        );
        expect(calc.estimate(v).amountTl, PenaltyCalculator.dailyRestTl);
      },
    );

    test('weekly rest insufficient is a flat amount', () {
      final v = _violation(
        ViolationType.weeklyRestInsufficient,
        excessDuration: const Duration(hours: 20),
      );
      expect(calc.estimate(v).amountTl, PenaltyCalculator.weeklyRestTl);
    });
  });

  test('missingRecord has no real fine amount', () {
    final v = _violation(ViolationType.missingRecord);
    final estimate = calc.estimate(v);
    expect(estimate.amountTl, isNull);
    expect(estimate.isRealFine, isFalse);
  });

  test('asCompany doubles the amount', () {
    final v = _violation(ViolationType.dailyRestInsufficient);
    final driverRate = calc.estimate(v, asCompany: false).amountTl!;
    final companyRate = calc.estimate(v, asCompany: true).amountTl!;
    expect(companyRate, driverRate * PenaltyCalculator.companyMultiplier);
  });

  test('asCompany never fabricates an amount for missingRecord', () {
    final v = _violation(ViolationType.missingRecord);
    expect(calc.estimate(v, asCompany: true).amountTl, isNull);
  });

  test('totalTl sums only real fines, excluding missingRecord', () {
    final violations = [
      _violation(ViolationType.dailyRestInsufficient),
      _violation(ViolationType.weeklyRestInsufficient),
      _violation(ViolationType.missingRecord),
    ];
    expect(
      calc.totalTl(violations),
      PenaltyCalculator.dailyRestTl + PenaltyCalculator.weeklyRestTl,
    );
  });

  test(
    'breakdownByType groups and sorts by total descending, excluding missingRecord',
    () {
      final violations = [
        _violation(ViolationType.dailyRestInsufficient),
        _violation(ViolationType.dailyRestInsufficient),
        _violation(ViolationType.weeklyRestInsufficient),
        _violation(ViolationType.missingRecord),
      ];
      final breakdown = calc.breakdownByType(violations);
      expect(breakdown.length, 2);
      expect(breakdown.first.type, ViolationType.dailyRestInsufficient);
      expect(breakdown.first.count, 2);
      expect(breakdown.first.totalTl, PenaltyCalculator.dailyRestTl * 2);
      expect(
        breakdown.any((e) => e.type == ViolationType.missingRecord),
        isFalse,
      );
    },
  );
}
