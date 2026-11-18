import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../config/sync_config.dart';
import '../driving_time_calculator.dart';
import 'ddd_queue.dart';
import 'link_gate.dart';
import 'motion_source.dart';
import 'quiet_window.dart';

/// What one download attempt gave.
class DddDownloadOutcome {
  const DddDownloadOutcome({
    this.bytes,
    this.cancelled = false,
    this.problem,
    required this.downloadedAt,
  });

  /// Null when cancelled or failed; a cancelled download's partial data is
  /// never handed on.
  final Uint8List? bytes;
  final bool cancelled;
  final String? problem;

  /// Unit time when the download finished.
  final DateTime downloadedAt;

  bool get succeeded => !cancelled && bytes != null && bytes!.isNotEmpty;
}

typedef CardDownloader =
    Future<DddDownloadOutcome> Function(DownloadCancelToken token);
typedef VuDayDownloader =
    Future<DddDownloadOutcome> Function(
      DateTime day,
      DownloadCancelToken token,
    );

/// Decides when the line goes to a card download.
///
/// Live data comes first: on (re)connecting the line stays live and the
/// missing card data is only queued. A download starts in a quiet window
/// (see [QuietWindowDetector]), never while driving. Between two jobs a
/// fresh live sample has to show the window is still quiet. When the
/// vehicle starts moving during a download it is cancelled, its data
/// thrown away and the job put back. Card data older than
/// [SyncConfig.maxDddAge] makes the next download mandatory: it starts
/// after a shorter stop, and the driver is asked to wait when stopped.
class LinkScheduler extends ChangeNotifier {
  LinkScheduler({
    this.config = SyncConfig.defaults,
    required this.downloadCard,
    required this.onCardData,
    this.downloadVuDay,
    this.onVuData,
    this.motion = const NoMotionSource(),
    DateTime Function()? clock,
  }) : quiet = QuietWindowDetector(config),
       _clock = clock ?? (() => DateTime.now().toUtc());

  final SyncConfig config;
  final CardDownloader downloadCard;
  final Future<void> Function(DddDownloadOutcome outcome) onCardData;
  final VuDayDownloader? downloadVuDay;
  final Future<void> Function(DateTime day, DddDownloadOutcome outcome)?
  onVuData;
  final MotionSource motion;
  final DateTime Function() _clock;

  final DddQueue queue = DddQueue();
  final QuietWindowDetector quiet;

  /// From the store: the last card download and how far it confirmed.
  DateTime? lastDddDownloadAt;
  DateTime? watermark;

  bool _connected = false;
  DddJob? _current;
  DownloadCancelToken? _token;
  DateTime? _lastJobEndedAt;
  DateTime? _retryAfter;
  String? _lastProblem;

  bool get isRunning => _current != null;
  DddJob? get currentJob => _current;
  String? get lastProblem => _lastProblem;

  /// Card data too old: the next download is mandatory.
  bool isStale(DateTime now) {
    final last = lastDddDownloadAt;
    return last == null || now.difference(last) > config.maxDddAge;
  }

  /// Whether to show "wait for the vehicle to stop so the data can be
  /// checked": a mandatory download is waiting for its window.
  bool waitingForStop(DateTime now) =>
      _connected && isStale(now) && queue.hasCardJob && !isRunning;

  // ------------------------------------------------------------ events --

  /// Contact made or back. The line stays live; what is missing is queued.
  /// A short break ([SyncConfig.shortGapThreshold]) queues nothing of its
  /// own: the next periodic download covers it.
  void onConnected({DateTime? disconnectedAt}) {
    final now = _clock();
    _connected = true;
    final shortBreak =
        disconnectedAt != null &&
        now.difference(disconnectedAt) < config.shortGapThreshold;
    if (!shortBreak || isStale(now)) _queueMissing(now);
    notifyListeners();
  }

  void onDisconnected() {
    _connected = false;
    quiet.reset();
    // The line is gone; whatever the download had is lost with it.
    _token?.cancel('disconnected');
    notifyListeners();
  }

  /// A live sample. Queues the periodic download when it is due, then
  /// starts the next job if the window is quiet.
  void onLiveSample({
    required int? speedKmh,
    required ActivityType? activity,
    required bool cardInserted,
    bool? ignitionOn,
  }) {
    final now = _clock();
    quiet.onSample(
      at: now,
      speedKmh: speedKmh,
      activity: activity,
      cardInserted: cardInserted,
      ignitionOn: ignitionOn,
    );
    final last = lastDddDownloadAt;
    if (last == null || now.difference(last) >= config.periodicSyncInterval) {
      _queueMissing(now);
    }
    unawaited(tick());
  }

  // -------------------------------------------------------------- run --

  /// Starts the next job if it may start now. Returns when that job is done
  /// (or at once when none starts).
  Future<void> tick() async {
    final now = _clock();
    if (!_connected || isRunning || queue.isEmpty) return;
    if (_retryAfter != null && now.isBefore(_retryAfter!)) return;
    // A fresh look at the vehicle since the last job.
    final ended = _lastJobEndedAt;
    final sample = quiet.lastSampleAt;
    if (ended != null && (sample == null || !sample.isAfter(ended))) return;
    if (!quiet.isOpen(now, mandatory: isStale(now))) return;
    await _run(queue.next!);
  }

  Future<void> _run(DddJob job) async {
    final token = DownloadCancelToken();
    _current = job;
    _token = token;
    notifyListeners();
    await motion.start(() {
      // ASSUMPTION (SyncConfig.abortLeavesUnitStable): cutting a download
      // short with TransferExit + StopCommunication leaves the unit usable.
      if (config.abortLeavesUnitStable) token.cancel('moving');
    });
    try {
      final DddDownloadOutcome outcome;
      if (job.kind == DddJobKind.card) {
        outcome = await downloadCard(token);
      } else {
        final download = downloadVuDay;
        if (download == null) {
          queue.complete(job);
          return;
        }
        outcome = await download(job.day!, token);
      }

      if (outcome.cancelled || token.isCancelled) {
        // Kept in the queue; nothing of it is used.
        _lastProblem = token.reason ?? 'cancelled';
      } else if (outcome.succeeded) {
        if (job.kind == DddJobKind.card) {
          await onCardData(outcome);
          lastDddDownloadAt = outcome.downloadedAt;
        } else {
          await onVuData?.call(job.day!, outcome);
        }
        queue.complete(job);
        _lastProblem = null;
        _retryAfter = null;
      } else {
        _lastProblem = outcome.problem ?? 'no data';
        _retryAfter = _clock().add(const Duration(minutes: 5));
      }
    } catch (e) {
      _lastProblem = '$e';
      _retryAfter = _clock().add(const Duration(minutes: 5));
    } finally {
      await motion.stop();
      _current = null;
      _token = null;
      _lastJobEndedAt = _clock();
      notifyListeners();
    }
  }

  void _queueMissing(DateTime now) {
    final today = DateTime.utc(now.year, now.month, now.day);
    final mark = watermark;
    final last = lastDddDownloadAt;
    final due =
        mark == null ||
        mark.isBefore(today) ||
        last == null ||
        now.difference(last) >= config.periodicSyncInterval;
    if (due) {
      queue.add(DddJob(kind: DddJobKind.card, enqueuedAt: now));
    }
    if (config.vuDownloadEnabled && downloadVuDay != null) {
      final from =
          mark ?? today.subtract(Duration(days: config.dddLookbackDays - 1));
      queue.addVuDays(from, today, now);
    }
  }
}
