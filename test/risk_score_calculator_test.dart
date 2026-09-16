import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/services/risk_score_calculator.dart';
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
  final calc = RiskScoreCalculator();

  test('no violations => perfect score, low risk', () {
    final result = calc.calculate(const []);
    expect(result.score, 100);
    expect(result.level, RiskLevel.low);
  });

  test('a single low-severity violation deducts only a small amount', () {
    final result = calc.calculate([
      _violation(
        ViolationType.continuousDrivingExceeded,
        excessDuration: Duration.zero,
      ),
    ]);
    expect(result.score, lessThan(100));
    expect(result.score, greaterThan(90));
  });

  test('worse overage deducts more than a barely-over one, same type', () {
    final barelyOver = calc.calculate([
      _violation(
        ViolationType.dailyDrivingExceeded,
        excessDuration: const Duration(minutes: 1),
      ),
    ]);
    final wayOver = calc.calculate([
      _violation(
        ViolationType.dailyDrivingExceeded,
        excessDuration: const Duration(hours: 3),
      ),
    ]);
    expect(wayOver.score, lessThan(barelyOver.score));
  });

  test(
    'repeating one violation type many times cannot alone zero out the score (per-type cap)',
    () {
      final violations = List.generate(
        50,
        (_) => _violation(
          ViolationType.continuousDrivingExceeded,
          excessDuration: const Duration(hours: 5),
        ),
      );
      final result = calc.calculate(violations);

      expect(result.score, 76);
    },
  );

  test('score never goes below 0 even with many severe, varied violations', () {
    final violations = <Violation>[];
    for (final type in ViolationType.values) {
      violations.addAll(
        List.generate(
          10,
          (_) => _violation(type, excessDuration: const Duration(hours: 20)),
        ),
      );
    }
    final result = calc.calculate(violations);
    expect(result.score, greaterThanOrEqualTo(0));
    expect(result.level, RiskLevel.high);
  });

  test(
    'missingRecord (no excessDuration) still applies its base weight once, capped',
    () {
      final violations = List.generate(
        10,
        (_) => _violation(ViolationType.missingRecord),
      );
      final result = calc.calculate(violations);

      expect(result.score, 90);
    },
  );
}
