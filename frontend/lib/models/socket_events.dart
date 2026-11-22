import 'package:latlong2/latlong.dart';

import 'enums.dart';
import 'json_utils.dart';

/// Payloads tipados de los eventos Socket.IO servidor → cliente.

class BusLocationEvent {
  final String routeId;
  final double lat;
  final double lng;
  final DateTime? updatedAt;
  const BusLocationEvent({
    required this.routeId,
    required this.lat,
    required this.lng,
    this.updatedAt,
  });
  LatLng get latLng => LatLng(lat, lng);

  factory BusLocationEvent.fromJson(Map<String, dynamic> m) => BusLocationEvent(
        routeId: asString(m['routeId']),
        lat: asDouble(m['lat']),
        lng: asDouble(m['lng']),
        updatedAt: parseDate(m['updatedAt']),
      );
}

class RouteStatusEvent {
  final String routeId;
  final RouteStatus status;
  final String? reason; // 'sos' | 'manual' | 'auto'
  const RouteStatusEvent({
    required this.routeId,
    required this.status,
    this.reason,
  });

  factory RouteStatusEvent.fromJson(Map<String, dynamic> m) => RouteStatusEvent(
        routeId: asString(m['routeId']),
        status: RouteStatus.parse(asStringOrNull(m['status'])),
        reason: asStringOrNull(m['reason']),
      );
}

class RouteStartedEvent {
  final String routeId;
  const RouteStartedEvent({required this.routeId});
  factory RouteStartedEvent.fromJson(Map<String, dynamic> m) =>
      RouteStartedEvent(routeId: asString(m['routeId']));
}

class PolylineEvent {
  final String routeId;
  final List<LatLng> polyline;
  const PolylineEvent({required this.routeId, required this.polyline});
  factory PolylineEvent.fromJson(Map<String, dynamic> m) => PolylineEvent(
        routeId: asString(m['routeId']),
        polyline: parsePolyline(m['polyline']),
      );
}

class PickupUpdateEvent {
  final String routeId;
  final String studentId;
  final PickupStatus pickupStatus;
  final String? stopLabel;
  const PickupUpdateEvent({
    required this.routeId,
    required this.studentId,
    required this.pickupStatus,
    this.stopLabel,
  });
  factory PickupUpdateEvent.fromJson(Map<String, dynamic> m) =>
      PickupUpdateEvent(
        routeId: asString(m['routeId']),
        studentId: asString(m['studentId']),
        pickupStatus: PickupStatus.parse(asStringOrNull(m['pickupStatus'])),
        stopLabel: asStringOrNull(m['stopLabel']),
      );
}

class ProximityEvent {
  final String routeId;
  final String studentId;
  final String type; // 'approaching' | 'arrived_stop'
  final double distance; // metros
  const ProximityEvent({
    required this.routeId,
    required this.studentId,
    required this.type,
    required this.distance,
  });
  bool get isApproaching => type == 'approaching';
  bool get isArrivedStop => type == 'arrived_stop';

  factory ProximityEvent.fromJson(Map<String, dynamic> m) => ProximityEvent(
        routeId: asString(m['routeId']),
        studentId: asString(m['studentId']),
        type: asString(m['type']),
        distance: asDouble(m['distance']),
      );
}

class SosEvent {
  final String routeId;
  final DateTime? at;
  const SosEvent({required this.routeId, this.at});
  factory SosEvent.fromJson(Map<String, dynamic> m) =>
      SosEvent(routeId: asString(m['routeId']), at: parseDate(m['at']));
}

class TripCompletedEvent {
  final String routeId;
  const TripCompletedEvent({required this.routeId});
  factory TripCompletedEvent.fromJson(Map<String, dynamic> m) =>
      TripCompletedEvent(routeId: asString(m['routeId']));
}

class StudentServiceEvent {
  final String routeId;
  final String studentId;
  final TodayServiceStatus todayServiceStatus;
  const StudentServiceEvent({
    required this.routeId,
    required this.studentId,
    required this.todayServiceStatus,
  });
  factory StudentServiceEvent.fromJson(Map<String, dynamic> m) =>
      StudentServiceEvent(
        routeId: asString(m['routeId']),
        studentId: asString(m['studentId']),
        todayServiceStatus:
            TodayServiceStatus.parse(asStringOrNull(m['todayServiceStatus'])),
      );
}
