import '../../core/services/penalty_calculator.dart';
import '../../core/services/violation_analyzer.dart';

/// Reference data for the "Cezalar ve Ciddiyetleri" sheet: the driving and
/// rest-time rows of Annex III to Directive 2006/22/EC (as replaced by
/// Regulation (EU) 2016/403), each paired with the Turkish fine from
/// Takograf_Ceza_Listesi_2026.xlsx. Where the KTK 49/3 tier changes inside
/// an EU range, the range is split so every row has one exact fine.

/// One range of the measured value with its EU category and Turkish fine.
class SeverityBand {
  /// Lower bound of the measured value, or null when unbounded below.
  final Duration? min;
  final bool minInclusive;

  /// Upper bound of the measured value, or null when unbounded above.
  final Duration? max;
  final bool maxInclusive;

  /// First part of a split rest, shown as "3 sa + (range)".
  final Duration? splitFirstPart;

  /// Extra condition shown after the range (e.g. "no break").
  final String? conditionKey;

  final EuSeverity severity;

  /// Driver fine in TL, or null when there is no Turkish fine
  /// ([fineNoteKey] says why).
  final int? fineTl;

  /// A second fine written together with the first one.
  final int? extraFineTl;

  final String? fineNoteKey;

  const SeverityBand({
    this.min,
    this.minInclusive = true,
    this.max,
    this.maxInclusive = false,
    this.splitFirstPart,
    this.conditionKey,
    required this.severity,
    this.fineTl,
    this.extraFineTl,
    this.fineNoteKey,
  });
}

class SeverityRule {
  final String titleKey;
  final List<SeverityBand> bands;

  const SeverityRule({required this.titleKey, required this.bands});
}

class SeverityGroup {
  final String titleKey;
  final List<SeverityRule> rules;

  const SeverityGroup({required this.titleKey, required this.rules});
}

Duration _hours(int h, [int m = 0]) => Duration(hours: h, minutes: m);

const _dailyRestFine = PenaltyCalculator.dailyRestTl;
const _weeklyRestFine = PenaltyCalculator.weeklyRestTl;

/// Daily rest bands that share the reduced (9h) thresholds.
List<SeverityBand> _reducedDailyRestBands({Duration? splitFirstPart}) => [
  SeverityBand(
    min: _hours(8),
    max: _hours(9),
    splitFirstPart: splitFirstPart,
    severity: EuSeverity.minor,
    fineTl: _dailyRestFine,
  ),
  SeverityBand(
    min: _hours(7),
    max: _hours(8),
    splitFirstPart: splitFirstPart,
    severity: EuSeverity.serious,
    fineTl: _dailyRestFine,
  ),
  SeverityBand(
    max: _hours(7),
    splitFirstPart: splitFirstPart,
    severity: EuSeverity.verySerious,
    fineTl: _dailyRestFine,
  ),
];

/// Daily driving bands for a limit of [limit] hours (9, or 10 when
/// extended). KTK 49/3-b: up to 1h over → b-1, 1–3h over → b-2, 3h or more
/// over → b-3.
List<SeverityBand> _dailyDrivingBands(int limit) => [
  SeverityBand(
    min: _hours(limit),
    minInclusive: false,
    max: _hours(limit + 1),
    severity: EuSeverity.minor,
    fineTl: PenaltyCalculator.dailyUpToOneHourTl,
  ),
  SeverityBand(
    min: _hours(limit + 1),
    max: _hours(limit + 2),
    severity: EuSeverity.serious,
    fineTl: PenaltyCalculator.dailyOneToThreeHoursTl,
  ),
  SeverityBand(
    min: _hours(limit + 2),
    max: _hours(limit + 3),
    severity: EuSeverity.verySerious,
    fineTl: PenaltyCalculator.dailyOneToThreeHoursTl,
  ),
  SeverityBand(
    min: _hours(limit + 3),
    severity: EuSeverity.verySerious,
    fineTl: PenaltyCalculator.dailyThreeHoursOrMoreTl,
  ),
  SeverityBand(
    min: _hours(limit) * 1.5,
    conditionKey: 'analysis.sevConditionNoBreak',
    severity: EuSeverity.mostSerious,
    fineTl: PenaltyCalculator.dailyThreeHoursOrMoreTl,
    extraFineTl: PenaltyCalculator.continuousOverOneHourTl,
  ),
];

