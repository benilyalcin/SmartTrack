import '../config/sync_config.dart';
import '../models/activity_segment.dart';
import 'activity_store.dart';
import 'driving_time_calculator.dart';

/// A card file to merge in.
class DddImport {
  const DddImport({
    required this.fileId,
    required this.driverId,
    required this.records,
    required this.downloadedAt,
  });

  final String fileId;
  final String driverId;

  /// The file's activity records (TachographDriverData.activityLog).
  final List<TachographActivity> records;

  /// When the file was read off the card, in unit time.
  final DateTime downloadedAt;
}

class ImportOutcome {
  const ImportOutcome({
    required this.state,
    required this.changed,
    required this.newCorrections,
    required this.notify,
  });

  final ActivityStoreState state;

  /// False when the file brought nothing new (imported before, or older
  /// than what is there).
  final bool changed;

  final List<CorrectionLogEntry> newCorrections;

  /// Whether a correction is big enough to tell the driver
  /// ([SyncConfig.correctionNotifyThreshold]).
  final bool notify;
}

/// Merges card (DDD), live and manual activity data.
///
/// Rules (see the data-source plan):
/// - Trust is DDD > live > manual. Up to the card file's watermark - its
///   last activity change - only card records stand; a live or manual
///   segment there is superseded, never deleted, and the difference is
///   logged.
/// - A stretch the card covers without a record (card not inserted, or a
///   whole day without one) is a question for the driver (needsManual);
///   a manual entry there stands, as the card has nothing to say against
///   it.
/// - A stretch with no live record (lost contact, or the line busy with a
///   card download) is a pendingGap: the unit kept recording, the next card
///   download fills it.
/// - Importing the same file twice changes nothing; an older file never
///   replaces records from a newer one.
///
/// Every method is pure: it takes a state and returns the next one.
class ActivityMergeEngine {
  const ActivityMergeEngine([this.config = SyncConfig.defaults]);

  final SyncConfig config;

  // ---------------------------------------------------------------- DDD --

