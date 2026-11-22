import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../models/json_utils.dart';

/// Geometría de una ruta calculada (OSRM) o de respaldo (línea recta).
class RouteGeometry {
  final List<LatLng> points;
  final double? distanceMeters;
  final double? durationSeconds;

  /// `true` si OSRM no respondió y se usó línea recta entre waypoints.
  final bool isFallback;

  const RouteGeometry({
    required this.points,
    this.distanceMeters,
    this.durationSeconds,
    this.isFallback = false,
  });
}

class OsrmService {
  OsrmService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// Línea recta entre waypoints (fallback).
  static RouteGeometry straightLine(List<LatLng> waypoints) =>
      RouteGeometry(points: List<LatLng>.from(waypoints), isFallback: true);

  /// Ruta por calles pasando por [waypoints] en orden (paradas + escuela).
  /// Nunca lanza: ante error/timeout devuelve [straightLine].
  Future<RouteGeometry> fetchRoute(
    List<LatLng> waypoints, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (waypoints.length < 2) return straightLine(waypoints);
    final coords =
        waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
    final uri = Uri.parse(
        '${AppConfig.osrmBaseUrl}/$coords?overview=full&geometries=geojson');
    try {
      final res = await _client.get(uri).timeout(timeout);
      if (res.statusCode != 200) return straightLine(waypoints);
      final data = asMap(jsonDecode(utf8.decode(res.bodyBytes)));
      if (data['code'] != 'Ok') return straightLine(waypoints);
      final routes = asList(data['routes']);
      if (routes.isEmpty) return straightLine(waypoints);
      final route = asMap(routes.first);
      final coordinates = asList(asMap(route['geometry'])['coordinates']);
      final points = <LatLng>[];
      for (final c in coordinates) {
        if (c is List && c.length >= 2) {
          final lng = asDoubleOrNull(c[0]);
          final lat = asDoubleOrNull(c[1]);
          if (lat != null && lng != null) points.add(LatLng(lat, lng));
        }
      }
      if (points.length < 2) return straightLine(waypoints);
      return RouteGeometry(
        points: points,
        distanceMeters: asDoubleOrNull(route['distance']),
        durationSeconds: asDoubleOrNull(route['duration']),
      );
    } catch (e) {
      debugPrint('OsrmService: usando línea recta ($e)');
      return straightLine(waypoints);
    }
  }
}
