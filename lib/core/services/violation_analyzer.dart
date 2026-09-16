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

class Violation {
  final ViolationType type;
  final ViolationSeverity severity;
  final DateTime start;
  final DateTime end;

  final String descriptionKey;

  final String ruleReference;

  final Duration? excessDuration;

  const Violation({
    required this.type,
    required this.severity,
    required this.start,
    required this.end,
    required this.descriptionKey,
    required this.ruleReference,
    this.excessDuration,
  });

  Duration get duration => end.difference(start);
}

class ActivityGap {
  final DateTime start;
  final DateTime end;

  const ActivityGap({required this.start, required this.end});

  Duration get duration => end.difference(start);
}

class ViolationAnalyzer {
  static const Duration minDailyRest = Duration(hours: 11);
  static const Duration reducedDailyRest = Duration(hours: 9);
  static const Duration minWeeklyRest = Duration(hours: 45);
  static const Duration reducedWeeklyRest = Duration(hours: 24);

  final DrivingTimeCalculator _calculator = DrivingTimeCalculator();

  List<Violation> analyze(List<TachographActivity> activities, DateTime now) {
    final violations = <Violation>[];
    if (activities.isEmpty) return violations;

    final sorted = activities.where((a) => !a.startTime.isAfter(now)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (sorted.isEmpty) return violations;

    final rules = _calculator.calculate(sorted, now);
    final startTimes = _calculator.violationStartTimes(sorted, now);

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
        ),
      );
    }
    for (final w in _calculator.dailyExceededWindows(sorted, now)) {
      violations.add(
        Violation(
          type: ViolationType.dailyDrivingExceeded,
          severity: ViolationSeverity.violation,
          start: w.start,
          end: w.end,
          descriptionKey: 'violation.dailyDrivingExceeded',
          ruleReference: 'EU 561/2006 Art. 6.1',
          excessDuration: w.excess,
        ),
      );
    }
    _addIfExceeded(
      violations,
      rules['weekly'],
      startTimes['weekly'],
      ViolationType.weeklyDrivingExceeded,
      'violation.weeklyDrivingExceeded',
      'EU 561/2006 Art. 6.2',
      sorted,
      now,
    );
    _addIfExceeded(
      violations,
      rules['bi_weekly'],
      startTimes['bi_weekly'],
      ViolationType.biWeeklyDrivingExceeded,
      'violation.biWeeklyDrivingExceeded',
      'EU 561/2006 Art. 6.3',
      sorted,
      now,
    );

    violations.addAll(_checkDailyRest(sorted, now));
    violations.addAll(_checkWeeklyRest(sorted, now));

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
        ),
      );
    }

    addIfExceeded(
      'continuous',
      ViolationType.continuousDrivingExceeded,
      'violation.continuousDrivingExceeded',
      'EU 561/2006 Art. 7',
    );
    addIfExceeded(
      'daily',
      ViolationType.dailyDrivingExceeded,
      'violation.dailyDrivingExceeded',
      'EU 561/2006 Art. 6.1',
    );
    addIfExceeded(
      'weekly',
      ViolationType.weeklyDrivingExceeded,
      'violation.weeklyDrivingExceeded',
      'EU 561/2006 Art. 6.2',
    );
    addIfExceeded(
      'bi_weekly',
      ViolationType.biWeeklyDrivingExceeded,
      'violation.biWeeklyDrivingExceeded',
      'EU 561/2006 Art. 6.3',
    );
    return violations;
  }

  void _addIfExceeded(
    List<Violation> out,
    DrivingRuleResult? result,
    DateTime? crossingTime,
    ViolationType type,
    String descriptionKey,
    String ruleReference,
    List<TachographActivity> sorted,
    DateTime now,
  ) {
    if (result == null || !result.isExceeded) return;
    out.add(
      Violation(
        type: type,
        severity: ViolationSeverity.violation,

        start:
            crossingTime ?? (sorted.isNotEmpty ? sorted.first.startTime : now),
        end: now,
        descriptionKey: descriptionKey,
        ruleReference: ruleReference,
        excessDuration: result.used - result.limit,
      ),
    );
  }

  List<Violation> _checkDailyRest(
    List<TachographActivity> sorted,
    DateTime now,
  ) {
    final violations = <Violation>[];
    TachographActivity? lastDriving;

    for (final act in sorted) {
      if (act.type == ActivityType.rest && lastDriving != null) {
        if (act.duration < reducedDailyRest) {
          violations.add(
            Violation(
              type: ViolationType.dailyRestInsufficient,
              severity: ViolationSeverity.violation,
              start: act.startTime,
              end: act.endTime,
              descriptionKey: 'violation.dailyRestInsufficient',
              ruleReference: 'EU 561/2006 Art. 8.2',
              excessDuration: reducedDailyRest - act.duration,
            ),
          );
        }
      }
      if (act.type == ActivityType.driving) lastDriving = act;
    }
    return violations;
  }

  List<Violation> _checkWeeklyRest(
    List<TachographActivity> sorted,
    DateTime now,
  ) {
    if (sorted.isEmpty) return const [];

    final weekStart = now.subtract(const Duration(days: 7));
    final restsThisWeek = sorted.where(
      (a) => a.type == ActivityType.rest && a.endTime.isAfter(weekStart),
    );
    final hasDrivingThisWeek = sorted.any(
      (a) => a.type == ActivityType.driving && a.endTime.isAfter(weekStart),
    );
    if (!hasDrivingThisWeek) return const [];

    final longestRest = restsThisWeek.fold<Duration>(
      Duration.zero,
      (max, a) => a.duration > max ? a.duration : max,
    );

    if (longestRest < reducedWeeklyRest) {
      return [
        Violation(
          type: ViolationType.weeklyRestInsufficient,
          severity: ViolationSeverity.violation,
          start: weekStart,
          end: now,
          descriptionKey: 'violation.weeklyRestInsufficient',
          ruleReference: 'EU 561/2006 Art. 8.6',
          excessDuration: reducedWeeklyRest - longestRest,
        ),
      ];
    }
    return const [];
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