  ImportOutcome importDdd(
    ActivityStoreState state,
    DddImport input, {
    required DateTime now,
  }) {
    final unchanged = ImportOutcome(
      state: state,
      changed: false,
      newCorrections: const [],
      notify: false,
    );
    final downloadedAt = input.downloadedAt.toUtc();
    final records =
        latestCardRecordPerDay(
            input.records,
          ).where((r) => r.startTime.isBefore(downloadedAt)).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (records.isEmpty) return unchanged;

    final driver = input.driverId;
    final from = _utcDay(records.first.startTime);
    final watermark = _watermark(records, downloadedAt);
    final created = downloadedAt;

    // What the file says, up to the watermark.
    final fresh = <ActivitySegment>[];
    final recordDays = <DateTime>{};
    for (final r in records) {
      recordDays.add(_utcDay(r.startTime));
      if (!r.startTime.isBefore(watermark)) continue;
      final end = r.endTime.isAfter(watermark) ? watermark : r.endTime;
      if (!end.isAfter(r.startTime)) continue;
      final noRecord = r.type == ActivityType.unknown;
      fresh.add(
        ActivitySegment(
          id: _dddId(driver, r.startTime, end, r.type),
          driverId: driver,
          startUtc: r.startTime.toUtc(),
          endUtc: end.toUtc(),
          activityType: r.type,
          source: SegmentSource.ddd,
          status: noRecord
              ? SegmentStatus.needsManual
              : SegmentStatus.confirmed,
          createdAt: created,
          slot: r.slot,
          isCrew: r.isCrew,
          recordPresenceCounter: r.recordPresenceCounter,
        ),
      );
    }
    // Days inside the file's span with no record at all: the card was not
    // inserted that whole day.
    for (
      var day = from;
      day.isBefore(watermark);
      day = DateTime.utc(day.year, day.month, day.day + 1)
    ) {
      if (recordDays.contains(day)) continue;
      final next = DateTime.utc(day.year, day.month, day.day + 1);
      final end = next.isAfter(watermark) ? watermark : next;
      fresh.add(
        ActivitySegment(
          id: _dddId(driver, day, end, ActivityType.unknown),
          driverId: driver,
          startUtc: day,
          endUtc: end,
          activityType: ActivityType.unknown,
          source: SegmentSource.ddd,
          status: SegmentStatus.needsManual,
          createdAt: created,
        ),
      );
    }

    final knownIds = {for (final s in state.segments) s.id};
    final active = state.activeFor(driver);
    // Card segments from a file downloaded later than this one win.
    final newerDdd = [
      for (final s in active)
        if (s.source == SegmentSource.ddd && s.createdAt.isAfter(created)) s,
    ];
    final toAdd = [
      for (final s in fresh)
        if (!knownIds.contains(s.id) &&
            !newerDdd.any((n) => _overlaps(n, s, now)))
          s,
    ];

    // The activity under way at the download carried on from the watermark
    // until then: it fills a gap there, as far as the file goes.
    // ASSUMPTION (SyncConfig.cardRecordsReachLastChange): the newest card
    // record is the activity under way at the download.
    final tail = <ActivitySegment>[];
    if (config.cardRecordsReachLastChange && watermark.isBefore(downloadedAt)) {
      final last = records.last;
      if (!last.startTime.isAfter(watermark) &&
          last.type != ActivityType.unknown) {
        for (final gap in active.where((s) => s.isGap && !_isDdd(s))) {
          final start = _later(gap.startUtc, watermark);
          final end = _earlier(gap.endOr(now), downloadedAt);
          if (!end.isAfter(start)) continue;
          final id = '${_dddId(driver, start, end, last.type)}:tail';
          if (knownIds.contains(id)) continue;
          tail.add(
            ActivitySegment(
              id: id,
              driverId: driver,
              startUtc: start,
              endUtc: end,
              activityType: last.type,
              source: SegmentSource.ddd,
              status: SegmentStatus.provisional,
              createdAt: created,
              slot: last.slot,
              isCrew: last.isCrew,
            ),
          );
        }
      }
    }

    if (toAdd.isEmpty && tail.isEmpty) {
      return ImportOutcome(
        state: _withSync(state, driver, watermark, downloadedAt),
        changed: false,
        newCorrections: const [],
        notify: false,
      );
    }

    final added = [...toAdd, ...tail];
    // Live data and gaps give way to anything the file says; manual
    // entries only to a real record.
    final liveCover = _union([for (final s in added) _span(s, now)]);
    final manualCover = _union([
      for (final s in added)
        if (s.activityType != ActivityType.unknown) _span(s, now),
    ]);

    final segments = <ActivitySegment>[];
    final corrections = <CorrectionLogEntry>[];
    for (final s in state.segments) {
      final touchable =
          s.driverId == driver &&
          !s.isSuperseded &&
          !newerDdd.contains(s) &&
          !added.any((a) => a.id == s.id);
      if (!touchable) {
        segments.add(s);
        continue;
      }
      final cover = s.source == SegmentSource.manual ? manualCover : liveCover;
      final split = _subtract(s, cover, now);
      if (!split.overlapped) {
        segments.add(s);
        continue;
      }
      final by = added.firstWhere((a) => _overlaps(a, s, now));
      segments.add(s.copyWith(supersededBy: by.id));
      for (final piece in split.kept) {
        segments.add(
          s.copyWith(
            id: '${s.id}~${piece.start.millisecondsSinceEpoch}',
            startUtc: piece.start,
            endUtc: piece.end,
            clearEnd: piece.end == null,
          ),
        );
      }
      if (!s.isGap && s.source != SegmentSource.ddd) {
        corrections.add(_correction(s, added, cover, now));
      }
    }
    segments
      ..addAll(added)
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));

    final next = _withSync(
      state.copyWith(
        segments: segments,
        corrections: [...state.corrections, ...corrections],
      ),
      driver,
      watermark,
      downloadedAt,
    );
    return ImportOutcome(
      state: next,
      changed: true,
      newCorrections: corrections,
      notify: corrections.any(
        (c) => c.differingTime >= config.correctionNotifyThreshold,
      ),
    );
  }

  /// The file's last activity change: from there on it has no end for the
  /// activity under way. When its newest day cannot be trusted to reach that
  /// far, the start of that day.
  DateTime _watermark(List<TachographActivity> records, DateTime downloaded) {
    final last = records.last;
    final mark = config.cardRecordsReachLastChange
        ? last.startTime.toUtc()
        : _utcDay(last.startTime);
    return mark.isAfter(downloaded) ? downloaded : mark;
  }

  CorrectionLogEntry _correction(
    ActivitySegment replaced,
    List<ActivitySegment> by,
    List<_Span> cover,
    DateTime now,
  ) {
    var differing = Duration.zero;
    final ids = <String>[];
    for (final d in by) {
      final overlap = _overlap(_span(replaced, now), _span(d, now));
      if (overlap == Duration.zero) continue;
      ids.add(d.id);
      if (d.activityType != replaced.activityType) differing += overlap;
    }
    final spans = [
      for (final c in cover)
        if (_overlap(c, _span(replaced, now)) > Duration.zero) c,
    ];
    return CorrectionLogEntry(
      at: now.toUtc(),
      supersededId: replaced.id,
      supersededSource: replaced.source,
      supersededType: replaced.activityType,
      startUtc: _later(replaced.startUtc, spans.first.start),
      endUtc: _earlier(replaced.endOr(now), spans.last.end ?? now),
      dddSegmentIds: ids,
      differingTime: differing,
    );
  }

  ActivityStoreState _withSync(
    ActivityStoreState state,
    String driver,
    DateTime watermark,
    DateTime downloadedAt,
  ) {
    final sync = state.syncOf(driver);
    final mark = sync.dddWatermarkUtc;
    final last = sync.lastDddDownloadAt;
    return state.copyWith(
      syncStates: {
        ...state.syncStates,
        driver: sync.copyWith(
          dddWatermarkUtc: mark == null || watermark.isAfter(mark)
              ? watermark
              : mark,
          lastDddDownloadAt: last == null || downloadedAt.isAfter(last)
              ? downloadedAt
              : last,
        ),
      },
    );
  }

  // --------------------------------------------------------------- live --

  /// A live sample: the unit says [driverId] is doing [type] at [at]. When
  /// the unit also says how long that has gone on, [changedAt] is when it
  /// began; otherwise the change is put at [at].
  ///
  /// When the unit says an activity has run since before contact was lost,
  /// the gap is no gap: the segment from before it carries on.
  ActivityStoreState recordLive(
    ActivityStoreState state, {
    required String driverId,
    required ActivityType type,
    required DateTime at,
    DateTime? changedAt,
  }) {
    at = at.toUtc();
    final sync = state.syncOf(driverId);
    var segments = _closeOpenGaps(state.segments, driverId, at);

    final prevIndex = segments.lastIndexWhere((s) => _isLive(s, driverId));
    final prev = prevIndex < 0 ? null : segments[prevIndex];
    var start = changedAt?.toUtc() ?? at;
    if (start.isAfter(at)) start = at;
    final mark = sync.dddWatermarkUtc;
    if (mark != null && start.isBefore(mark)) start = mark;

    if (prev != null && prev.activityType == type) {
      final prevEnd = prev.endUtc;
      // Still the same activity, or the same one carried on through a gap.
      if (prevEnd == null || !start.isAfter(prevEnd)) {
        segments[prevIndex] = prev.copyWith(clearEnd: true);
        segments = _trimGaps(segments, driverId, from: prevEnd ?? at);
        return _afterSample(state, segments, driverId, at);
      }
    }

    if (prev != null) {
      final prevEnd = prev.endUtc;
      if (prevEnd == null) {
        if (!start.isAfter(prev.startUtc)) start = at;
        segments[prevIndex] = prev.copyWith(endUtc: start);
      } else if (start.isBefore(prevEnd)) {
        start = prevEnd;
      }
    }
    // What the unit says it has been doing explains the gap from [start].
    segments = _trimGaps(segments, driverId, from: start);
    segments.add(
      ActivitySegment(
        id: 'live:$driverId:${start.millisecondsSinceEpoch}',
        driverId: driverId,
        startUtc: start,
        endUtc: null,
        activityType: type,
        source: SegmentSource.live,
        status: SegmentStatus.provisional,
        createdAt: at,
      ),
    );
    return _afterSample(state, segments, driverId, at);
  }

  ActivityStoreState _afterSample(
    ActivityStoreState state,
    List<ActivitySegment> segments,
    String driverId,
    DateTime at,
  ) => state.copyWith(
    segments: segments..sort((a, b) => a.startUtc.compareTo(b.startUtc)),
    syncStates: {
      ...state.syncStates,
      driverId: state.syncOf(driverId).copyWith(lastLiveSampleUtc: at),
    },
  );

  /// Cuts [driverId]'s live gaps off at [from]; a gap that starts there or
  /// later goes.
  List<ActivitySegment> _trimGaps(
    List<ActivitySegment> segments,
    String driverId, {
    required DateTime from,
  }) => [
    for (final s in segments)
      if (!_isLiveGap(s, driverId) || s.endUtc == null)
        s
      else if (!s.startUtc.isBefore(from))
        ...const <ActivitySegment>[]
      else if (s.endUtc!.isAfter(from))
        s.copyWith(endUtc: from)
      else
        s,
  ];

  /// No live data from here on, for [reason]. The open live segment is
  /// ended at the last sample - all that is known of it - and an open
  /// pendingGap takes over from there.
  ActivityStoreState markLinkDown(
    ActivityStoreState state, {
    required String driverId,
    required DateTime at,
    required GapReason reason,
  }) {
    at = at.toUtc();
    final segments = List<ActivitySegment>.of(state.segments);
    if (segments.any((s) => _isLiveGap(s, driverId) && s.endUtc == null)) {
      return state;
    }
    final lastSample = state.syncOf(driverId).lastLiveSampleUtc;
    final openIndex = segments.lastIndexWhere((s) => _isOpenLive(s, driverId));
    var gapStart = lastSample ?? at;
    if (openIndex >= 0) {
      final open = segments[openIndex];
      final end = _later(open.startUtc, lastSample ?? at);
      if (end.isAfter(open.startUtc)) {
        segments[openIndex] = open.copyWith(endUtc: end);
      } else {
        // Seen once, at the very moment contact went: nothing is known of
        // it beyond that, so the gap starts there.
        segments.removeAt(openIndex);
      }
      gapStart = end;
    }
    if (gapStart.isAfter(at)) gapStart = at;
    segments
      ..add(
        ActivitySegment(
          id: 'gap:$driverId:${gapStart.millisecondsSinceEpoch}',
          driverId: driverId,
          startUtc: gapStart,
          endUtc: null,
          activityType: ActivityType.unknown,
          source: SegmentSource.live,
          status: SegmentStatus.pendingGap,
          createdAt: at,
          gapReason: reason,
        ),
      )
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    return state.copyWith(segments: segments);
  }

  /// Live data is back at [at]: the open gap ends there.
  ActivityStoreState markLinkUp(
    ActivityStoreState state, {
    required String driverId,
    required DateTime at,
  }) => state.copyWith(
    segments: _closeOpenGaps(state.segments, driverId, at.toUtc()),
  );

  List<ActivitySegment> _closeOpenGaps(
    List<ActivitySegment> segments,
    String driverId,
    DateTime at,
  ) => [
    for (final s in segments)
      if (_isLiveGap(s, driverId) && s.endUtc == null)
        if (at.difference(s.startUtc) >= config.recordTolerance)
          s.copyWith(endUtc: at)
        else
          ...const <ActivitySegment>[]
      else
        s,
  ];

  // ------------------------------------------------------------- manual --

  /// The driver's account of [start]..[end]. It only stands where no card
  /// record or live data says otherwise, and it fills any gap there.
  ActivityStoreState addManual(
    ActivityStoreState state, {
    required String driverId,
    required ActivityType type,
    required DateTime start,
    required DateTime end,
    String? note,
    required DateTime now,
  }) {
    final active = state.activeFor(driverId);
    final taken = _union([
      for (final s in active)
        if (!s.isGap && !(s.source == SegmentSource.manual)) _span(s, now),
    ]);
    final entry = ActivitySegment(
      id: 'manual:${now.toUtc().microsecondsSinceEpoch}',
      driverId: driverId,
      startUtc: start.toUtc(),
      endUtc: end.toUtc(),
      activityType: type,
      source: SegmentSource.manual,
      status: SegmentStatus.provisional,
      createdAt: now.toUtc(),
      note: note,
    );
    final pieces = _subtract(entry, taken, now).kept;
    if (pieces.isEmpty) return state;
    final added = [
      for (final p in pieces)
        entry.copyWith(
          id: '${entry.id}:${p.start.millisecondsSinceEpoch}',
          startUtc: p.start,
          endUtc: p.end,
        ),
    ];
    final cover = _union([for (final a in added) _span(a, now)]);

    final segments = <ActivitySegment>[];
    for (final s in state.segments) {
      final isOurGap =
          s.driverId == driverId &&
          !s.isSuperseded &&
          s.isGap &&
          s.source != SegmentSource.ddd;
      final isOlderManual =
          s.driverId == driverId &&
          !s.isSuperseded &&
          s.source == SegmentSource.manual;
      if (!isOurGap && !isOlderManual) {
        segments.add(s);
        continue;
      }
      final split = _subtract(s, cover, now);
      if (!split.overlapped) {
        segments.add(s);
        continue;
      }
      segments.add(s.copyWith(supersededBy: added.first.id));
      for (final piece in split.kept) {
        segments.add(
          s.copyWith(
            id: '${s.id}~${piece.start.millisecondsSinceEpoch}',
            startUtc: piece.start,
            endUtc: piece.end,
            clearEnd: piece.end == null,
          ),
        );
      }
    }
    segments
      ..addAll(added)
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    return state.copyWith(segments: segments);
  }

  // --------------------------------------------------------------- gaps --

  /// Turns a pending gap into a question for the driver once no card
  /// download has come for [SyncConfig.manualEntryAfter] since it ended.
  /// A gap left by a card download never does: the unit was recording all
  /// through it.
  ActivityStoreState classifyGaps(ActivityStoreState state, DateTime now) {
    now = now.toUtc();
    var changed = false;
    final segments = [
      for (final s in state.segments)
        if (s.status == SegmentStatus.pendingGap &&
            !s.isSuperseded &&
            s.gapReason != GapReason.dddMode &&
            s.endUtc != null &&
            now.difference(s.endUtc!) >= config.manualEntryAfter &&
            _noDddSince(state.syncOf(s.driverId), s.endUtc!))
          () {
            changed = true;
            return s.copyWith(status: SegmentStatus.needsManual);
          }()
        else
          s,
    ];
    return changed ? state.copyWith(segments: segments) : state;
  }

  bool _noDddSince(SyncState sync, DateTime gapEnd) {
    final last = sync.lastDddDownloadAt;
    return last == null || last.isBefore(gapEnd);
  }

  // --------------------------------------------------------------- view --

  /// [driverId]'s day as it stands: active segments without overlaps, a
  /// stretch claimed twice going to the more trusted source. Gaps included.
  List<ActivitySegment> view(
    ActivityStoreState state,
    String driverId,
    DateTime now,
  ) {
    final ranked = state.activeFor(driverId)
      ..sort((a, b) {
        final byRank = _rank(b).compareTo(_rank(a));
        return byRank != 0 ? byRank : a.startUtc.compareTo(b.startUtc);
      });
    final placed = <ActivitySegment>[];
    var taken = <_Span>[];
    for (final s in ranked) {
      final split = _subtract(s, taken, now);
      if (!split.overlapped) {
        placed.add(s);
      } else {
        for (final p in split.kept) {
          placed.add(
            s.copyWith(
              startUtc: p.start,
              endUtc: p.end,
              clearEnd: p.end == null,
            ),
          );
        }
      }
      taken = _union([...taken, _span(s, now)]);
    }
    return placed
      ..removeWhere((s) => !s.endOr(now).isAfter(s.startUtc))
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  }

  /// [view] as activities for the calculators, the analyzer and the pages.
  /// App gaps are left out (no record is no activity); card stretches
  /// without a record stay in as unknown, as the card file has them.
  List<TachographActivity> activities(
    ActivityStoreState state,
    String driverId,
    DateTime now,
  ) => [
    for (final s in view(state, driverId, now))
      if (!s.isGap || s.source == SegmentSource.ddd) s.toActivity(now),
  ];

  int _rank(ActivitySegment s) {
    if (s.source == SegmentSource.ddd) {
      // A card stretch with no record says nothing against a manual entry.
      if (s.status == SegmentStatus.needsManual) return 1;
      return s.status == SegmentStatus.provisional ? 4 : 5;
    }
    if (s.isGap) return 0;
    return s.source == SegmentSource.live ? 3 : 2;
  }

  // ------------------------------------------------------------ helpers --

  static bool _isDdd(ActivitySegment s) => s.source == SegmentSource.ddd;

  static bool _isLive(ActivitySegment s, String driverId) =>
      s.driverId == driverId &&
      s.source == SegmentSource.live &&
      !s.isGap &&
      !s.isSuperseded;

  static bool _isOpenLive(ActivitySegment s, String driverId) =>
      _isLive(s, driverId) && s.endUtc == null;

  static bool _isLiveGap(ActivitySegment s, String driverId) =>
      s.driverId == driverId &&
      s.source == SegmentSource.live &&
      s.isGap &&
      !s.isSuperseded;

  static String _dddId(
    String driver,
    DateTime start,
    DateTime end,
    ActivityType type,
  ) =>
      'ddd:$driver:${start.millisecondsSinceEpoch}-'
      '${end.millisecondsSinceEpoch}:${type.name}';

  static bool _overlaps(ActivitySegment a, ActivitySegment b, DateTime now) =>
      _overlap(_span(a, now), _span(b, now)) > Duration.zero;
}

