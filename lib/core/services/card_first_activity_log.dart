import 'driving_time_calculator.dart';

/// The activity log built card file first: the file's records wherever the
/// file speaks, and the app's own records (live samples, the driver's manual
/// entries) only where it does not.
///
/// The file speaks for every UTC day it holds a record for, up to
/// [downloadedAt]. Its unknown stretches (card not inserted) stay unknown, so
/// a day reads the same as in the file's own activity list. A card file ends
/// each day's last activity at midnight, so on the download day its records
/// are cut at [downloadedAt] and the app's records take over from there.
List<TachographActivity> cardFirstActivityLog({
  required List<TachographActivity> cardLog,
  required DateTime downloadedAt,
  required List<TachographActivity> appLog,
}) {
  final cardRecords = latestCardRecordPerDay(cardLog);

  final cardDays = {for (final a in cardRecords) _utcDay(a.startTime)}.toList()
    ..sort();
  final spoken = <_Span>[];
  for (final day in cardDays) {
    final dayEnd = day.add(const Duration(days: 1));
    final end = downloadedAt.isBefore(dayEnd) ? downloadedAt : dayEnd;
    if (end.isAfter(day)) spoken.add(_Span(day, end));
  }

  final result = <TachographActivity>[
    for (final a in cardRecords)
      if (a.startTime.isBefore(downloadedAt))
        a.endTime.isAfter(downloadedAt)
            ? _withTimes(a, a.startTime, downloadedAt)
            : a,
    for (final a in appLog) ..._outside(a, spoken),
  ]..sort((a, b) => a.startTime.compareTo(b.startTime));
  return result;
}

/// A card can hold more than one record for the same date. Keeps only the
/// records of the latest one (highest presence counter) for each date.
List<TachographActivity> latestCardRecordPerDay(
  List<TachographActivity> log,
) {
  final bestCounterByDay = <DateTime, int>{};
  for (final a in log) {
    final counter = a.recordPresenceCounter;
    if (counter == null) continue;
    final day = _utcDay(a.startTime);
    final best = bestCounterByDay[day];
    if (best == null || counter > best) bestCounterByDay[day] = counter;
  }
  if (bestCounterByDay.isEmpty) return log;
  return [
    for (final a in log)
      if (a.recordPresenceCounter == null ||
          a.recordPresenceCounter == bestCounterByDay[_utcDay(a.startTime)])
        a,
  ];
}

class _Span {
  final DateTime start;
  final DateTime end;

  const _Span(this.start, this.end);
}

DateTime _utcDay(DateTime t) {
  final utc = t.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day);
}

/// The parts of [a] that fall outside [spans] (sorted, not overlapping).
Iterable<TachographActivity> _outside(
  TachographActivity a,
  List<_Span> spans,
) sync* {
  var start = a.startTime;
  for (final span in spans) {
    if (!span.end.isAfter(start)) continue;
    if (!span.start.isBefore(a.endTime)) break;
    if (span.start.isAfter(start)) yield _withTimes(a, start, span.start);
    start = span.end;
    if (!start.isBefore(a.endTime)) return;
  }
  if (a.endTime.isAfter(start)) yield _withTimes(a, start, a.endTime);
}

TachographActivity _withTimes(
  TachographActivity a,
  DateTime start,
  DateTime end,
) {
  return TachographActivity(
    type: a.type,
    startTime: start,
    endTime: end,
    isManualEntry: a.isManualEntry,
    note: a.note,
    isCrew: a.isCrew,
    slot: a.slot,
    cardInserted: a.cardInserted,
    recordPresenceCounter: a.recordPresenceCounter,
  );
}