/// Weekly-rest-delay bands (< 3h MI, 3–12h SI, 12h or more VSI).
List<SeverityBand> _delayBands() => [
  SeverityBand(
    max: _hours(3),
    severity: EuSeverity.minor,
    fineTl: _weeklyRestFine,
  ),
  SeverityBand(
    min: _hours(3),
    max: _hours(12),
    severity: EuSeverity.serious,
    fineTl: _weeklyRestFine,
  ),
  SeverityBand(
    min: _hours(12),
    severity: EuSeverity.verySerious,
    fineTl: _weeklyRestFine,
  ),
];

final List<SeverityGroup> severityReference = [
  SeverityGroup(
    titleKey: 'analysis.sevGroupCrew',
    rules: [
      SeverityRule(
        titleKey: 'analysis.sevRuleMinAge',
        bands: [SeverityBand(severity: EuSeverity.serious, fineTl: 40000)],
      ),
    ],
  ),
  SeverityGroup(
    titleKey: 'analysis.sevGroupDriving',
    rules: [
      SeverityRule(
        titleKey: 'analysis.sevRuleDaily9',
        bands: _dailyDrivingBands(9),
      ),
      SeverityRule(
        titleKey: 'analysis.sevRuleDaily10',
        bands: _dailyDrivingBands(10),
      ),
      // KTK 49/3-c: up to 4h over → c-1, 4–15h over → c-2, 15h or more → c-3.
      SeverityRule(
        titleKey: 'analysis.sevRuleWeekly',
        bands: [
          SeverityBand(
            min: _hours(56),
            minInclusive: false,
            max: _hours(60),
            severity: EuSeverity.minor,
            fineTl: PenaltyCalculator.weeklyUpToFourHoursTl,
          ),
          SeverityBand(
            min: _hours(60),
            max: _hours(65),
            severity: EuSeverity.serious,
            fineTl: PenaltyCalculator.weeklyFourToFifteenHoursTl,
          ),
          SeverityBand(
            min: _hours(65),
            max: _hours(70),
            severity: EuSeverity.verySerious,
            fineTl: PenaltyCalculator.weeklyFourToFifteenHoursTl,
          ),
          SeverityBand(
            min: _hours(70),
            max: _hours(71),
            severity: EuSeverity.mostSerious,
            fineTl: PenaltyCalculator.weeklyFourToFifteenHoursTl,
          ),
          SeverityBand(
            min: _hours(71),
            severity: EuSeverity.mostSerious,
            fineTl: PenaltyCalculator.weeklyFifteenHoursOrMoreTl,
          ),
        ],
      ),
      SeverityRule(
        titleKey: 'analysis.sevRuleBiWeekly',
        bands: [
          SeverityBand(
            min: _hours(90),
            minInclusive: false,
            max: _hours(94),
            maxInclusive: true,
            severity: EuSeverity.minor,
            fineTl: PenaltyCalculator.weeklyUpToFourHoursTl,
          ),
          SeverityBand(
            min: _hours(94),
            minInclusive: false,
            max: _hours(100),
            severity: EuSeverity.minor,
            fineTl: PenaltyCalculator.weeklyFourToFifteenHoursTl,
          ),
          SeverityBand(
            min: _hours(100),
            max: _hours(105),
            severity: EuSeverity.serious,
            fineTl: PenaltyCalculator.weeklyFourToFifteenHoursTl,
          ),
          SeverityBand(
            min: _hours(105),
            max: _hours(112, 30),
            severity: EuSeverity.verySerious,
            fineTl: PenaltyCalculator.weeklyFifteenHoursOrMoreTl,
          ),
          SeverityBand(
            min: _hours(112, 30),
            severity: EuSeverity.mostSerious,
            fineTl: PenaltyCalculator.weeklyFifteenHoursOrMoreTl,
          ),
        ],
      ),
    ],
  ),
  SeverityGroup(
    titleKey: 'analysis.sevGroupBreaks',
    rules: [
      // KTK 49/3-a: up to 1h over (5h30) → a-1, more → a-2.
      SeverityRule(
        titleKey: 'analysis.sevRuleContinuous',
        bands: [
          SeverityBand(
            min: _hours(4, 30),
            minInclusive: false,
            max: _hours(5),
            severity: EuSeverity.minor,
            fineTl: PenaltyCalculator.continuousUpToOneHourTl,
          ),
          SeverityBand(
            min: _hours(5),
            max: _hours(5, 30),
            maxInclusive: true,
            severity: EuSeverity.serious,
            fineTl: PenaltyCalculator.continuousUpToOneHourTl,
          ),
          SeverityBand(
            min: _hours(5, 30),
            minInclusive: false,
            max: _hours(6),
            severity: EuSeverity.serious,
            fineTl: PenaltyCalculator.continuousOverOneHourTl,
          ),
          SeverityBand(
            min: _hours(6),
            severity: EuSeverity.verySerious,
            fineTl: PenaltyCalculator.continuousOverOneHourTl,
          ),
        ],
      ),
    ],
  ),
  SeverityGroup(
    titleKey: 'analysis.sevGroupRest',
    rules: [
      SeverityRule(
        titleKey: 'analysis.sevRuleDailyRest11',
        bands: [
          SeverityBand(
            min: _hours(10),
            max: _hours(11),
            severity: EuSeverity.minor,
            fineTl: _dailyRestFine,
          ),
          SeverityBand(
            min: _hours(8, 30),
            max: _hours(10),
            severity: EuSeverity.serious,
            fineTl: _dailyRestFine,
          ),
          SeverityBand(
            max: _hours(8, 30),
            severity: EuSeverity.verySerious,
            fineTl: _dailyRestFine,
          ),
        ],
      ),
      SeverityRule(
        titleKey: 'analysis.sevRuleDailyRest9',
        bands: _reducedDailyRestBands(),
      ),
      SeverityRule(
        titleKey: 'analysis.sevRuleSplitRest',
        bands: _reducedDailyRestBands(splitFirstPart: _hours(3)),
      ),
      SeverityRule(
        titleKey: 'analysis.sevRuleMultiManning',
        bands: _reducedDailyRestBands(),
      ),
      SeverityRule(
        titleKey: 'analysis.sevRuleReducedWeeklyRest',
        bands: [
          SeverityBand(
            min: _hours(22),
            max: _hours(24),
            severity: EuSeverity.minor,
            fineTl: _weeklyRestFine,
          ),
          SeverityBand(
            min: _hours(20),
            max: _hours(22),
            severity: EuSeverity.serious,
            fineTl: _weeklyRestFine,
          ),
          SeverityBand(
            max: _hours(20),
            severity: EuSeverity.verySerious,
            fineTl: _weeklyRestFine,
          ),
        ],
      ),
      SeverityRule(
        titleKey: 'analysis.sevRuleWeeklyRest45',
        bands: [
          SeverityBand(
            min: _hours(42),
            max: _hours(45),
            severity: EuSeverity.minor,
            fineTl: _weeklyRestFine,
          ),
          SeverityBand(
            min: _hours(36),
            max: _hours(42),
            severity: EuSeverity.serious,
            fineTl: _weeklyRestFine,
          ),
          SeverityBand(
            max: _hours(36),
            severity: EuSeverity.verySerious,
            fineTl: _weeklyRestFine,
          ),
        ],
      ),
      SeverityRule(
        titleKey: 'analysis.sevRuleWeeklyRestLate',
        bands: _delayBands(),
      ),
    ],
  ),
  SeverityGroup(
    titleKey: 'analysis.sevGroup12Day',
    rules: [
      SeverityRule(titleKey: 'analysis.sevRule12Day', bands: _delayBands()),
      SeverityRule(
        titleKey: 'analysis.sevRule12DayRest',
        bands: [
          SeverityBand(
            min: _hours(65),
            minInclusive: false,
            max: _hours(67),
            maxInclusive: true,
            severity: EuSeverity.serious,
            fineTl: _weeklyRestFine,
          ),
          SeverityBand(
            max: _hours(65),
            maxInclusive: true,
            severity: EuSeverity.verySerious,
            fineTl: _weeklyRestFine,
          ),
        ],
      ),
      SeverityRule(
        titleKey: 'analysis.sevRuleNightDriving',
        bands: [
          SeverityBand(
            min: _hours(3),
            minInclusive: false,
            max: _hours(4, 30),
            severity: EuSeverity.serious,
            fineNoteKey: 'analysis.sevNoTrPenalty',
          ),
          SeverityBand(
            min: _hours(4, 30),
            severity: EuSeverity.verySerious,
            fineTl: PenaltyCalculator.continuousOverOneHourTl,
          ),
        ],
      ),
    ],
  ),
  SeverityGroup(
    titleKey: 'analysis.sevGroupWork',
    rules: [
      SeverityRule(
        titleKey: 'analysis.sevRuleWageLink',
        bands: [
          SeverityBand(
            severity: EuSeverity.verySerious,
            fineNoteKey: 'analysis.sevNoTrPenalty',
          ),
        ],
      ),
      SeverityRule(
        titleKey: 'analysis.sevRuleWorkOrganisation',
        bands: [
          SeverityBand(
            severity: EuSeverity.verySerious,
            fineNoteKey: 'analysis.sevOperatorDoubleOnly',
          ),
        ],
      ),
    ],
  ),
];
