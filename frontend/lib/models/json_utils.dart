import 'package:latlong2/latlong.dart';

/// Utilidades de parseo JSON tolerantes (números como num/String, nulos...).

double? asDoubleOrNull(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

double asDouble(Object? v, [double fallback = 0]) =>
    asDoubleOrNull(v) ?? fallback;

int? asIntOrNull(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

int asInt(Object? v, [int fallback = 0]) => asIntOrNull(v) ?? fallback;

String asString(Object? v, [String fallback = '']) =>
    v == null ? fallback : v.toString();

String? asStringOrNull(Object? v) => v?.toString();

bool asBool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;

Map<String, dynamic> asMap(Object? v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

List<dynamic> asList(Object? v) => v is List ? v : const <dynamic>[];

DateTime? parseDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// `[[lat,lng],...]` → `List<LatLng>`.
List<LatLng> parsePolyline(Object? v) {
  final out = <LatLng>[];
  for (final p in asList(v)) {
    if (p is List && p.length >= 2) {
      final lat = asDoubleOrNull(p[0]);
      final lng = asDoubleOrNull(p[1]);
      if (lat != null && lng != null) out.add(LatLng(lat, lng));
    }
  }
  return out;
}

/// `List<LatLng>` → `[[lat,lng],...]`.
List<List<double>> polylineToJson(List<LatLng> points) =>
    points.map((p) => <double>[p.latitude, p.longitude]).toList();
