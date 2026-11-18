import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smarttrack_mine/core/config/sync_config.dart';
import 'package:smarttrack_mine/core/services/driving_time_calculator.dart';
import 'package:smarttrack_mine/core/services/link/link_gate.dart';
import 'package:smarttrack_mine/core/services/link/link_scheduler.dart';
import 'package:smarttrack_mine/core/services/link/motion_source.dart';
import 'package:smarttrack_mine/core/services/link/quiet_window.dart';

class FakeMotion implements MotionSource {
  void Function()? _onMoving;
  bool watching = false;

  void move() => _onMoving?.call();

  @override
  Future<void> start(void Function() onMoving) async {
    _onMoving = onMoving;
    watching = true;
  }

  @override
  Future<void> stop() async {
    _onMoving = null;
    watching = false;
  }
}

class Harness {
  Harness({SyncConfig config = SyncConfig.defaults, bool vu = false}) {
    scheduler = LinkScheduler(
      config: config,
      clock: () => now,
      motion: motion,
      downloadCard: (token) async {
        cardStarts++;
        tokens.add(token);
        final done = Completer<void>();
        pending = done;
        await done.future;
        return DddDownloadOutcome(
          bytes: token.isCancelled ? null : Uint8List.fromList([1, 2, 3]),
          cancelled: token.isCancelled,
          downloadedAt: now,
        );
      },
      onCardData: (outcome) async => imported.add(outcome),
      downloadVuDay: vu
          ? (day, token) async {
              vuDays.add(day);
              return DddDownloadOutcome(
                bytes: Uint8List.fromList([day.day]),
                downloadedAt: now,
              );
            }
          : null,
      onVuData: vu ? (day, outcome) async {} : null,
    );
  }

  DateTime now = DateTime.utc(2026, 11, 18, 10);
  final motion = FakeMotion();
  late final LinkScheduler scheduler;
  int cardStarts = 0;
  final tokens = <DownloadCancelToken>[];
  final imported = <DddDownloadOutcome>[];
  final vuDays = <DateTime>[];
  Completer<void>? pending;

  void sample({
    int speed = 0,
    ActivityType activity = ActivityType.work,
    bool card = true,
  }) => scheduler.onLiveSample(
    speedKmh: speed,
    activity: activity,
    cardInserted: card,
  );

  void advance(Duration d) => now = now.add(d);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> finishDownload() async {
    pending?.complete();
    pending = null;
    await settle();
    await settle();
  }
}

