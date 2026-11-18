import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/sync_config.dart';
import '../models/activity_segment.dart';
import 'activity_merge_engine.dart';
import 'activity_store.dart';
import 'driving_time_calculator.dart';
import 'link/link_gate.dart';
import 'link/link_scheduler.dart';
import 'link/motion_source.dart';
import 'time/tacho_clock.dart';
import 'violation_analyzer.dart';

/// What the app kept before the activity store existed, imported once.
class LegacyActivityData {
  const LegacyActivityData({
    this.live1 = const [],
    this.live2 = const [],
    this.manual = const [],
    this.open1,
    this.open2,
    this.lastKnownActivityTime,
  });

  final List<TachographActivity> live1;
  final List<TachographActivity> live2;
  final List<TachographActivity> manual;
  final ({ActivityType type, DateTime start})? open1;
  final ({ActivityType type, DateTime start})? open2;
  final DateTime? lastKnownActivityTime;
}

/// Everything about the drivers' activity data in one place, for AppState
/// to delegate to: the store, the merge engine and the link scheduler.
///
/// Rules: card (DDD) > live > manual, all in UTC, the line to the unit is
/// either live or downloading. See [ActivityMergeEngine] and
/// [LinkScheduler].
class ActivityDataController extends ChangeNotifier {
  ActivityDataController({
    this.config = SyncConfig.defaults,
    required this.clock,
    required CardDownloader downloadCard,
    required Future<void> Function(DddDownloadOutcome outcome) onCardData,
    ActivityStore? store,
    MotionSource motion = const NoMotionSource(),
    LinkGate? gate,
  }) : store = store ?? ActivityStore(config: config),
       engine = ActivityMergeEngine(config),
       gate = gate ?? LinkGate.instance {
    scheduler = LinkScheduler(
      config: config,
      clock: clock.nowUtc,
      motion: motion,
      downloadCard: downloadCard,
      onCardData: onCardData,
    );
    this.gate.addListener(_onGateChanged);
    scheduler.addListener(notifyListeners);
  }

  static const drivers = ['driver1', 'driver2'];

  final SyncConfig config;
  final TachoClock clock;
  final ActivityStore store;
  final ActivityMergeEngine engine;
  final LinkGate gate;
  late final LinkScheduler scheduler;

  ActivityStoreState get state => store.state;

  bool _inDddMode = false;
  DateTime? _disconnectedAt;

  /// A card file corrected live or manual data by more than
  /// [SyncConfig.correctionNotifyThreshold]; cleared when shown.
  List<CorrectionLogEntry> _pendingCorrections = const [];
  List<CorrectionLogEntry> get pendingCorrections => _pendingCorrections;
  void clearPendingCorrections() {
    _pendingCorrections = const [];
    notifyListeners();
  }

  // -------------------------------------------------------------- setup --

  /// Loads the store; on its very first start brings over [legacy].
  Future<void> load({
    LegacyActivityData legacy = const LegacyActivityData(),
  }) async {
    await store.load();
    if (!store.hadStoredState) {
      await _replace(_fromLegacy(legacy), force: true);
    }
    _syncScheduler();
  }

  ActivityStoreState _fromLegacy(LegacyActivityData legacy) {
    final now = clock.nowUtc();
    final segments = <ActivitySegment>[];
    void addLive(String driver, List<TachographActivity> log) {
      for (final a in log) {
        if (!a.endTime.isAfter(a.startTime)) continue;
        segments.add(
          ActivitySegment(
            id: 'live:$driver:${a.startTime.toUtc().millisecondsSinceEpoch}',
            driverId: driver,
            startUtc: a.startTime.toUtc(),
            endUtc: a.endTime.toUtc(),
            activityType: a.type,
            source: SegmentSource.live,
            status: SegmentStatus.provisional,
            createdAt: now,
          ),
        );
      }
    }

    addLive('driver1', legacy.live1);
    addLive('driver2', legacy.live2);
    // An activity under way when the app last stopped: what is known of it
    // runs to the last checkpoint.
    for (final (driver, open) in [
      ('driver1', legacy.open1),
      ('driver2', legacy.open2),
    ]) {
      if (open == null) continue;
      final end = legacy.lastKnownActivityTime?.toUtc();
      if (end == null || !end.isAfter(open.start)) continue;
      addLive(driver, [
        TachographActivity(
          type: open.type,
          startTime: open.start,
          endTime: end,
        ),
      ]);
    }
    var i = 0;
    for (final a in legacy.manual) {
      if (!a.endTime.isAfter(a.startTime)) continue;
      segments.add(
        ActivitySegment(
          id: 'manual:legacy:${i++}',
          driverId: 'driver1',
          startUtc: a.startTime.toUtc(),
          endUtc: a.endTime.toUtc(),
          activityType: a.type,
          source: SegmentSource.manual,
          status: SegmentStatus.provisional,
          createdAt: now,
          note: a.note,
        ),
      );
    }
    segments.sort((a, b) => a.startUtc.compareTo(b.startUtc));
    return ActivityStoreState(segments: segments);
  }

