import 'dart:math';

import 'violation_analyzer.dart';

enum RiskLevel { low, medium, high }

class RiskScoreResult {
  final int score;
  final RiskLevel level;

  final Map<ViolationType, double> deductionByType;

  const RiskScoreResult({
    required this.score,
    required this.level,
    required this.deductionByType,
  });
}

class RiskScoreCalculator {
  static const Duration defaultWindow = Duration(days: 28);

  static const Map<ViolationType, double> _baseWeights = {
    ViolationType.continuousDrivingExceeded: 8,
    ViolationType.dailyDrivingExceeded: 10,
    ViolationType.weeklyDrivingExceeded: 14,
    ViolationType.biWeeklyDrivingExceeded: 16,
    ViolationType.dailyRestInsufficient: 10,
    ViolationType.weeklyRestInsufficient: 14,
    ViolationType.missingRecord: 3,
  };

  static const Map<ViolationType, double> _perTypeCap = {
    ViolationType.continuousDrivingExceeded: 24,
    ViolationType.dailyDrivingExceeded: 30,
    ViolationType.weeklyDrivingExceeded: 35,
    ViolationType.biWeeklyDrivingExceeded: 40,
    ViolationType.dailyRestInsufficient: 30,
    ViolationType.weeklyRestInsufficient: 35,
    ViolationType.missingRecord: 10,
  };

  static const Map<ViolationType, int> _referenceMinutes = {
    ViolationType.continuousDrivingExceeded: 60,
    ViolationType.dailyDrivingExceeded: 60,
    ViolationType.weeklyDrivingExceeded: 240,
    ViolationType.biWeeklyDrivingExceeded: 240,
    ViolationType.dailyRestInsufficient: 60,
    ViolationType.weeklyRestInsufficient: 60,
  };

  RiskScoreResult calculate(List<Violation> violationsInWindow) {
    final cumulativeByType = <ViolationType, double>{};

    for (final v in violationsInWindow) {
      final referenceMinutes = _referenceMinutes[v.type];
      final excess = v.excessDuration;
      final severityMultiplier = (referenceMinutes == null || excess == null)
          ? 1.0
          : 1.0 + min(excess.inMinutes / referenceMinutes, 1.5) * 0.5;

      final deduction = (_baseWeights[v.type] ?? 0) * severityMultiplier;
      cumulativeByType[v.type] = (cumulativeByType[v.type] ?? 0) + deduction;
    }

    final cappedByType = <ViolationType, double>{
      for (final entry in cumulativeByType.entries)
        entry.key: min(entry.value, _perTypeCap[entry.key] ?? entry.value),
    };

    final totalDeduction = cappedByType.values.fold<double>(
      0,
      (sum, d) => sum + d,
    );
    final score = (100 - totalDeduction).round().clamp(0, 100);

    return RiskScoreResult(
      score: score,
      level: _levelFor(score),
      deductionByType: cappedByType,
    );
  }

  RiskLevel _levelFor(int score) {
    if (score >= 80) return RiskLevel.low;
    if (score >= 50) return RiskLevel.medium;
    return RiskLevel.high;
  }
}
