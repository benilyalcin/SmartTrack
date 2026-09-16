enum ActivityType { driving, rest, available, work, unknown }

enum DriverSlot { driver, coDriver }

class TachographActivity {
  final ActivityType type;
  final DateTime startTime;
  final DateTime endTime;

  final bool isManualEntry;

  final String? note;

  final bool isCrew;

  final DriverSlot slot;

  final bool cardInserted;

  final int? recordPresenceCounter;

  TachographActivity({
    required this.type,
    required this.startTime,
    required this.endTime,
    this.isManualEntry = false,
    this.note,
    this.isCrew = false,
    this.slot = DriverSlot.driver,
    this.cardInserted = true,
    this.recordPresenceCounter,
  });

  Duration get duration => endTime.difference(startTime);
}

class DrivingRuleResult {
  final Duration used;
  final Duration limit;

  DrivingRuleResult({required this.used, required this.limit});

  Duration get remaining {
    final rem = limit - used;
    return rem.isNegative ? Duration.zero : rem;
  }

  bool get isExceeded => used >= limit;

  bool get isWarning => remaining <= const Duration(minutes: 30) && !isExceeded;
}

class LimitExceededWindow {
  final DateTime start;
  final DateTime end;
  final Duration excess;
  const LimitExceededWindow({
    required this.start,
    required this.end,
    required this.excess,
  });
}

class DrivingTimeCalculator {
  static const Duration continuousDrivingLimit = Duration(
    hours: 4,
    minutes: 30,
  );
  static const Duration dailyDrivingLimit = Duration(hours: 9);
  static const Duration weeklyDrivingLimit = Duration(hours: 56);
  static const Duration biWeeklyDrivingLimit = Duration(hours: 90);

  Map<String, DrivingRuleResult> calculate(
    List<TachographActivity> activities,
    DateTime currentTime,
  ) {
    final sortedActivities = _activitiesUpTo(activities, currentTime);

    return {
      'continuous': _calculateContinuous(sortedActivities, currentTime),
      'daily': _calculateDaily(sortedActivities, currentTime),
      'weekly': _calculateWeekly(sortedActivities, currentTime),
      'bi_weekly': _calculateBiWeekly(sortedActivities, currentTime),
    };
  }