  // --------------------------------------------------------------- read --

  ActivityStoreState? _viewState;
  DateTime? _viewAt;
  final Map<String, List<ActivitySegment>> _viewCache = {};

  /// [driverId]'s merged day (see [ActivityMergeEngine.view]). Kept until
  /// the data changes or half a minute passes (an open segment runs to now).
  List<ActivitySegment> view(String driverId) {
    final now = clock.nowUtc();
    if (!identical(_viewState, store.state) ||
        _viewAt == null ||
        now.difference(_viewAt!) >= const Duration(seconds: 30)) {
      _viewCache.clear();
      _viewState = store.state;
      _viewAt = now;
    }
    return _viewCache.putIfAbsent(
      driverId,
      () => List.unmodifiable(engine.view(store.state, driverId, now)),
    );
  }

  /// [view] as activities, for the calculators and the pages.
  List<TachographActivity> activities(String driverId) {
    final now = clock.nowUtc();
    return [
      for (final s in view(driverId))
        if (!s.isGap || s.source == SegmentSource.ddd) s.toActivity(now),
    ];
  }

  /// The live segment under way now, if any.
  ActivitySegment? openLive(String driverId) {
    for (final s in state.activeFor(driverId).reversed) {
      if (s.source == SegmentSource.live && !s.isGap && s.endUtc == null) {
        return s;
      }
    }
    return null;
  }

  /// The last live segment, open or not: what to show, faded, while the
  /// line is busy with a download.
  ActivitySegment? lastLive(String driverId) {
    for (final s in state.activeFor(driverId).reversed) {
      if (s.source == SegmentSource.live && !s.isGap) return s;
    }
    return null;
  }

  SpeedSample? get lastSpeed =>
      store.speedSamples.isEmpty ? null : store.speedSamples.last;

  /// Stretches the driver is asked about, oldest first: no record at all,
  /// and none to come (see [SegmentStatus.needsManual]), that ended within
  /// [SyncConfig.manualPromptLookback].
  List<ActivityGap> questions(String driverId) {
    final now = clock.nowUtc();
    final since = now.subtract(config.manualPromptLookback);
    return [
      for (final s in view(driverId))
        if (s.status == SegmentStatus.needsManual &&
            s.endUtc != null &&
            s.endUtc!.isAfter(since))
          ActivityGap(start: s.startUtc, end: s.endUtc!),
    ];
  }

  /// A card download holds the line: "verifying tachograph data".
  bool get isVerifying => gate.isDddMode;

  /// Stale card data and a download waiting for the vehicle to stop.
  bool get waitingForStop => scheduler.waitingForStop(clock.nowUtc());

  SyncState syncOf(String driverId) => state.syncOf(driverId);

  // -------------------------------------------------------------- write --

  /// A live working state for [driverId] ('driver1' / 'driver2').
  /// [currentActivityDuration] is how long the unit says the activity has
  /// run, which dates the change better than the poll does.
  void recordLive(
    String driverId,
    ActivityType type, {
    Duration? currentActivityDuration,
  }) {
    final at = clock.nowUtc();
    final next = engine.recordLive(
      state,
      driverId: driverId,
      type: type,
      at: at,
      changedAt: currentActivityDuration == null
          ? null
          : at.subtract(currentActivityDuration),
    );
    // Only the last-sample time changed: written later with the next change.
    final segmentsChanged =
        !identical(next.segments, state.segments) &&
        !_sameSegments(next.segments, state.segments);
    unawaited(_replace(next, force: segmentsChanged));
  }

  /// A live sample for the scheduler: speed, the main driver's activity and
  /// whether a card is in slot 1.
  void onLiveSample({
    required int? speedKmh,
    required ActivityType? activity,
    required bool cardInserted,
  }) {
    if (speedKmh != null) {
      unawaited(
        store.addSpeedSample(SpeedSample(tsUtc: clock.nowUtc(), kmh: speedKmh)),
      );
    }
    _syncScheduler();
    scheduler.onLiveSample(
      speedKmh: speedKmh,
      activity: activity,
      cardInserted: cardInserted,
    );
  }

  void onConnected() {
    gate.setConnected(true);
    _syncScheduler();
    scheduler.onConnected(disconnectedAt: _disconnectedAt);
    _disconnectedAt = null;
  }

