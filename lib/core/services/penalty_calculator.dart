import 'violation_analyzer.dart';

class PenaltyEstimate {
  final ViolationType type;

  final int? amountTl;

  final String tierLabelKey;

  final bool isCompanyRate;

  const PenaltyEstimate({
    required this.type,
    required this.amountTl,
    required this.tierLabelKey,
    required this.isCompanyRate,
  });

  bool get isRealFine => amountTl != null;
}

class PenaltyBreakdownEntry {
  final ViolationType type;
  final int count;
  final int totalTl;

  const PenaltyBreakdownEntry({
    required this.type,
    required this.count,
    required this.totalTl,
  });
}

class PenaltyCalculator {
  static const int drivingOverageLowTl = 1000;
  static const int drivingOverageHighTl = 3000;
  static const Duration _drivingOverageLowThreshold = Duration(hours: 1);

  static const int weeklyOverageTier1Tl = 7500;
  static const int weeklyOverageTier2Tl = 11250;
  static const int weeklyOverageTier3Tl = 15000;
  static const Duration _weeklyOverageTier1Threshold = Duration(hours: 4);
  static const Duration _weeklyOverageTier2Threshold = Duration(hours: 15);

  static const int dailyRestTl = 2250;
  static const int weeklyRestTl = 3750;

  static const int companyMultiplier = 2;

  PenaltyEstimate estimate(Violation violation, {bool asCompany = false}) {
    final int? baseAmount;
    final String tierLabelKey;

    switch (violation.type) {
      case ViolationType.continuousDrivingExceeded:
      case ViolationType.dailyDrivingExceeded:
        final excess = violation.excessDuration ?? Duration.zero;
        if (excess <= _drivingOverageLowThreshold) {
          baseAmount = drivingOverageLowTl;
          tierLabelKey = 'analysis.penaltyTierUpToOneHour';
        } else {
          baseAmount = drivingOverageHighTl;
          tierLabelKey = 'analysis.penaltyTierOverOneHour';
        }

      case ViolationType.weeklyDrivingExceeded:
      case ViolationType.biWeeklyDrivingExceeded:
        final excess = violation.excessDuration ?? Duration.zero;
        if (excess <= _weeklyOverageTier1Threshold) {
          baseAmount = weeklyOverageTier1Tl;
          tierLabelKey = 'analysis.penaltyTierUpToFourHours';
        } else if (excess < _weeklyOverageTier2Threshold) {
          baseAmount = weeklyOverageTier2Tl;
          tierLabelKey = 'analysis.penaltyTierFourToFifteenHours';
        } else {
          baseAmount = weeklyOverageTier3Tl;
          tierLabelKey = 'analysis.penaltyTierOverFifteenHours';
        }

      case ViolationType.dailyRestInsufficient:
        baseAmount = dailyRestTl;
        tierLabelKey = 'analysis.penaltyTierFlatRate';

      case ViolationType.weeklyRestInsufficient:
        baseAmount = weeklyRestTl;
        tierLabelKey = 'analysis.penaltyTierFlatRate';

      case ViolationType.missingRecord:
        baseAmount = null;
        tierLabelKey = 'analysis.missingRecordNotFine';
    }

    return PenaltyEstimate(
      type: violation.type,
      amountTl: baseAmount == null
          ? null
          : (asCompany ? baseAmount * companyMultiplier : baseAmount),
      tierLabelKey: tierLabelKey,
      isCompanyRate: asCompany && baseAmount != null,
    );
  }

  int totalTl(List<Violation> violations, {bool asCompany = false}) {
    var total = 0;
    for (final v in violations) {
      total += estimate(v, asCompany: asCompany).amountTl ?? 0;
    }
    return total;
  }

  List<PenaltyBreakdownEntry> breakdownByType(
    List<Violation> violations, {
    bool asCompany = false,
  }) {
    final totals = <ViolationType, int>{};
    final counts = <ViolationType, int>{};
    for (final v in violations) {
      final amount = estimate(v, asCompany: asCompany).amountTl;
      if (amount == null) continue;
      totals[v.type] = (totals[v.type] ?? 0) + amount;
      counts[v.type] = (counts[v.type] ?? 0) + 1;
    }
    final entries =
        totals.entries
            .map(
              (e) => PenaltyBreakdownEntry(
                type: e.key,
                count: counts[e.key]!,
                totalTl: e.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.totalTl.compareTo(a.totalTl));
    return entries;
  }
}