  List<TachographActivity> _activitiesUpTo(
    List<TachographActivity> activities,
    DateTime currentTime,
  ) {
    return activities.where((a) => !a.startTime.isAfter(currentTime)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  DrivingRuleResult _calculateContinuous(
    List<TachographActivity> activities,
    DateTime currentTime,
  ) {
    Duration currentContinuous = Duration.zero;
    final pendingRests = <Duration>[];

    for (final act in activities) {
      if (act.type == ActivityType.driving) {
        currentContinuous += act.duration;
      } else if (act.type == ActivityType.rest) {
        pendingRests.add(act.duration);
        if (satisfiesArticle7BreakRequirement(pendingRests)) {
          currentContinuous = Duration.zero;
          pendingRests.clear();
        }
      }
    }

    return DrivingRuleResult(
      used: currentContinuous,
      limit: continuousDrivingLimit,
    );
  }

  bool hasQualifyingPendingFirstHalf(
    List<TachographActivity> activities,
    DateTime currentTime,
  ) {
    final pendingRests = <Duration>[];
    for (final act in activities) {
      if (act.type == ActivityType.rest) {
        pendingRests.add(act.duration);
        if (satisfiesArticle7BreakRequirement(pendingRests))
          pendingRests.clear();
      }
    }
    return pendingRests.any((d) => d >= const Duration(minutes: 15));
  }

  bool hasIncompleteBreakAttempt(
    List<TachographActivity> activities,
    DateTime currentTime,
  ) {
    final pendingRests = <Duration>[];
    for (final act in activities) {
      if (act.type == ActivityType.rest) {
        pendingRests.add(act.duration);
        if (satisfiesArticle7BreakRequirement(pendingRests))
          pendingRests.clear();
      }
    }
    return pendingRests.isNotEmpty;
  }

  static bool segmentsFullyCoverRange(
    List<TachographActivity> segments,
    DateTime start,
    DateTime end,
  ) {
    if (segments.isEmpty) return false;
    final sorted = List<TachographActivity>.from(segments)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (sorted.first.startTime.isAfter(start)) return false;
    var coveredUntil = sorted.first.endTime;
    for (final segment in sorted.skip(1)) {
      if (segment.startTime.isAfter(coveredUntil)) return false;
      if (segment.endTime.isAfter(coveredUntil)) coveredUntil = segment.endTime;
    }
    return !coveredUntil.isBefore(end);
  }

  static bool satisfiesArticle7BreakRequirement(
    List<Duration> restDurationsInOrder,
  ) {
    for (final d in restDurationsInOrder) {
      if (d >= const Duration(minutes: 45)) return true;
    }
    for (int i = 0; i < restDurationsInOrder.length; i++) {
      if (restDurationsInOrder[i] < const Duration(minutes: 15)) continue;
      for (int j = i + 1; j < restDurationsInOrder.length; j++) {
        if (restDurationsInOrder[j] >= const Duration(minutes: 30)) return true;
      }
    }
    return false;
  }

  DrivingRuleResult _calculateDaily(
    List<TachographActivity> activities,
    DateTime currentTime,
  ) {
    Duration currentDaily = Duration.zero;

    for (int i = activities.length - 1; i >= 0; i--) {
      final act = activities[i];

      if (act.type == ActivityType.rest &&
          act.duration >= const Duration(hours: 9)) {
        break;
      }

      if (act.type == ActivityType.driving) {
        currentDaily += act.duration;
      }
    }

    return DrivingRuleResult(used: currentDaily, limit: dailyDrivingLimit);
  }

  Duration compensationDeadlineRemaining(int weeksAgo, DateTime currentTime) {
    final daysSinceMonday = currentTime.weekday - DateTime.monday;
    final startOfCurrentWeek = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    ).subtract(Duration(days: daysSinceMonday));
    final deadline = startOfCurrentWeek.add(Duration(days: (3 - weeksAgo) * 7));
    final remaining = deadline.difference(currentTime);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  DrivingRuleResult _calculateWeekly(
    List<TachographActivity> activities,
    DateTime currentTime,
  ) {
    int daysSinceMonday = currentTime.weekday - DateTime.monday;
    DateTime startOfWeek = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    ).subtract(Duration(days: daysSinceMonday));

    Duration weeklyTotal = Duration.zero;

    for (final act in activities) {
      if (act.type == ActivityType.driving &&
          act.endTime.isAfter(startOfWeek)) {
        DateTime effectiveStart = act.startTime.isBefore(startOfWeek)
            ? startOfWeek
            : act.startTime;
        weeklyTotal += act.endTime.difference(effectiveStart);
      }
    }

    return DrivingRuleResult(used: weeklyTotal, limit: weeklyDrivingLimit);
  }

  DrivingRuleResult _calculateBiWeekly(
    List<TachographActivity> activities,
    DateTime currentTime,
  ) {
    int daysSinceMonday = currentTime.weekday - DateTime.monday;
    DateTime startOfThisWeek = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    ).subtract(Duration(days: daysSinceMonday));
    DateTime startOfPreviousWeek = startOfThisWeek.subtract(
      const Duration(days: 7),
    );

    Duration biWeeklyTotal = Duration.zero;

    for (final act in activities) {
      if (act.type == ActivityType.driving &&
          act.endTime.isAfter(startOfPreviousWeek)) {
        DateTime effectiveStart = act.startTime.isBefore(startOfPreviousWeek)
            ? startOfPreviousWeek
            : act.startTime;
        biWeeklyTotal += act.endTime.difference(effectiveStart);
      }
    }

    return DrivingRuleResult(used: biWeeklyTotal, limit: biWeeklyDrivingLimit);
  }

