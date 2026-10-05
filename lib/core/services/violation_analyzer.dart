import 'driving_time_calculator.dart';

enum ViolationType {
  continuousDrivingExceeded,
  dailyDrivingExceeded,
  weeklyDrivingExceeded,
  biWeeklyDrivingExceeded,
  dailyRestInsufficient,
  weeklyRestInsufficient,
  missingRecord,
}

enum ViolationSeverity { warning, violation }

/// Infringement category from Commission Regulation (EU) 2016/403, Annex I.
enum EuSeverity { minor, serious, verySerious, mostSerious }

extension EuSeverityCode on EuSeverity {
  String get code => switch (this) {
    EuSeverity.minor => 'MI',
    EuSeverity.serious => 'SI',
    EuSeverity.verySerious => 'VSI',
    EuSeverity.mostSerious => 'MSI',
  };
}

class Violation {
  final ViolationType type;
  final ViolationSeverity severity;
  final DateTime start;
  final DateTime end;

  final String descriptionKey;

  final String ruleReference;

  final Duration? excessDuration;

  /// EU 2016/403 category, or null when the violation has none (missing
  /// records).
  final EuSeverity? euSeverity;

  const Violation({
    required this.type,
    required this.severity,
    required this.start,
    required this.end,
    required this.descriptionKey,
    required this.ruleReference,
    this.excessDuration,
    this.euSeverity,
  });

  Duration get duration => end.difference(start);
}

class ActivityGap {
  final DateTime start;
  final DateTime end;

  const ActivityGap({required this.start, required this.end});

  Duration get duration => end.difference(start);
}

/// A continuous stretch of rest (or of unrecorded time, see [_restBlocks]).
class _RestBlock {
  final DateTime start;
  DateTime end;

  _RestBlock(this.start, this.end);

  Duration get length => end.difference(start);
}

typedef _BlockInWindow = ({_RestBlock block, Duration overlap});

class ViolationAnalyzer {
  static const Duration minDailyRest = Duration(hours: 11);
  static const Duration reducedDailyRest = Duration(hours: 9);
  static const Duration splitRestFirstPart = Duration(hours: 3);
  static const int maxReducedDailyRestsBetweenWeeklyRests = 3;
  static const Duration minWeeklyRest = Duration(hours: 45);
  static const Duration reducedWeeklyRest = Duration(hours: 24);

  /// Art. 8.6: a weekly rest must start within six 24h periods of the end of
  /// the previous one.
  static const Duration weeklyRestDeadline = Duration(hours: 6 * 24);

  final DrivingTimeCalculator _calculator = DrivingTimeCalculator();

