import 'violation_analyzer.dart';

class PenaltyEstimate {
  final ViolationType type;

  /// Full fine in TL, or null when the violation carries no fine.
  final int? amountTl;

  final String tierLabelKey;

  /// Legal basis of the fine, e.g. `KTK 49/3-b-2`. Null when no fine applies.
  final String? legalRef;

  final bool isCompanyRate;

  /// EU 2016/403 category of the underlying violation.
  final EuSeverity? euSeverity;

  /// Driver's licence penalty points, or null when no fine applies.
  final int? penaltyPoints;

  /// Additional sanction (e.g. prohibition from driving), or null.
  final String? sanctionKey;

  const PenaltyEstimate({
    required this.type,
    required this.amountTl,
    required this.tierLabelKey,
    required this.legalRef,
    required this.isCompanyRate,
    this.euSeverity,
    this.penaltyPoints,
    this.sanctionKey,
  });

  bool get isRealFine => amountTl != null;

  /// [amountTl] after the early-payment discount (fine paid within 15 days of
  /// notification).
  int? get discountedAmountTl => amountTl == null
      ? null
      : amountTl! *
            (100 - PenaltyCalculator.earlyPaymentDiscountPercent) ~/
            100;
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

/// Driver fines for driving/rest-time violations under Karayolları Trafik
/// Kanunu (2918) madde 49/3, at the 2026 rates. Amounts are the full fine;
/// see [PenaltyEstimate.discountedAmountTl] for the early-payment amount.
/// Amounts, points and sanctions match the "2918 Resmi Maddeler" sheet of
/// Takograf_Ceza_Listesi_2026.xlsx.
class PenaltyCalculator {
  // 49/3-a: continuous driving time exceeded.
  static const int continuousUpToOneHourTl = 1000;
  static const int continuousOverOneHourTl = 3000;

  // 49/3-b: daily driving time exceeded.
  static const int dailyUpToOneHourTl = 3000;
  static const int dailyOneToThreeHoursTl = 5000;
  static const int dailyThreeHoursOrMoreTl = 10000;

  // 49/3-c: weekly or bi-weekly driving time exceeded.
  static const int weeklyUpToFourHoursTl = 10000;
  static const int weeklyFourToFifteenHoursTl = 15000;
  static const int weeklyFifteenHoursOrMoreTl = 20000;

  // 49/3-d and 49/3-e: daily / weekly rest violated.
  static const int dailyRestTl = 3000;
  static const int weeklyRestTl = 5000;

  static const int earlyPaymentDiscountPercent = 25;

  /// The vehicle operator (işleten) is fined twice the driver amount.
  static const int companyMultiplier = 2;

  /// Every 49/3 violation adds 20 penalty points to the driver's licence.
  static const int penaltyPointsPerViolation = 20;

  /// Every 49/3 violation also carries "araç kullanmaktan men" (the driver is
  /// barred from driving on).
  static const String drivingBanSanctionKey = 'analysis.sanctionDrivingBan';

  PenaltyEstimate estimate(Violation violation, {bool asCompany = false}) {
    final int? baseAmount;
    final String tierLabelKey;
    final String? legalRef;
    final excess = violation.excessDuration ?? Duration.zero;

    switch (violation.type) {
      case ViolationType.continuousDrivingExceeded:
        if (excess <= const Duration(hours: 1)) {
          baseAmount = continuousUpToOneHourTl;
          tierLabelKey = 'analysis.penaltyTierUpToOneHour';
          legalRef = 'KTK 49/3-a-1';
        } else {
          baseAmount = continuousOverOneHourTl;
          tierLabelKey = 'analysis.penaltyTierOverOneHour';
          legalRef = 'KTK 49/3-a-2';
        }

      case ViolationType.dailyDrivingExceeded:
        if (excess <= const Duration(hours: 1)) {
          baseAmount = dailyUpToOneHourTl;
          tierLabelKey = 'analysis.penaltyTierUpToOneHour';
          legalRef = 'KTK 49/3-b-1';
        } else if (excess < const Duration(hours: 3)) {
          baseAmount = dailyOneToThreeHoursTl;
          tierLabelKey = 'analysis.penaltyTierOneToThreeHours';
          legalRef = 'KTK 49/3-b-2';
        } else {
          baseAmount = dailyThreeHoursOrMoreTl;
          tierLabelKey = 'analysis.penaltyTierThreeHoursOrMore';
          legalRef = 'KTK 49/3-b-3';
        }

      case ViolationType.weeklyDrivingExceeded:
      case ViolationType.biWeeklyDrivingExceeded:
        if (excess <= const Duration(hours: 4)) {
          baseAmount = weeklyUpToFourHoursTl;
          tierLabelKey = 'analysis.penaltyTierUpToFourHours';
          legalRef = 'KTK 49/3-c-1';
        } else if (excess < const Duration(hours: 15)) {
          baseAmount = weeklyFourToFifteenHoursTl;
          tierLabelKey = 'analysis.penaltyTierFourToFifteenHours';
          legalRef = 'KTK 49/3-c-2';
        } else {
          baseAmount = weeklyFifteenHoursOrMoreTl;
          tierLabelKey = 'analysis.penaltyTierOverFifteenHours';
          legalRef = 'KTK 49/3-c-3';
        }

      case ViolationType.dailyRestInsufficient:
        baseAmount = dailyRestTl;
        tierLabelKey = 'analysis.penaltyTierFlatRate';
        legalRef = 'KTK 49/3-d';

      case ViolationType.weeklyRestInsufficient:
        baseAmount = weeklyRestTl;
        tierLabelKey = 'analysis.penaltyTierFlatRate';
        legalRef = 'KTK 49/3-e';

      case ViolationType.missingRecord:
        baseAmount = null;
        tierLabelKey = 'analysis.missingRecordNotFine';
        legalRef = null;
    }

    return PenaltyEstimate(
      type: violation.type,
      amountTl: baseAmount == null
          ? null
          : (asCompany ? baseAmount * companyMultiplier : baseAmount),
      tierLabelKey: tierLabelKey,
      legalRef: legalRef,
      isCompanyRate: asCompany && baseAmount != null,
      euSeverity: violation.euSeverity,
      penaltyPoints: baseAmount == null ? null : penaltyPointsPerViolation,
      sanctionKey: baseAmount == null ? null : drivingBanSanctionKey,
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