  List<LimitExceededWindow> continuousExceededWindows(
    List<TachographActivity> activities,
    DateTime currentTime,
  ) {
    final sorted = _activitiesUpTo(activities, currentTime);
    Duration currentContinuous = Duration.zero;
    final pendingRests = <Duration>[];
    DateTime? crossing;
    final windows = <LimitExceededWindow>[];
    DateTime? cursor;

    void closeOpenEpisode(DateTime at) {
      if (crossing != null && currentContinuous >= continuousDrivingLimit) {
        windows.add(
          LimitExceededWindow(
            start: crossing!,
            end: at,
            excess: currentContinuous - continuousDrivingLimit,
          ),
        );
      }
      currentContinuous = Duration.zero;
      pendingRests.clear();
      crossing = null;
    }

    for (final act in sorted) {
      final gapSince = cursor;
      if (gapSince != null && act.startTime.isAfter(gapSince))
        closeOpenEpisode(gapSince);
      if (act.type == ActivityType.unknown) {
        closeOpenEpisode(act.startTime);
        cursor = act.endTime;
        continue;
      }
      if (act.type == ActivityType.driving) {
        crossing ??= _crossingInstant(
          act.startTime,
          act.duration,
          currentContinuous,
          continuousDrivingLimit,
        );
        currentContinuous += act.duration;
      } else if (act.type == ActivityType.rest) {
        final priorPending = List<Duration>.of(pendingRests);
        pendingRests.add(act.duration);
        if (satisfiesArticle7BreakRequirement(pendingRests)) {
          closeOpenEpisode(_article7ResolutionInstant(act, priorPending));
        }
      }
      cursor = act.endTime;
    }

    final trailingGap = cursor;
    final effectiveEnd =
        (trailingGap != null &&
            currentTime.difference(trailingGap) >= const Duration(minutes: 30))
        ? trailingGap
        : currentTime;
    if (crossing != null && currentContinuous >= continuousDrivingLimit) {
      windows.add(
        LimitExceededWindow(
          start: crossing!,
          end: effectiveEnd,
          excess: currentContinuous - continuousDrivingLimit,
        ),
      );
    }
    return windows;
  }

  List<LimitExceededWindow> dailyExceededWindows(
    List<TachographActivity> activities,
    DateTime currentTime,
  ) {
    final sorted = _activitiesUpTo(activities, currentTime);
    Duration currentDaily = Duration.zero;
    DateTime? crossing;
    final windows = <LimitExceededWindow>[];
    DateTime? cursor;

    void closeOpenEpisode(DateTime at) {
      if (crossing != null && currentDaily >= dailyDrivingLimit) {
        windows.add(
          LimitExceededWindow(
            start: crossing!,
            end: at,
            excess: currentDaily - dailyDrivingLimit,
          ),
        );
      }
      currentDaily = Duration.zero;
      crossing = null;
    }

    for (final act in sorted) {
      final gapSince = cursor;
      if (gapSince != null && act.startTime.isAfter(gapSince))
        closeOpenEpisode(gapSince);
      if (act.type == ActivityType.unknown) {
        closeOpenEpisode(act.startTime);
        cursor = act.endTime;
        continue;
      }
      if (act.type == ActivityType.rest &&
          act.duration >= const Duration(hours: 9)) {
        closeOpenEpisode(act.startTime.add(const Duration(hours: 9)));
        cursor = act.endTime;
        continue;
      }
      if (act.type == ActivityType.driving) {
        crossing ??= _crossingInstant(
          act.startTime,
          act.duration,
          currentDaily,
          dailyDrivingLimit,
        );
        currentDaily += act.duration;
      }
      cursor = act.endTime;
    }

    final trailingGap = cursor;
    final effectiveEnd =
        (trailingGap != null &&
            currentTime.difference(trailingGap) >= const Duration(minutes: 30))
        ? trailingGap
        : currentTime;
    if (crossing != null && currentDaily >= dailyDrivingLimit) {
      windows.add(
        LimitExceededWindow(
          start: crossing!,
          end: effectiveEnd,
          excess: currentDaily - dailyDrivingLimit,
        ),
      );
    }
    return windows;
  }

  static DateTime _article7ResolutionInstant(
    TachographActivity resolvingRest,
    List<Duration> priorPendingRests,
  ) {
    DateTime? single;
    if (resolvingRest.duration >= const Duration(minutes: 45)) {
      single = resolvingRest.startTime.add(const Duration(minutes: 45));
    }
    DateTime? split;
    if (resolvingRest.duration >= const Duration(minutes: 30) &&
        priorPendingRests.any((d) => d >= const Duration(minutes: 15))) {
      split = resolvingRest.startTime.add(const Duration(minutes: 30));
    }
    if (single == null) return split!;
    if (split == null) return single;
    return single.isBefore(split) ? single : split;
  }

