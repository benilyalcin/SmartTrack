class RoutePoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? speedKmh;

  const RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speedKmh,
  });
}
