import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Tells the scheduler the vehicle has started moving while a card download
/// holds the line - when the unit itself cannot say, as no live data comes
/// then.
abstract class MotionSource {
  /// Whether it can tell the vehicle moves at all.
  Future<bool> isAvailable();

  /// Starts watching; [onMoving] is called when the vehicle moves.
  Future<void> start(void Function() onMoving);
  Future<void> stop();
}

/// No signal: a download is only stopped by the next quiet-window check.
class NoMotionSource implements MotionSource {
  const NoMotionSource();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> start(void Function() onMoving) async {}

  @override
  Future<void> stop() async {}
}

/// The phone's GPS speed. Used only when location permission has already
/// been given; it never asks for it.
class GpsMotionSource implements MotionSource {
  GpsMotionSource({this.movingKmh = 8, this.readingsNeeded = 2});

  /// Above this the vehicle is taken to be moving.
  final double movingKmh;

  /// Readings in a row above [movingKmh] before it counts: one GPS jump
  /// should not stop a download.
  final int readingsNeeded;

  StreamSubscription<Position>? _subscription;

  @override
  Future<bool> isAvailable() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return false;
      }
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> start(void Function() onMoving) async {
    await stop();
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return;
    } catch (_) {
      return;
    }
    var fast = 0;
    _subscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        ).listen((position) {
          final kmh = position.speed.isNaN ? 0.0 : position.speed * 3.6;
          fast = kmh > movingKmh ? fast + 1 : 0;
          if (fast >= readingsNeeded) onMoving();
        }, onError: (Object _) {});
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
