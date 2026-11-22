import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import 'enums.dart';
import 'json_utils.dart';

/// `{lat,lng,address}` — destino final de una ruta.
class SchoolLocation {
  final double lat;
  final double lng;
  final String address;

  const SchoolLocation({
    required this.lat,
    required this.lng,
    this.address = '',
  });

  LatLng get latLng => LatLng(lat, lng);

  factory SchoolLocation.fromLatLng(LatLng p, {String address = ''}) =>
      SchoolLocation(lat: p.latitude, lng: p.longitude, address: address);

  factory SchoolLocation.fromJson(Object? json) {
    final m = asMap(json);
    return SchoolLocation(
      lat: asDouble(m['lat'], AppConfig.defaultMapCenter.latitude),
      lng: asDouble(m['lng'], AppConfig.defaultMapCenter.longitude),
      address: asString(m['address']),
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'address': address};

  SchoolLocation copyWith({double? lat, double? lng, String? address}) =>
      SchoolLocation(
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        address: address ?? this.address,
      );
}

/// `{lat,lng,updatedAt}` — última ubicación conocida del autobús.
class BusLocation {
  final double lat;
  final double lng;
  final DateTime? updatedAt;

  const BusLocation({required this.lat, required this.lng, this.updatedAt});

  LatLng get latLng => LatLng(lat, lng);

  static BusLocation? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final m = asMap(json);
    final lat = asDoubleOrNull(m['lat']);
    final lng = asDoubleOrNull(m['lng']);
    if (lat == null || lng == null) return null;
    return BusLocation(lat: lat, lng: lng, updatedAt: parseDate(m['updatedAt']));
  }

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'updatedAt': updatedAt?.toIso8601String(),
      };
}

/// Ruta (vista coordinador/tutor).
class RouteModel {
  final String id;
  final String uuid;
  final String shortCode;
  final String name;
  final String startTime; // "07:30"
  final SchoolLocation schoolLocation;
  final RouteStatus status;
  final BusLocation? currentLocation;
  final List<LatLng> polyline;
  final String? coordinatorId;

  /// Solo vienen en `GET /api/routes` y `GET /api/routes/:id`.
  final int studentCount;
  final int confirmedCount;

  const RouteModel({
    required this.id,
    this.uuid = '',
    this.shortCode = '',
    required this.name,
    this.startTime = '07:30',
    required this.schoolLocation,
    this.status = RouteStatus.idle,
    this.currentLocation,
    this.polyline = const [],
    this.coordinatorId,
    this.studentCount = 0,
    this.confirmedCount = 0,
  });

  factory RouteModel.fromJson(Object? json) {
    final m = asMap(json);
    return RouteModel(
      id: asString(m['id'] ?? m['_id']),
      uuid: asString(m['uuid']),
      shortCode: asString(m['shortCode']),
      name: asString(m['name']),
      startTime: asString(m['startTime'], '07:30'),
      schoolLocation: SchoolLocation.fromJson(m['schoolLocation']),
      status: RouteStatus.parse(asStringOrNull(m['status'])),
      currentLocation: BusLocation.tryFromJson(m['currentLocation']),
      polyline: parsePolyline(m['polyline']),
      coordinatorId: asStringOrNull(m['coordinatorId']),
      studentCount: asInt(m['studentCount']),
      confirmedCount: asInt(m['confirmedCount']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'shortCode': shortCode,
        'name': name,
        'startTime': startTime,
        'schoolLocation': schoolLocation.toJson(),
        'status': status.value,
        'currentLocation': currentLocation?.toJson(),
        'polyline': polylineToJson(polyline),
        'coordinatorId': coordinatorId,
        'studentCount': studentCount,
        'confirmedCount': confirmedCount,
      };

  RouteModel copyWith({
    String? name,
    String? startTime,
    SchoolLocation? schoolLocation,
    RouteStatus? status,
    BusLocation? currentLocation,
    List<LatLng>? polyline,
    int? studentCount,
    int? confirmedCount,
  }) =>
      RouteModel(
        id: id,
        uuid: uuid,
        shortCode: shortCode,
        name: name ?? this.name,
        startTime: startTime ?? this.startTime,
        schoolLocation: schoolLocation ?? this.schoolLocation,
        status: status ?? this.status,
        currentLocation: currentLocation ?? this.currentLocation,
        polyline: polyline ?? this.polyline,
        coordinatorId: coordinatorId,
        studentCount: studentCount ?? this.studentCount,
        confirmedCount: confirmedCount ?? this.confirmedCount,
      );
}
