import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/localization/localization.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/gps_tracking_service.dart';
import '../../core/theme/app_theme.dart';

class RouteMapCard extends StatefulWidget {
  const RouteMapCard({super.key});

  @override
  State<RouteMapCard> createState() => _RouteMapCardState();
}

class _RouteMapCardState extends State<RouteMapCard> {
  final MapController _mapController = MapController();
  bool _autoFollow = true;

  String _t(String key) => AppLocalizations.getText(
    AppStateProvider.of(context).selectedLanguage,
    key,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: GpsTrackingService.instance,
      builder: (context, _) {
        final service = GpsTrackingService.instance;
        final points = service.points
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();

        if (service.status == GpsTrackingStatus.tracking &&
            _autoFollow &&
            points.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted)
              _mapController.move(points.last, _mapController.camera.zoom);
          });
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.map_outlined, color: scheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _t('analysis.routeMapLabel'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  _buildTrackingButton(context, service),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _t('analysis.routeMapNote'),
                style: TextStyle(fontSize: 11, color: scheme.outline),
              ),
              const SizedBox(height: 16),
              if (points.length >= 2) _buildStatsRow(context, service),
              if (points.length >= 2) const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 260,
                  child: points.isEmpty
                      ? _buildEmptyState(context, service)
                      : _buildMap(context, points, service),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrackingButton(
    BuildContext context,
    GpsTrackingService service,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isTracking = service.status == GpsTrackingStatus.tracking;
    final isBusy = service.status == GpsTrackingStatus.requestingPermission;

    return TextButton.icon(
      onPressed: isBusy
          ? null
          : () async {
              if (isTracking) {
                service.stopTracking();
              } else {
                setState(() => _autoFollow = true);
                await service.startTracking();
              }
            },
      icon: isBusy
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            )
          : Icon(
              isTracking
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
              size: 18,
            ),
      label: Text(
        isTracking ? _t('analysis.routeMapStop') : _t('analysis.routeMapStart'),
      ),
      style: TextButton.styleFrom(
        foregroundColor: isTracking ? scheme.error : scheme.primary,
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, GpsTrackingService service) {
    final scheme = Theme.of(context).colorScheme;
    final km = service.totalDistanceMeters / 1000;
    final elapsed = service.elapsed;
    final h = elapsed.inHours.toString().padLeft(2, '0');
    final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');

    return Row(
      children: [
        Icon(Icons.straighten, size: 16, color: scheme.outline),
        const SizedBox(width: 6),
        Text(
          '${km.toStringAsFixed(1)} km',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(width: 16),
        Icon(Icons.schedule, size: 16, color: scheme.outline),
        const SizedBox(width: 6),
        Text(
          '$h:$m',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const Spacer(),
        if (service.points.isNotEmpty)
          TextButton(
            onPressed: service.status == GpsTrackingStatus.tracking
                ? null
                : service.clearRoute,
            child: Text(
              _t('analysis.routeMapClear'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildMap(
    BuildContext context,
    List<LatLng> points,
    GpsTrackingService service,
  ) {
    return GestureDetector(
      onPanStart: (_) => setState(() => _autoFollow = false),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: points.last, initialZoom: 15),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.smarttrack_mine',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 4,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: points.first,
                width: 24,
                height: 24,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.circle, size: 8, color: Colors.white),
                ),
              ),
              if (points.length > 1)
                Marker(
                  point: points.last,
                  width: 32,
                  height: 32,
                  child: Icon(
                    Icons.location_on,
                    color: Theme.of(context).colorScheme.error,
                    size: 32,
                  ),
                ),
            ],
          ),
          const RichAttributionWidget(
            attributions: [
              TextSourceAttribution(
                'OpenStreetMap contributors',
                prependCopyright: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, GpsTrackingService service) {
    final scheme = Theme.of(context).colorScheme;
    final String message;
    switch (service.status) {
      case GpsTrackingStatus.permissionDenied:
        message = _t('analysis.routeMapPermissionDenied');
      case GpsTrackingStatus.serviceDisabled:
        message = _t('analysis.routeMapServiceDisabled');
      case GpsTrackingStatus.error:
        message = _t('analysis.routeMapError');
      case GpsTrackingStatus.requestingPermission:
        message = _t('analysis.routeMapRequesting');
      case GpsTrackingStatus.tracking:
      case GpsTrackingStatus.idle:
        message = _t('analysis.routeMapEmpty');
    }
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_searching, size: 32, color: scheme.outline),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
