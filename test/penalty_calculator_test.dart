import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/penalty_calculator.dart';
import 'package:smarttrack_mine/core/services/violation_analyzer.dart';

Violation _violation(
  ViolationType type, {
  Duration? excessDuration,
  EuSeverity? euSeverity,
}) {
  final now = DateTime(2026, 1, 5, 12);
  return Violation(
    type: type,
    severity: ViolationSeverity.violation,
    start: now,
    end: now,
    descriptionKey: 'violation.x',
    ruleReference: 'EU 561/2006',
    excessDuration: excessDuration,
    euSeverity: euSeverity,
  );
}

void main() {
  final calc = PenaltyCalculator();

  group('continuous driving tiers (KTK 49/3-a)', () {
    test('exceeded by exactly 1 hour uses the low tier', () {
      final e = calc.estimate(
        _violation(
          ViolationType.continuousDrivingExceeded,
          excessDuration: const Duration(hours: 1),
        ),
      );
      expect(e.amountTl, PenaltyCalculator.continuousUpToOneHourTl);
      expect(e.legalRef, 'KTK 49/3-a-1');
    });

    test('exceeded by more than 1 hour uses the high tier', () {
      final e = calc.estimate(
        _violation(
          ViolationType.continuousDrivingExceeded,
          excessDuration: const Duration(hours: 1, minutes: 1),
        ),
      );
      expect(e.amountTl, PenaltyCalculator.continuousOverOneHourTl);
      expect(e.legalRef, 'KTK 49/3-a-2');
    });
  });

  group('daily driving tiers (KTK 49/3-b)', () {
    test('exceeded by exactly 1 hour uses tier 1', () {
      final e = calc.estimate(
        _violation(
          ViolationType.dailyDrivingExceeded,
          excessDuration: const Duration(hours: 1),
        ),
      );
      expect(e.amountTl, PenaltyCalculator.dailyUpToOneHourTl);
      expect(e.legalRef, 'KTK 49/3-b-1');
    });

    test('exceeded by 2 hours uses tier 2', () {
      final e = calc.estimate(
        _violation(
          ViolationType.dailyDrivingExceeded,
          excessDuration: const Duration(hours: 2),
        ),
      );
      expect(e.amountTl, PenaltyCalculator.dailyOneToThreeHoursTl);
      expect(e.legalRef, 'KTK 49/3-b-2');
    });

    test(
      'exceeded by exactly 3 hours uses tier 3 ("üç saat ve daha fazla")',
      () {
        final e = calc.estimate(
          _violation(
            ViolationType.dailyDrivingExceeded,
            excessDuration: const Duration(hours: 3),
          ),
        );
        expect(e.amountTl, PenaltyCalculator.dailyThreeHoursOrMoreTl);
        expect(e.legalRef, 'KTK 49/3-b-3');
      },
    );

    test('daily overage is priced differently from continuous overage', () {
      const excess = Duration(minutes: 30);
      final daily = calc.estimate(
        _violation(ViolationType.dailyDrivingExceeded, excessDuration: excess),
      );
      final continuous = calc.estimate(
        _violation(
          ViolationType.continuousDrivingExceeded,
          excessDuration: excess,
        ),
      );
      expect(daily.amountTl, isNot(continuous.amountTl));
    });
  });

  group('weekly/bi-weekly driving tiers (KTK 49/3-c)', () {
    test('exceeded by exactly 4 hours uses tier 1', () {
      final e = calc.estimate(
        _violation(
          ViolationType.weeklyDrivingExceeded,
          excessDuration: const Duration(hours: 4),
        ),
      );
      expect(e.amountTl, PenaltyCalculator.weeklyUpToFourHoursTl);
      expect(e.legalRef, 'KTK 49/3-c-1');
    });

    test('exceeded by 10 hours uses tier 2', () {
      final e = calc.estimate(
        _violation(
          ViolationType.biWeeklyDrivingExceeded,
          excessDuration: const Duration(hours: 10),
        ),
      );
      expect(e.amountTl, PenaltyCalculator.weeklyFourToFifteenHoursTl);
      expect(e.legalRef, 'KTK 49/3-c-2');
    });

    test('exceeded by exactly 15 hours uses tier 3', () {
      final e = calc.estimate(
        _violation(
          ViolationType.weeklyDrivingExceeded,
          excessDuration: const Duration(hours: 15),
        ),
      );
      expect(e.amountTl, PenaltyCalculator.weeklyFifteenHoursOrMoreTl);
      expect(e.legalRef, 'KTK 49/3-c-3');
    });
  });

  group('rest-insufficient flat rates (KTK 49/3-d, 49/3-e)', () {
    test(
      'daily rest insufficient is a flat amount regardless of excessDuration',
      () {
        final e = calc.estimate(
          _violation(
            ViolationType.dailyRestInsufficient,
            excessDuration: const Duration(hours: 5),
          ),
        );
        expect(e.amountTl, PenaltyCalculator.dailyRestTl);
        expect(e.legalRef, 'KTK 49/3-d');
      },
    );

    test('weekly rest insufficient is a flat amount', () {
      final e = calc.estimate(
        _violation(
          ViolationType.weeklyRestInsufficient,
          excessDuration: const Duration(hours: 20),
        ),
      );
      expect(e.amountTl, PenaltyCalculator.weeklyRestTl);
      expect(e.legalRef, 'KTK 49/3-e');
    });
  });

  test('amounts are the full 2026 rates, not the discounted ones', () {
    expect(PenaltyCalculator.continuousUpToOneHourTl, 1000);
    expect(PenaltyCalculator.dailyOneToThreeHoursTl, 5000);
    expect(PenaltyCalculator.weeklyUpToFourHoursTl, 10000);
    expect(PenaltyCalculator.dailyRestTl, 3000);
    expect(PenaltyCalculator.weeklyRestTl, 5000);
  });

  test('discountedAmountTl applies the 25% early-payment discount', () {
    final e = calc.estimate(
      _violation(
        ViolationType.dailyDrivingExceeded,
        excessDuration: const Duration(hours: 2),
      ),
    );
    expect(e.amountTl, 5000);
    expect(e.discountedAmountTl, 3750);
  });

  test('every 49/3 fine carries 20 points and a driving ban', () {
    final e = calc.estimate(
      _violation(
        ViolationType.continuousDrivingExceeded,
        excessDuration: const Duration(minutes: 30),
        euSeverity: EuSeverity.serious,
      ),
    );
    expect(e.penaltyPoints, 20);
    expect(e.sanctionKey, PenaltyCalculator.drivingBanSanctionKey);
    expect(e.euSeverity, EuSeverity.serious);
  });

  test('missingRecord has no real fine amount', () {
    final estimate = calc.estimate(_violation(ViolationType.missingRecord));
    expect(estimate.amountTl, isNull);
    expect(estimate.discountedAmountTl, isNull);
    expect(estimate.legalRef, isNull);
    expect(estimate.isRealFine, isFalse);
    expect(estimate.penaltyPoints, isNull);
    expect(estimate.sanctionKey, isNull);
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
        _violation(ViolationType.dailyRestInsufficient),
        _violation(ViolationType.weeklyRestInsufficient),
        _violation(ViolationType.missingRecord),
      ];
      final breakdown = calc.breakdownByType(violations);
      expect(breakdown.length, 2);
      expect(breakdown.first.type, ViolationType.dailyRestInsufficient);
      expect(breakdown.first.count, 3);
      expect(breakdown.first.totalTl, PenaltyCalculator.dailyRestTl * 3);
      expect(
        breakdown.any((e) => e.type == ViolationType.missingRecord),
        isFalse,
      );
    },
  );
}