  List<Violation> analyze(List<TachographActivity> activities, DateTime now) {
    final violations = <Violation>[];
    if (activities.isEmpty) return violations;

    final sorted = _mergeContiguous(
      activities.where((a) => !a.startTime.isAfter(now)).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime)),
    );
    if (sorted.isEmpty) return violations;

    for (final w in _calculator.continuousExceededWindows(sorted, now)) {
      violations.add(
        Violation(
          type: ViolationType.continuousDrivingExceeded,
          severity: ViolationSeverity.violation,
          start: w.start,
          end: w.end,
          descriptionKey: 'violation.continuousDrivingExceeded',
          ruleReference: 'EU 561/2006 Art. 7',
          excessDuration: w.excess,
          euSeverity: continuousDrivingSeverity(w.total),
        ),
      );
    }
    for (final w in _calculator.dailyExceededWindows(sorted, now)) {
      final extended =
          w.limit == DrivingTimeCalculator.extendedDailyDrivingLimit;
      violations.add(
        Violation(
          type: ViolationType.dailyDrivingExceeded,
          severity: ViolationSeverity.violation,
          start: w.start,
          end: w.end,
          descriptionKey: extended
              ? 'violation.dailyDrivingExceededExtended'
              : 'violation.dailyDrivingExceeded',
          ruleReference: 'EU 561/2006 Art. 6.1',
          excessDuration: w.excess,
          euSeverity: dailyDrivingSeverity(w.total, limit: w.limit),
        ),
      );
    }
    final weeks = _calculator.weeklyExceededWindows(sorted, now);
    for (final w in weeks.weekly) {
      violations.add(
        Violation(
          type: ViolationType.weeklyDrivingExceeded,
          severity: ViolationSeverity.violation,
          start: w.start,
          end: w.end,
          descriptionKey: 'violation.weeklyDrivingExceeded',
          ruleReference: 'EU 561/2006 Art. 6.2',
          excessDuration: w.excess,
          euSeverity: weeklyDrivingSeverity(w.total),
        ),
      );
    }
    for (final w in weeks.biWeekly) {
      violations.add(
        Violation(
          type: ViolationType.biWeeklyDrivingExceeded,
          severity: ViolationSeverity.violation,
          start: w.start,
          end: w.end,
          descriptionKey: 'violation.biWeeklyDrivingExceeded',
          ruleReference: 'EU 561/2006 Art. 6.3',
          excessDuration: w.excess,
          euSeverity: biWeeklyDrivingSeverity(w.total),
        ),
      );
    }

    final restBlocks = _restBlocks(sorted, now);
    violations.addAll(_checkDailyRest(sorted, restBlocks, now));
    violations.addAll(_checkWeeklyRest(sorted, restBlocks, now));

    for (final gap in detectGaps(sorted)) {
      violations.add(
        Violation(
          type: ViolationType.missingRecord,
          severity: ViolationSeverity.warning,
          start: gap.start,
          end: gap.end,
          descriptionKey: 'violation.missingRecord',
          ruleReference: 'EU 561/2006 Art. 15',
        ),
      );
    }

    for (final act in sorted) {
      if (act.type != ActivityType.unknown) continue;
      violations.add(
        Violation(
          type: ViolationType.missingRecord,
          severity: ViolationSeverity.warning,
          start: act.startTime,
          end: act.endTime,
          descriptionKey: 'violation.missingRecord',
          ruleReference: 'EU 561/2006 Art. 15',
        ),
      );
    }

    violations.sort((a, b) => b.start.compareTo(a.start));
    return violations;
  }

  List<Violation> analyzeLiveRules(
    Map<String, DrivingRuleResult> rules,
    DateTime now,
  ) {
    final violations = <Violation>[];
    void addIfExceeded(
      String key,
      ViolationType type,
      String descriptionKey,
      String ruleReference,
      EuSeverity Function(Duration used) severityOf,
    ) {
      final result = rules[key];
      if (result == null || !result.isExceeded) return;

      final overage = result.used - result.limit;
      final start = overage.isNegative ? now : now.subtract(overage);
      violations.add(
        Violation(
          type: type,
          severity: ViolationSeverity.violation,
          start: start,
          end: now,
          descriptionKey: descriptionKey,
          ruleReference: ruleReference,
          excessDuration: overage.isNegative ? Duration.zero : overage,
          euSeverity: severityOf(result.used),
        ),
      );
    }

    addIfExceeded(
      'continuous',
      ViolationType.continuousDrivingExceeded,
      'violation.continuousDrivingExceeded',
      'EU 561/2006 Art. 7',
      continuousDrivingSeverity,
    );
    addIfExceeded(
      'daily',
      ViolationType.dailyDrivingExceeded,
      'violation.dailyDrivingExceeded',
      'EU 561/2006 Art. 6.1',
      (used) => dailyDrivingSeverity(
        used,
        limit: DrivingTimeCalculator.dailyDrivingLimit,
      ),
    );
    addIfExceeded(
      'weekly',
      ViolationType.weeklyDrivingExceeded,
      'violation.weeklyDrivingExceeded',
      'EU 561/2006 Art. 6.2',
      weeklyDrivingSeverity,
    );
    addIfExceeded(
      'bi_weekly',
      ViolationType.biWeeklyDrivingExceeded,
      'violation.biWeeklyDrivingExceeded',
      'EU 561/2006 Art. 6.3',
      biWeeklyDrivingSeverity,
    );
    return violations;
  }

  // -------------------------------------------------------------------------
  // EU 2016/403 Annex I categories. Thresholds follow the "Ceza Listesi"
  // sheet of Takograf_Ceza_Listesi_2026.xlsx; anything above the legal limit
  // but below the SI threshold is a minor infringement (MI).
  // -------------------------------------------------------------------------

  /// [driven] is the uninterrupted driving time (limit 4h30).
  static EuSeverity continuousDrivingSeverity(Duration driven) {
    if (driven >= const Duration(hours: 6)) return EuSeverity.verySerious;
    if (driven >= const Duration(hours: 5)) return EuSeverity.serious;
    return EuSeverity.minor;
  }

  /// [driven] is the day's driving time; [limit] is 9h, or 10h on an
  /// extended day.
  static EuSeverity dailyDrivingSeverity(
    Duration driven, {
    required Duration limit,
  }) {
    if (driven >= limit * 1.5) return EuSeverity.mostSerious;
    if (driven >= limit + const Duration(hours: 2)) {
      return EuSeverity.verySerious;
    }
    if (driven >= limit + const Duration(hours: 1)) return EuSeverity.serious;
    return EuSeverity.minor;
  }

  static EuSeverity weeklyDrivingSeverity(Duration driven) {
    if (driven >= const Duration(hours: 70)) return EuSeverity.mostSerious;
    if (driven >= const Duration(hours: 65)) return EuSeverity.verySerious;
    if (driven >= const Duration(hours: 60)) return EuSeverity.serious;
    return EuSeverity.minor;
  }

  static EuSeverity biWeeklyDrivingSeverity(Duration driven) {
    if (driven >= const Duration(hours: 112, minutes: 30)) {
      return EuSeverity.mostSerious;
    }
    if (driven >= const Duration(hours: 105)) return EuSeverity.verySerious;
    if (driven >= const Duration(hours: 100)) return EuSeverity.serious;
    return EuSeverity.minor;
  }

  /// [rest] is the longest rest taken in the 24h period. [reducible] is true
  /// when a reduced (9h) or split (3h + 9h) rest was allowed, false when a
  /// regular 11h rest was required.
  static EuSeverity dailyRestSeverity(
    Duration rest, {
    required bool reducible,
  }) {
    if (reducible) {
      if (rest >= const Duration(hours: 8)) return EuSeverity.minor;
      if (rest >= const Duration(hours: 7)) return EuSeverity.serious;
      return EuSeverity.verySerious;
    }
    if (rest >= const Duration(hours: 10)) return EuSeverity.minor;
    if (rest >= const Duration(hours: 8, minutes: 30)) {
      return EuSeverity.serious;
    }
    return EuSeverity.verySerious;
  }

  /// A reduced weekly rest of [rest] taken when a regular 45h one was due.
  static EuSeverity weeklyRestShortSeverity(Duration rest) {
    if (rest >= const Duration(hours: 42)) return EuSeverity.minor;
    if (rest >= const Duration(hours: 36)) return EuSeverity.serious;
    return EuSeverity.verySerious;
  }

  /// A weekly rest started [delay] after the six-24h-period deadline.
  static EuSeverity weeklyRestDelaySeverity(Duration delay) {
    if (delay >= const Duration(hours: 12)) return EuSeverity.verySerious;
    if (delay >= const Duration(hours: 3)) return EuSeverity.serious;
    return EuSeverity.minor;
  }

  // -------------------------------------------------------------------------
  // Rest periods
  // -------------------------------------------------------------------------

  /// Joins back-to-back records of the same activity, so a rest split across
  /// several records is judged by its real length.
  static List<TachographActivity> _mergeContiguous(
    List<TachographActivity> sorted,
  ) {
    final merged = <TachographActivity>[];
    for (final a in sorted) {
      final last = merged.isEmpty ? null : merged.last;
      if (last != null &&
          last.type == a.type &&
          last.slot == a.slot &&
          !a.startTime.isAfter(last.endTime)) {
        if (a.endTime.isAfter(last.endTime)) {
          merged[merged.length - 1] = TachographActivity(
            type: last.type,
            startTime: last.startTime,
            endTime: a.endTime,
            isManualEntry: last.isManualEntry,
            note: last.note,
            isCrew: last.isCrew,
            slot: last.slot,
            cardInserted: last.cardInserted,
            recordPresenceCounter: last.recordPresenceCounter,
          );
        }
        continue;
      }
      merged.add(a);
    }
    return merged;
  }

  /// Rest as continuous blocks, up to [now]. Unrecorded time (gaps between
  /// records, unknown activities, and the time since the last record) is
  /// counted as rest: missing data must never produce a rest fine. It is
  /// reported separately as a missing record.
  static List<_RestBlock> _restBlocks(
    List<TachographActivity> sorted,
    DateTime now,
  ) {
    final blocks = <_RestBlock>[];
    void addRest(DateTime start, DateTime end) {
      if (!end.isAfter(start)) return;
      if (blocks.isNotEmpty && !start.isAfter(blocks.last.end)) {
        if (end.isAfter(blocks.last.end)) blocks.last.end = end;
        return;
      }
      blocks.add(_RestBlock(start, end));
    }

    DateTime? cursor;
    for (final a in sorted) {
      final end = a.endTime.isAfter(now) ? now : a.endTime;
      final c = cursor;
      if (c != null && a.startTime.isAfter(c)) addRest(c, a.startTime);
      if (a.type == ActivityType.rest || a.type == ActivityType.unknown) {
        addRest(a.startTime, end);
      }
      if (c == null || end.isAfter(c)) cursor = end;
    }
    final c = cursor;
    if (c != null && now.isAfter(c)) addRest(c, now);
    return blocks;
  }

  static bool _isRestLike(TachographActivity a) =>
      a.type == ActivityType.rest || a.type == ActivityType.unknown;

  /// Art. 8.2: within each 24h period after the end of the previous daily or
  /// weekly rest, a new daily rest must be taken: 11h regular, 3h + 9h split,
  /// or 9h reduced (at most 3 times between two weekly rests). Only the part
  /// of a rest that falls inside the 24h period counts. Periods still in
  /// progress at [now] are not judged.
  List<Violation> _checkDailyRest(
    List<TachographActivity> sorted,
    List<_RestBlock> blocks,
    DateTime now,
  ) {
    final violations = <Violation>[];
    final firstWork = sorted.where((a) => !_isRestLike(a)).firstOrNull;
    if (firstWork == null) return violations;

    var periodStart = firstWork.startTime;
    var reducedSinceWeeklyRest = 0;

    while (true) {
      final periodEnd = periodStart.add(const Duration(hours: 24));
      if (periodEnd.isAfter(now)) break;

      final inPeriod = <_BlockInWindow>[];
      for (final b in blocks) {
        if (!b.end.isAfter(periodStart)) continue;
        if (!b.start.isBefore(periodEnd)) break;
        final s = b.start.isBefore(periodStart) ? periodStart : b.start;
        final e = b.end.isAfter(periodEnd) ? periodEnd : b.end;
        inPeriod.add((block: b, overlap: e.difference(s)));
      }

      // The first rest that qualifies ends the period.
      _BlockInWindow? taken;
      var regular = false;
      var hadSplitFirstPart = false;
      for (final x in inPeriod) {
        if (x.overlap >= minDailyRest ||
            (hadSplitFirstPart && x.overlap >= reducedDailyRest)) {
          taken = x;
          regular = true;
          break;
        }
        if (x.overlap >= reducedDailyRest) {
          taken = x;
          break;
        }
        if (x.overlap >= splitRestFirstPart) hadSplitFirstPart = true;
      }

      if (taken == null) {
        // No rest long enough: the longest one (latest on ties) stands as the
        // insufficient daily rest.
        for (final x in inPeriod) {
          if (taken == null || x.overlap >= taken.overlap) taken = x;
        }
        final rest = taken?.overlap ?? Duration.zero;
        var hadFirstPartBefore = false;
        for (final x in inPeriod) {
          if (identical(x.block, taken?.block)) break;
          if (x.overlap >= splitRestFirstPart) hadFirstPartBefore = true;
        }
        final reducible =
            reducedSinceWeeklyRest < maxReducedDailyRestsBetweenWeeklyRests ||
            hadFirstPartBefore;
        violations.add(
          _dailyRestViolation(
            start: taken?.block.start ?? periodEnd,
            end: taken?.block.end ?? periodEnd,
            rest: rest,
            reducible: reducible,
          ),
        );
      } else if (!regular) {
        if (reducedSinceWeeklyRest < maxReducedDailyRestsBetweenWeeklyRests) {
          reducedSinceWeeklyRest++;
        } else {
          violations.add(
            _dailyRestViolation(
              start: taken.block.start,
              end: taken.block.end,
              rest: taken.overlap,
              reducible: false,
            ),
          );
        }
      }

      // The next period starts when this period's rest ends. A rest shorter
      // than 3h is only a break, so then the next real rest ends it instead;
      // this keeps one long stretch without rest from being counted twice.
      _RestBlock? closing = taken?.block;
      if (closing == null || closing.length < splitRestFirstPart) {
        closing = blocks
            .where(
              (b) =>
                  b.end.isAfter(periodStart) && b.length >= splitRestFirstPart,
            )
            .firstOrNull;
        if (closing == null) break;
      }
      if (closing.length >= reducedWeeklyRest) reducedSinceWeeklyRest = 0;
      periodStart = closing.end.isAfter(periodStart) ? closing.end : periodEnd;
    }
    return violations;
  }

  Violation _dailyRestViolation({
    required DateTime start,
    required DateTime end,
    required Duration rest,
    required bool reducible,
  }) {
    final needed = reducible ? reducedDailyRest : minDailyRest;
    return Violation(
      type: ViolationType.dailyRestInsufficient,
      severity: ViolationSeverity.violation,
      start: start,
      end: end,
      descriptionKey: 'violation.dailyRestInsufficient',
      ruleReference: 'EU 561/2006 Art. 8.2',
      excessDuration: needed - rest,
      euSeverity: dailyRestSeverity(rest, reducible: reducible),
    );
  }

  /// Art. 8.6: a weekly rest (45h regular, 24h reduced) must start no later
  /// than six 24h periods after the previous one ended, and two reduced
  /// weekly rests may not follow each other. The first period is counted
  /// from the start of the data, so its deadline is never earlier than the
  /// real one.
  List<Violation> _checkWeeklyRest(
    List<TachographActivity> sorted,
    List<_RestBlock> blocks,
    DateTime now,
  ) {
    final violations = <Violation>[];
    final firstWork = sorted.where((a) => !_isRestLike(a)).firstOrNull;
    if (firstWork == null) return violations;

    final weeklyRests = blocks
        .where((b) => b.length >= reducedWeeklyRest)
        .toList();
    // A rest still going on at [now] may yet turn into a weekly rest.
    final ongoing = blocks.isNotEmpty && !blocks.last.end.isBefore(now)
        ? blocks.last
        : null;

    var periodStart = firstWork.startTime;
    var previousWasReduced = false;

    while (true) {
      final deadline = periodStart.add(weeklyRestDeadline);
      final next = weeklyRests
          .where((b) => !b.start.isBefore(periodStart))
          .firstOrNull;
      final restStart =
          next?.start ??
          (ongoing != null && !ongoing.start.isBefore(periodStart)
              ? ongoing.start
              : now);

      if (restStart.isAfter(deadline)) {
        final delay = restStart.difference(deadline);
        violations.add(
          Violation(
            type: ViolationType.weeklyRestInsufficient,
            severity: ViolationSeverity.violation,
            start: deadline,
            end: restStart,
            descriptionKey: 'violation.weeklyRestDelayed',
            ruleReference: 'EU 561/2006 Art. 8.6',
            excessDuration: delay,
            euSeverity: weeklyRestDelaySeverity(delay),
          ),
        );
      }
      if (next == null) break;

      final stillGoing = !next.end.isBefore(now);
      if (!stillGoing) {
        if (next.length < minWeeklyRest) {
          if (previousWasReduced) {
            violations.add(
              Violation(
                type: ViolationType.weeklyRestInsufficient,
                severity: ViolationSeverity.violation,
                start: next.start,
                end: next.end,
                descriptionKey: 'violation.weeklyRestNotRegular',
                ruleReference: 'EU 561/2006 Art. 8.6',
                excessDuration: minWeeklyRest - next.length,
                euSeverity: weeklyRestShortSeverity(next.length),
              ),
            );
          }
          previousWasReduced = true;
        } else {
          previousWasReduced = false;
        }
      }
      if (stillGoing) break;
      periodStart = next.end;
    }
    return violations;
  }

  List<ActivityGap> detectGaps(
    List<TachographActivity> activities, {
    Duration minGap = const Duration(minutes: 30),
  }) {
    if (activities.length < 2) return const [];

    final sorted = List<TachographActivity>.from(activities)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final gaps = <ActivityGap>[];
    for (int i = 0; i < sorted.length - 1; i++) {
      final gapStart = sorted[i].endTime;
      final gapEnd = sorted[i + 1].startTime;
      if (gapEnd.isAfter(gapStart) && gapEnd.difference(gapStart) >= minGap) {
        gaps.add(ActivityGap(start: gapStart, end: gapEnd));
      }
    }
    return gaps;
  }
}
