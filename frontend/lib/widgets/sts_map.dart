import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';

/// Marcador de parada para [StsMap].
class StsStopMarker {
  final LatLng point;
  final String label;
  final bool pickedUp;
  final bool highlighted;

  const StsStopMarker({
    required this.point,
    required this.label,
    this.pickedUp = false,
    this.highlighted = false,
  });
}

/// Mapa reutilizable basado en `flutter_map` + OpenStreetMap (con caché de tiles
/// integrada en flutter_map 8.2). Soporta polilínea, paradas, escuela, autobús,
/// pin seleccionable y toque en el mapa.
class StsMap extends StatelessWidget {
  const StsMap({
    super.key,
    this.controller,
    this.initialCenter,
    this.initialZoom = AppConfig.defaultZoom,
    this.polyline = const [],
    this.stops = const [],
    this.schoolPoint,
    this.schoolLabel = 'Escuela',
    this.busPoint,
    this.pickupPin,
    this.onTap,
    this.borderRadius = 16,
  });

  final MapController? controller;
  final LatLng? initialCenter;
  final double initialZoom;
  final List<LatLng> polyline;
  final List<StsStopMarker> stops;
  final LatLng? schoolPoint;
  final String schoolLabel;
  final LatLng? busPoint;
  final LatLng? pickupPin;
  final void Function(LatLng point)? onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final center = initialCenter ??
        busPoint ??
        pickupPin ??
        schoolPoint ??
        (stops.isNotEmpty ? stops.first.point : AppConfig.defaultMapCenter);

    final markers = <Marker>[
      for (final s in stops)
        Marker(
          point: s.point,
          width: 96,
          height: 54,
          alignment: Alignment.topCenter,
          child: _StopPin(stop: s),
        ),
      if (schoolPoint != null)
        Marker(
          point: schoolPoint!,
          width: 96,
          height: 54,
          alignment: Alignment.topCenter,
          child: _SchoolPin(label: schoolLabel),
        ),
      if (pickupPin != null)
        Marker(
          point: pickupPin!,
          width: 48,
          height: 48,
          alignment: Alignment.topCenter,
          child: const Icon(
            Icons.location_pin,
            size: 46,
            color: AppColors.primary,
          ),
        ),
      if (busPoint != null)
        Marker(
          point: busPoint!,
          width: 48,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_bus,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
    ];

    final map = FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: initialZoom,
        onTap: onTap == null ? null : (_, latLng) => onTap!(latLng),
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.osmTileUrl,
          userAgentPackageName: AppConfig.userAgentPackage,
        ),
        if (polyline.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: polyline,
                color: AppColors.primary,
                strokeWidth: 5,
              ),
            ],
          ),
        MarkerLayer(markers: markers),
      ],
    );

    if (borderRadius <= 0) return map;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: map,
    );
  }
}

class _StopPin extends StatelessWidget {
  const _StopPin({required this.stop});
  final StsStopMarker stop;

  @override
  Widget build(BuildContext context) {
    final color = stop.pickedUp
        ? AppColors.success
        : (stop.highlighted ? AppColors.warning : AppColors.primary);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(
            stop.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        Icon(
          stop.pickedUp ? Icons.check_circle : Icons.location_on,
          color: color,
          size: 28,
        ),
      ],
    );
  }
}

class _SchoolPin extends StatelessWidget {
  const _SchoolPin({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.school,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const Icon(Icons.school, color: AppColors.school, size: 28),
      ],
    );
  }
}