/// A card can hold more than one record for the same date. Keeps only the
/// records of the latest one (highest presence counter) for each date.
List<TachographActivity> latestCardRecordPerDay(List<TachographActivity> log) {
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

/// A stretch of time; no [end] means still going on.
class _Span {
  const _Span(this.start, this.end);

  final DateTime start;
  final DateTime? end;
}

_Span _span(ActivitySegment s, DateTime now) => _Span(s.startUtc, s.endUtc);

final _forever = DateTime.utc(9999);

Duration _overlap(_Span a, _Span b) {
  final start = _later(a.start, b.start);
  final end = _earlier(a.end ?? _forever, b.end ?? _forever);
  return end.isAfter(start) ? end.difference(start) : Duration.zero;
}

/// [spans] sorted and merged where they touch.
List<_Span> _union(List<_Span> spans) {
  final sorted = List<_Span>.of(spans)
    ..sort((a, b) => a.start.compareTo(b.start));
  final out = <_Span>[];
  for (final s in sorted) {
    if (out.isNotEmpty) {
      final last = out.last;
      final lastEnd = last.end ?? _forever;
      if (!s.start.isAfter(lastEnd)) {
        final end = s.end == null || last.end == null
            ? null
            : _later(last.end!, s.end!);
        out[out.length - 1] = _Span(last.start, end);
        continue;
      }
    }
    out.add(s);
  }
  return out;
}

/// The parts of [s] outside [cover] (sorted, merged), and whether any of it
/// was inside.
({List<_Span> kept, bool overlapped}) _subtract(
  ActivitySegment s,
  List<_Span> cover,
  DateTime now,
) {
  final kept = <_Span>[];
  var overlapped = false;
  var start = s.startUtc;
  final end = s.endUtc;
  for (final c in cover) {
    final cEnd = c.end ?? _forever;
    if (!cEnd.isAfter(start)) continue;
    if (end != null && !c.start.isBefore(end)) break;
    overlapped = true;
    if (c.start.isAfter(start)) kept.add(_Span(start, c.start));
    if (c.end == null) return (kept: kept, overlapped: true);
    start = c.end!;
    if (end != null && !start.isBefore(end)) {
      return (kept: kept, overlapped: true);
    }
  }
  kept.add(_Span(start, end));
  return (kept: kept, overlapped: overlapped);
}

DateTime _utcDay(DateTime t) {
  final u = t.toUtc();
  return DateTime.utc(u.year, u.month, u.day);
}

DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
