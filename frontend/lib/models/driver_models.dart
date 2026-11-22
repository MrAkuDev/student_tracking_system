import 'package:latlong2/latlong.dart';

import 'enums.dart';
import 'json_utils.dart';
import 'route_model.dart';

/// Parada sanitizada para el chofer: SIN nombres/grados/tutor.
class DriverStop {
  final String studentId; // _id opaco
  final String stopLabel; // "Punto A"
  final int stopOrder;
  final double lat;
  final double lng;
  final PickupStatus status;

  const DriverStop({
    required this.studentId,
    required this.stopLabel,
    required this.stopOrder,
    required this.lat,
    required this.lng,
    this.status = PickupStatus.pending,
  });

  LatLng get latLng => LatLng(lat, lng);

  factory DriverStop.fromJson(Object? json) {
    final m = asMap(json);
    return DriverStop(
      studentId: asString(m['studentId']),
      stopLabel: asString(m['stopLabel']),
      stopOrder: asInt(m['stopOrder']),
      lat: asDouble(m['lat']),
      lng: asDouble(m['lng']),
      status: PickupStatus.parse(asStringOrNull(m['status'])),
    );
  }

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'stopLabel': stopLabel,
        'stopOrder': stopOrder,
        'lat': lat,
        'lng': lng,
        'status': status.value,
      };

  DriverStop copyWith({PickupStatus? status}) => DriverStop(
        studentId: studentId,
        stopLabel: stopLabel,
        stopOrder: stopOrder,
        lat: lat,
        lng: lng,
        status: status ?? this.status,
      );
}

/// Ruta vista por el chofer (sanitizada).
class DriverRoute {
  final String id;
  final String shortCode;
  final String name;
  final String startTime;
  final RouteStatus status;
  final SchoolLocation schoolLocation;
  final List<LatLng> polyline;

  /// Vacío si la ruta aún no fue iniciada por el coordinador.
  final List<DriverStop> stops;

  const DriverRoute({
    required this.id,
    this.shortCode = '',
    this.name = '',
    this.startTime = '07:30',
    this.status = RouteStatus.idle,
    required this.schoolLocation,
    this.polyline = const [],
    this.stops = const [],
  });

  /// La ruta fue iniciada y ya hay paradas listas.
  bool get isReady => status.isActiveTrip && stops.isNotEmpty;

  factory DriverRoute.fromJson(Object? json) {
    final m = asMap(json);
    final stops = asList(m['stops']).map(DriverStop.fromJson).toList()
      ..sort((a, b) => a.stopOrder.compareTo(b.stopOrder));
    return DriverRoute(
      id: asString(m['id'] ?? m['_id']),
      shortCode: asString(m['shortCode']),
      name: asString(m['name']),
      startTime: asString(m['startTime'], '07:30'),
      status: RouteStatus.parse(asStringOrNull(m['status'])),
      schoolLocation: SchoolLocation.fromJson(m['schoolLocation']),
      polyline: parsePolyline(m['polyline']),
      stops: stops,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'shortCode': shortCode,
        'name': name,
        'startTime': startTime,
        'status': status.value,
        'schoolLocation': schoolLocation.toJson(),
        'polyline': polylineToJson(polyline),
        'stops': stops.map((s) => s.toJson()).toList(),
      };

  DriverRoute copyWith({
    RouteStatus? status,
    List<LatLng>? polyline,
    List<DriverStop>? stops,
  }) =>
      DriverRoute(
        id: id,
        shortCode: shortCode,
        name: name,
        startTime: startTime,
        status: status ?? this.status,
        schoolLocation: schoolLocation,
        polyline: polyline ?? this.polyline,
        stops: stops ?? this.stops,
      );
}

/// Parada con nombre (SOLO coordinador): `start` y `live`.
class LiveStop {
  final String studentId;
  final String stopLabel;
  final int stopOrder;
  final double lat;
  final double lng;
  final PickupStatus status;
  final String firstName;
  final String lastName;

  const LiveStop({
    required this.studentId,
    required this.stopLabel,
    required this.stopOrder,
    required this.lat,
    required this.lng,
    this.status = PickupStatus.pending,
    this.firstName = '',
    this.lastName = '',
  });

  String get fullName => '$firstName $lastName'.trim();
  LatLng get latLng => LatLng(lat, lng);

  factory LiveStop.fromJson(Object? json) {
    final m = asMap(json);
    return LiveStop(
      studentId: asString(m['studentId']),
      stopLabel: asString(m['stopLabel']),
      stopOrder: asInt(m['stopOrder']),
      lat: asDouble(m['lat']),
      lng: asDouble(m['lng']),
      status: PickupStatus.parse(asStringOrNull(m['status'])),
      firstName: asString(m['firstName']),
      lastName: asString(m['lastName']),
    );
  }

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'stopLabel': stopLabel,
        'stopOrder': stopOrder,
        'lat': lat,
        'lng': lng,
        'status': status.value,
        'firstName': firstName,
        'lastName': lastName,
      };

  LiveStop copyWith({PickupStatus? status}) => LiveStop(
        studentId: studentId,
        stopLabel: stopLabel,
        stopOrder: stopOrder,
        lat: lat,
        lng: lng,
        status: status ?? this.status,
        firstName: firstName,
        lastName: lastName,
      );
}