  void onDisconnected() {
    final at = clock.nowUtc();
    _disconnectedAt = at;
    var next = state;
    for (final d in drivers) {
      if (next.syncOf(d).lastLiveSampleUtc == null) continue;
      next = engine.markLinkDown(
        next,
        driverId: d,
        at: at,
        reason: GapReason.disconnect,
      );
    }
    unawaited(_replace(next, force: true));
    scheduler.onDisconnected();
    gate.setConnected(false);
  }

  void _onGateChanged() {
    final ddd = gate.isDddMode;
    if (ddd == _inDddMode) return;
    _inDddMode = ddd;
    if (ddd) {
      // No live data until the download is done; the unit keeps recording,
      // so the next card file fills this.
      final at = clock.nowUtc();
      var next = state;
      for (final d in drivers) {
        if (next.syncOf(d).lastLiveSampleUtc == null) continue;
        next = engine.markLinkDown(
          next,
          driverId: d,
          at: at,
          reason: GapReason.dddMode,
        );
      }
      unawaited(_replace(next, force: true));
    }
    notifyListeners();
  }

  /// Merges a card file for [driverId]. Same file twice: no change.
  ImportOutcome importCard({
    required String fileId,
    required List<TachographActivity> records,
    required DateTime downloadedAt,
    String driverId = 'driver1',
  }) {
    final outcome = engine.importDdd(
      state,
      DddImport(
        fileId: fileId,
        driverId: driverId,
        records: records,
        downloadedAt: downloadedAt,
      ),
      now: clock.nowUtc(),
    );
    if (outcome.changed || !identical(outcome.state, state)) {
      unawaited(_replace(outcome.state, force: true));
    }
    if (outcome.notify) {
      _pendingCorrections = [
        ..._pendingCorrections,
        ...outcome.newCorrections.where(
          (c) => c.differingTime >= config.correctionNotifyThreshold,
        ),
      ];
    }
    _syncScheduler();
    return outcome;
  }

  void addManual({
    required String driverId,
    required ActivityType type,
    required DateTime start,
    required DateTime end,
    String? note,
  }) {
    unawaited(
      _replace(
        engine.addManual(
          state,
          driverId: driverId,
          type: type,
          start: start,
          end: end,
          note: note,
          now: clock.nowUtc(),
        ),
        force: true,
      ),
    );
  }

  /// For tests and the debug pages: a stretch of [length] up to now with
  /// no record, as if no card download had come for it in all that time -
  /// a question for the driver.
  void debugUnexplainedGap(Duration length, {String driverId = 'driver1'}) {
    final now = clock.nowUtc();
    final start = now.subtract(length);
    unawaited(
      _replace(
        state.copyWith(
          segments: [
            ...state.segments,
            ActivitySegment(
              id: 'gap:$driverId:${start.millisecondsSinceEpoch}:debug',
              driverId: driverId,
              startUtc: start,
              endUtc: now,
              activityType: ActivityType.unknown,
              source: SegmentSource.live,
              status: SegmentStatus.needsManual,
              createdAt: now,
              gapReason: GapReason.disconnect,
            ),
          ]..sort((a, b) => a.startUtc.compareTo(b.startUtc)),
        ),
        force: true,
      ),
    );
  }

  /// Pending gaps that have waited too long become questions.
  void classifyGaps() {
    final next = engine.classifyGaps(state, clock.nowUtc());
    if (!identical(next, state)) unawaited(_replace(next, force: true));
  }

  // ------------------------------------------------------------ helpers --

  DateTime? _lastWrite;

  /// Keeps [next]; writes it when segments changed ([force]) or a minute
  /// after the last write.
  Future<void> _replace(ActivityStoreState next, {required bool force}) async {
    final now = clock.nowUtc();
    final due =
        force ||
        _lastWrite == null ||
        now.difference(_lastWrite!) >= const Duration(minutes: 1);
    if (due) {
      _lastWrite = now;
      await store.replace(next);
    } else {
      store.replaceInMemory(next);
    }
    // A write can finish after the owner is gone.
    if (!_disposed) notifyListeners();
  }

  bool _disposed = false;

  void _syncScheduler() {
    final sync = state.syncOf('driver1');
    scheduler
      ..lastDddDownloadAt = sync.lastDddDownloadAt
      ..watermark = sync.dddWatermarkUtc;
  }

  static bool _sameSegments(List<ActivitySegment> a, List<ActivitySegment> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.id != y.id ||
          x.endUtc != y.endUtc ||
          x.startUtc != y.startUtc ||
          x.status != y.status ||
          x.supersededBy != y.supersededBy) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    gate.removeListener(_onGateChanged);
    scheduler.removeListener(notifyListeners);
    unawaited(store.flushSpeed());
    super.dispose();
  }
}
