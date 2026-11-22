import 'package:latlong2/latlong.dart';

import 'json_utils.dart';

class Coordinator {
  final String id;
  final String username;
  final String name;
  final String phone;

  const Coordinator({
    required this.id,
    this.username = '',
    this.name = '',
    this.phone = '',
  });

  factory Coordinator.fromJson(Object? json) {
    final m = asMap(json);
    return Coordinator(
      id: asString(m['id'] ?? m['_id']),
      username: asString(m['username']),
      name: asString(m['name']),
      phone: asString(m['phone']),
    );
  }

  Map<String, dynamic> toJson() =>
      {'id': id, 'username': username, 'name': name, 'phone': phone};
}

/// Escuela por defecto (`GET /api/config/school`) o dentro de `tutor/access`.
class SchoolInfo {
  final String name;
  final String address;
  final LatLng location;

  const SchoolInfo({
    required this.name,
    required this.address,
    required this.location,
  });

  factory SchoolInfo.fromJson(Object? json) {
    final m = asMap(json);
    final loc = asMap(m['location']);
    return SchoolInfo(
      name: asString(m['name']),
      address: asString(m['address']),
      location: LatLng(asDouble(loc['lat'], 28.6353), asDouble(loc['lng'], -106.0889)),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'location': {'lat': location.latitude, 'lng': location.longitude},
      };
}

/// Reporte de incidencia.
class Incident {
  final String id;
  final String routeId;
  final String reportedByRole; // 'coordinator' | 'driver'
  final String description;
  final String? involvedStudentId;
  final DateTime? createdAt;

  const Incident({
    required this.id,
    this.routeId = '',
    this.reportedByRole = 'coordinator',
    this.description = '',
    this.involvedStudentId,
    this.createdAt,
  });

  factory Incident.fromJson(Object? json) {
    final m = asMap(json);
    return Incident(
      id: asString(m['id'] ?? m['_id']),
      routeId: asString(m['routeId']),
      reportedByRole: asString(m['reportedByRole'], 'coordinator'),
      description: asString(m['description']),
      involvedStudentId: asStringOrNull(m['involvedStudentId']),
      createdAt: parseDate(m['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'routeId': routeId,
        'reportedByRole': reportedByRole,
        'description': description,
        'involvedStudentId': involvedStudentId,
        'createdAt': createdAt?.toIso8601String(),
      };
}
