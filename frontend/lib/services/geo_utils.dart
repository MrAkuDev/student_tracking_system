import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';

/// Utilidades geográficas (distancias en metros).
class GeoUtils {
  GeoUtils._();

  static const double _earthRadius = 6371000.0;

  static double _rad(double deg) => deg * math.pi / 180.0;

  /// Distancia Haversine entre dos puntos, en metros.
  static double haversineMeters(LatLng a, LatLng b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * _earthRadius * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// Distancia de [p] al segmento [a]-[b], en metros (proyección local plana).
  static double distanceToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    final refLat = _rad(p.latitude);
    final kx = _earthRadius * math.cos(refLat);
    const ky = _earthRadius;
    double x(LatLng q) => _rad(q.longitude - p.longitude) * kx;
    double y(LatLng q) => _rad(q.latitude - p.latitude) * ky;

    final ax = x(a), ay = y(a), bx = x(b), by = y(b);
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    double t = 0;
    if (len2 > 0) {
      t = ((0 - ax) * dx + (0 - ay) * dy) / len2;
      t = t.clamp(0.0, 1.0);
    }
    final cx = ax + t * dx, cy = ay + t * dy;
    return math.sqrt(cx * cx + cy * cy);
  }

  /// Distancia mínima de [p] a una polilínea, en metros. `double.infinity` si
  /// la polilínea está vacía.
  static double distanceToPolylineMeters(LatLng p, List<LatLng> line) {
    if (line.isEmpty) return double.infinity;
    if (line.length == 1) return haversineMeters(p, line.first);
    var best = double.infinity;
    for (var i = 0; i < line.length - 1; i++) {
      final d = distanceToSegmentMeters(p, line[i], line[i + 1]);
      if (d < best) best = d;
    }
    return best;
  }

  /// Longitud total de una polilínea en metros.
  static double polylineLengthMeters(List<LatLng> line) {
    var total = 0.0;
    for (var i = 0; i < line.length - 1; i++) {
      total += haversineMeters(line[i], line[i + 1]);
    }
    return total;
  }

  /// Interpolación lineal entre dos puntos (t ∈ [0,1]).
  static LatLng lerp(LatLng a, LatLng b, double t) => LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );

  /// Densifica una polilínea insertando puntos cada [stepMeters] aprox., para
  /// simular el avance suave del autobús (un punto por tick).
  static List<LatLng> densify(List<LatLng> line, {double stepMeters = 20}) {
    if (line.length < 2) return List<LatLng>.from(line);
    final out = <LatLng>[line.first];
    for (var i = 0; i < line.length - 1; i++) {
      final a = line[i];
      final b = line[i + 1];
      final d = haversineMeters(a, b);
      final n = math.max(1, (d / stepMeters).ceil());
      for (var k = 1; k <= n; k++) {
        out.add(lerp(a, b, k / n));
      }
    }
    return out;
  }

  /// Índice del punto de [path] más cercano a [target] (buscando desde
  /// [startFrom], útil para avanzar a la siguiente parada en simulación).
  static int indexOfClosest(List<LatLng> path, LatLng target,
      {int startFrom = 0}) {
    if (path.isEmpty) return 0;
    var bestIdx = math.min(math.max(0, startFrom), path.length - 1);
    var bestDist = double.infinity;
    for (var i = bestIdx; i < path.length; i++) {
      final d = haversineMeters(path[i], target);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  /// Rumbo (grados, 0 = norte) de [a] hacia [b].
  static double bearingDegrees(LatLng a, LatLng b) {
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Límites que contienen todos los [points] (null si la lista está vacía).
  static LatLngBounds? boundsOf(Iterable<LatLng> points) {
    final list = points.toList();
    if (list.isEmpty) return null;
    return LatLngBounds.fromPoints(list);
  }

  /// "320 m" / "1.2 km"
  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
