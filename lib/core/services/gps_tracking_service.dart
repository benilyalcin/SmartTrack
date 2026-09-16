import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/route_point.dart';

enum GpsTrackingStatus {
  idle,
  requestingPermission,
  permissionDenied,
  serviceDisabled,
  tracking,
  error,
}

class GpsTrackingService extends ChangeNotifier {
  GpsTrackingService._();
  static final GpsTrackingService instance = GpsTrackingService._();

  GpsTrackingStatus _status = GpsTrackingStatus.idle;
  GpsTrackingStatus get status => _status;

  final List<RoutePoint> _points = [];
  List<RoutePoint> get points => List.unmodifiable(_points);

  StreamSubscription<Position>? _subscription;

  double get totalDistanceMeters {
    var total = 0.0;
    for (var i = 1; i < _points.length; i++) {
      total += Geolocator.distanceBetween(
        _points[i - 1].latitude,
        _points[i - 1].longitude,
        _points[i].latitude,
        _points[i].longitude,
      );
    }
    return total;
  }

  Duration get elapsed {
    if (_points.length < 2) return Duration.zero;
    return _points.last.timestamp.difference(_points.first.timestamp);
  }

  Future<bool> startTracking() async {
    if (_status == GpsTrackingStatus.tracking) return true;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _status = GpsTrackingStatus.serviceDisabled;
      notifyListeners();
      return false;
    }

    _status = GpsTrackingStatus.requestingPermission;
    notifyListeners();

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _status = GpsTrackingStatus.permissionDenied;
      notifyListeners();
      return false;
    }

    _status = GpsTrackingStatus.tracking;
    notifyListeners();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          (position) {
            _points.add(
              RoutePoint(
                latitude: position.latitude,
                longitude: position.longitude,
                timestamp: position.timestamp,
                speedKmh: position.speed.isNaN ? null : position.speed * 3.6,
              ),
            );
            notifyListeners();
          },
          onError: (Object _) {
            _status = GpsTrackingStatus.error;
            notifyListeners();
          },
        );
    return true;
  }

  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
    if (_status == GpsTrackingStatus.tracking) {
      _status = GpsTrackingStatus.idle;
      notifyListeners();
    }
  }

  void clearRoute() {
    _points.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