void main() {
  group('QuietWindowDetector', () {
    final t0 = DateTime.utc(2026, 11, 18, 10);
    QuietWindowDetector stopped({
      required Duration for_,
      ActivityType activity = ActivityType.work,
      bool card = true,
      int speed = 0,
    }) => QuietWindowDetector()
      ..onSample(
        at: t0,
        speedKmh: speed,
        activity: activity,
        cardInserted: card,
      )
      ..onSample(
        at: t0.add(for_),
        speedKmh: speed,
        activity: activity,
        cardInserted: card,
      );

    test('a stop shorter than a card download is not a window', () {
      final q = stopped(for_: const Duration(minutes: 4));
      expect(q.isOpen(t0.add(const Duration(minutes: 4))), isFalse);
      expect(q.isOpen(t0.add(const Duration(minutes: 5))), isTrue);
    });

    test('rest or break opens it at once', () {
      final q = stopped(for_: Duration.zero, activity: ActivityType.rest);
      expect(q.isOpen(t0), isTrue);
    });

    test('never without a card, never while driving', () {
      expect(
        stopped(
          for_: const Duration(hours: 1),
          card: false,
        ).isOpen(t0.add(const Duration(hours: 1))),
        isFalse,
      );
      expect(
        stopped(
          for_: const Duration(hours: 1),
          activity: ActivityType.driving,
        ).isOpen(t0.add(const Duration(hours: 1)), mandatory: true),
        isFalse,
      );
    });

    test('ignition off, once known, counts', () {
      final q = QuietWindowDetector()
        ..onSample(
          at: t0,
          speedKmh: 0,
          activity: ActivityType.work,
          cardInserted: true,
          ignitionOn: false,
        );
      expect(q.isOpen(t0), isTrue);
    });
  });

  group('LinkGate', () {
    test('no live read while a download holds the line', () async {
      final gate = LinkGate()..setConnected(true);
      expect(gate.mode, LinkMode.live);
      final release = Completer<void>();
      final download = gate.runDdd(() => release.future);
      expect(gate.mode, LinkMode.ddd);
      expect(gate.tryBeginLive(), isFalse);
      release.complete();
      await download;
      expect(gate.mode, LinkMode.live);
      expect(gate.tryBeginLive(), isTrue);
    });

    test('a download waits for the live read in flight', () async {
      final gate = LinkGate();
      expect(gate.tryBeginLive(), isTrue);
      var started = false;
      final download = gate.runDdd(() async => started = true);
      await Future<void>.delayed(Duration.zero);
      expect(started, isFalse);
      gate.endLive();
      await download;
      expect(started, isTrue);
    });
  });

  group('LinkScheduler', () {
    test('connecting queues the card but keeps the line live', () async {
      final h = Harness();
      h.scheduler.onConnected();
      expect(h.scheduler.queue.hasCardJob, isTrue);
      expect(h.cardStarts, 0);
    });

    test('never starts a download while driving', () async {
      final h = Harness();
      h.scheduler.onConnected();
      for (var i = 0; i < 20; i++) {
        h.sample(speed: 85, activity: ActivityType.driving);
        h.advance(const Duration(minutes: 5));
        await h.settle();
      }
      // Stopped in traffic but the unit still says driving.
      h.sample(speed: 0, activity: ActivityType.driving);
      h.advance(const Duration(minutes: 30));
      h.sample(speed: 0, activity: ActivityType.driving);
      await h.settle();
      expect(h.scheduler.isStale(h.now), isTrue);
      expect(h.cardStarts, 0);
    });

    test('moving during a download cancels it and puts the job back', () async {
      final h = Harness();
      h.scheduler.onConnected();
      h.sample(activity: ActivityType.rest);
      await h.settle();
      expect(h.cardStarts, 1);
      expect(h.scheduler.isRunning, isTrue);
      expect(h.motion.watching, isTrue);

      h.motion.move();
      expect(h.tokens.single.isCancelled, isTrue);
      await h.finishDownload();

      expect(h.scheduler.isRunning, isFalse);
      expect(h.imported, isEmpty, reason: 'partial data is thrown away');
      expect(h.scheduler.queue.hasCardJob, isTrue);
      expect(h.motion.watching, isFalse);

      // Not again without a fresh look at the vehicle...
      await h.scheduler.tick();
      expect(h.cardStarts, 1);
      // ...and not while it moves.
      h.advance(const Duration(minutes: 1));
      h.sample(speed: 40, activity: ActivityType.driving);
      await h.settle();
      expect(h.cardStarts, 1);

      // Parked again: the job runs and its data is used.
      h.advance(const Duration(minutes: 30));
      h.sample(activity: ActivityType.rest);
      await h.settle();
      expect(h.cardStarts, 2);
      await h.finishDownload();
      expect(h.imported, hasLength(1));
      expect(h.scheduler.queue.isEmpty, isTrue);
      expect(h.scheduler.lastDddDownloadAt, h.now);
    });

    test('vehicle unit days are fetched one at a time, newest first', () async {
      final h = Harness(
        config: const SyncConfig(vuDownloadEnabled: true),
        vu: true,
      );
      h.scheduler
        ..lastDddDownloadAt = h.now.subtract(const Duration(hours: 1))
        ..watermark = DateTime.utc(2026, 11, 15, 18);
      h.scheduler.onConnected();
      // The card first (the driver's own record), then days 18..15.
      expect(h.scheduler.queue.jobs.map((j) => j.key), [
        'card',
        for (final d in [18, 17, 16, 15])
          'vu:${DateTime.utc(2026, 11, d).toIso8601String()}',
      ]);

      h.sample(activity: ActivityType.rest);
      await h.settle();
      await h.finishDownload();
      expect(h.imported, hasLength(1));

      for (var i = 0; i < 4; i++) {
        h.advance(const Duration(minutes: 1));
        h.sample(activity: ActivityType.rest);
        await h.settle();
        await h.settle();
        expect(h.vuDays, hasLength(i + 1), reason: 'one per live check');
      }
      expect(h.vuDays.map((d) => d.day), [18, 17, 16, 15]);
      expect(h.scheduler.queue.isEmpty, isTrue);
    });

    test('the next part waits for a fresh live check', () async {
      final h = Harness(
        config: const SyncConfig(vuDownloadEnabled: true),
        vu: true,
      );
      h.scheduler
        ..lastDddDownloadAt = h.now.subtract(const Duration(hours: 1))
        ..watermark = DateTime.utc(2026, 11, 17, 18);
      h.scheduler.onConnected();
      h.sample(activity: ActivityType.rest);
      await h.settle();
      await h.finishDownload();
      await h.scheduler.tick();
      expect(h.vuDays, isEmpty);
      h.advance(const Duration(minutes: 1));
      h.sample(activity: ActivityType.rest);
      await h.settle();
      expect(h.vuDays, hasLength(1));
    });

    test('stale card data makes the download mandatory', () async {
      final h = Harness();
      h.scheduler.lastDddDownloadAt = h.now.subtract(const Duration(hours: 2));
      h.scheduler.watermark = h.now.subtract(const Duration(hours: 3));
      h.scheduler.onConnected();
      expect(h.scheduler.waitingForStop(h.now), isFalse);

      // Fresh enough: a 2 minute stop is not a window.
      h.sample(speed: 0);
      h.advance(const Duration(minutes: 2));
      h.sample(speed: 0);
      await h.settle();
      expect(h.cardStarts, 0);

      // Stale: the driver is asked to stop, and 2 minutes are enough.
      h.scheduler.lastDddDownloadAt = h.now.subtract(const Duration(hours: 30));
      h.sample(speed: 60, activity: ActivityType.driving);
      expect(h.scheduler.waitingForStop(h.now), isTrue);
      await h.settle();
      expect(h.cardStarts, 0, reason: 'still never while driving');
      h.sample(speed: 0);
      h.advance(const Duration(minutes: 2));
      h.sample(speed: 0);
      await h.settle();
      expect(h.cardStarts, 1);
      expect(h.scheduler.waitingForStop(h.now), isFalse);
    });

    test('a short break queues no download of its own', () {
      final h = Harness();
      h.scheduler
        ..lastDddDownloadAt = h.now.subtract(const Duration(hours: 1))
        ..watermark = h.now.subtract(const Duration(hours: 2));
      h.scheduler.onConnected(
        disconnectedAt: h.now.subtract(const Duration(minutes: 5)),
      );
      expect(h.scheduler.queue.isEmpty, isTrue);

      h.scheduler.onConnected(
        disconnectedAt: h.now.subtract(const Duration(hours: 2)),
      );
      expect(h.scheduler.queue.isEmpty, isTrue, reason: 'nothing missing');
    });

    test('losing contact cancels a running download', () async {
      final h = Harness();
      h.scheduler.onConnected();
      h.sample(activity: ActivityType.rest);
      await h.settle();
      h.scheduler.onDisconnected();
      expect(h.tokens.single.isCancelled, isTrue);
      await h.finishDownload();
      expect(h.imported, isEmpty);
      expect(h.scheduler.queue.hasCardJob, isTrue);
    });
  });
}