  Map<String, DateTime?> violationStartTimes(
    List<TachographActivity> activities,
    DateTime currentTime,
  ) {
    final sortedActivities = _activitiesUpTo(activities, currentTime);

    return {
      'continuous': _continuousCrossing(sortedActivities),
      'daily': _dailyCrossing(sortedActivities),
      'weekly': _weeklyCrossing(sortedActivities, currentTime),
      'bi_weekly': _biWeeklyCrossing(sortedActivities, currentTime),
    };
  }

  static DateTime? _crossingInstant(
    DateTime start,
    Duration duration,
    Duration accumulatorAtStart,
    Duration limit,
  ) {
    if (accumulatorAtStart >= limit) return null;
    final needed = limit - accumulatorAtStart;
    if (duration < needed) return null;
    return start.add(needed);
  }

  DateTime? _continuousCrossing(List<TachographActivity> activities) {
    Duration currentContinuous = Duration.zero;
    final pendingRests = <Duration>[];
    DateTime? crossing;

    for (final act in activities) {
      if (act.type == ActivityType.driving) {
        crossing ??= _crossingInstant(
          act.startTime,
          act.duration,
          currentContinuous,
          continuousDrivingLimit,
        );
        currentContinuous += act.duration;
      } else if (act.type == ActivityType.rest) {
        pendingRests.add(act.duration);
        if (satisfiesArticle7BreakRequirement(pendingRests)) {
          currentContinuous = Duration.zero;
          pendingRests.clear();
          crossing = null;
        }
      }
    }
    return currentContinuous >= continuousDrivingLimit ? crossing : null;
  }

  DateTime? _dailyCrossing(List<TachographActivity> activities) {
    Duration currentDaily = Duration.zero;
    DateTime? crossing;

    for (final act in activities) {
      if (act.type == ActivityType.rest &&
          act.duration >= const Duration(hours: 9)) {
        currentDaily = Duration.zero;
        crossing = null;
        continue;
      }
      if (act.type == ActivityType.driving) {
        crossing ??= _crossingInstant(
          act.startTime,
          act.duration,
          currentDaily,
          dailyDrivingLimit,
        );
        currentDaily += act.duration;
      }
    }
    return currentDaily >= dailyDrivingLimit ? crossing : null;
  }

  DateTime? _weeklyCrossing(
    List<TachographActivity> activities,
    DateTime currentTime,
  ) {
    int daysSinceMonday = currentTime.weekday - DateTime.monday;
    DateTime startOfWeek = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    ).subtract(Duration(days: daysSinceMonday));

    Duration total = Duration.zero;
    DateTime? crossing;
    for (final act in activities) {
      if (act.type != ActivityType.driving || !act.endTime.isAfter(startOfWeek))
        continue;
      final effectiveStart = act.startTime.isBefore(startOfWeek)
          ? startOfWeek
          : act.startTime;
      final effectiveDuration = act.endTime.difference(effectiveStart);
      crossing ??= _crossingInstant(
        effectiveStart,
        effectiveDuration,
        total,
        weeklyDrivingLimit,
      );
      total += effectiveDuration;
    }
    return total >= weeklyDrivingLimit ? crossing : null;
  }

  DateTime? _biWeeklyCrossing(
    List<TachographActivity> activities,
    DateTime currentTime,
  ) {
    int daysSinceMonday = currentTime.weekday - DateTime.monday;
    DateTime startOfThisWeek = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    ).subtract(Duration(days: daysSinceMonday));
    DateTime startOfPreviousWeek = startOfThisWeek.subtract(
      const Duration(days: 7),
    );

    Duration total = Duration.zero;
    DateTime? crossing;
    for (final act in activities) {
      if (act.type != ActivityType.driving ||
          !act.endTime.isAfter(startOfPreviousWeek))
        continue;
      final effectiveStart = act.startTime.isBefore(startOfPreviousWeek)
          ? startOfPreviousWeek
          : act.startTime;
      final effectiveDuration = act.endTime.difference(effectiveStart);
      crossing ??= _crossingInstant(
        effectiveStart,
        effectiveDuration,
        total,
        biWeeklyDrivingLimit,
      );
      total += effectiveDuration;
    }
    return total >= biWeeklyDrivingLimit ? crossing : null;
  }
}
