import 'package:latlong2/latlong.dart';

import 'driver_models.dart';
import 'json_utils.dart';
import 'misc_models.dart';
import 'route_model.dart';
import 'student_model.dart';

/// Respuesta de `POST /api/tutor/access`.
class TutorAccessResult {
  final Student student;
  final RouteModel route;
  final String coordinatorPhone;
  final SchoolInfo? school;

  const TutorAccessResult({
    required this.student,
    required this.route,
    this.coordinatorPhone = '',
    this.school,
  });

  factory TutorAccessResult.fromJson(Object? json) {
    final m = asMap(json);
    return TutorAccessResult(
      student: Student.fromJson(m['student']),
      route: RouteModel.fromJson(m['route']),
      coordinatorPhone: asString(m['coordinatorPhone']),
      school: m['school'] == null ? null : SchoolInfo.fromJson(m['school']),
    );
  }
}

/// Respuesta de `POST /api/driver/access`.
class DriverAccessResult {
  final DriverRoute route;
  final String coordinatorPhone;

  const DriverAccessResult({required this.route, this.coordinatorPhone = ''});

  factory DriverAccessResult.fromJson(Object? json) {
    final m = asMap(json);
    return DriverAccessResult(
      route: DriverRoute.fromJson(m['route']),
      coordinatorPhone: asString(m['coordinatorPhone']),
    );
  }
}

/// `GET /api/routes/:id`
class RouteDetailResult {
  final RouteModel route;
  final List<Student> students;
  const RouteDetailResult({required this.route, required this.students});

  factory RouteDetailResult.fromJson(Object? json) {
    final m = asMap(json);
    return RouteDetailResult(
      route: RouteModel.fromJson(m['route']),
      students: asList(m['students']).map(Student.fromJson).toList(),
    );
  }
}

/// `POST /api/routes/:id/start`
class StartRouteResult {
  final RouteModel route;
  final List<LiveStop> stops;
  const StartRouteResult({required this.route, required this.stops});

  factory StartRouteResult.fromJson(Object? json) {
    final m = asMap(json);
    final stops = asList(m['stops']).map(LiveStop.fromJson).toList()
      ..sort((a, b) => a.stopOrder.compareTo(b.stopOrder));
    return StartRouteResult(route: RouteModel.fromJson(m['route']), stops: stops);
  }
}

/// `GET /api/routes/:id/live`
class LiveRouteResult {
  final RouteModel route;
  final List<LiveStop> stops;
  final bool sosActive;
  const LiveRouteResult({
    required this.route,
    required this.stops,
    this.sosActive = false,
  });

  factory LiveRouteResult.fromJson(Object? json) {
    final m = asMap(json);
    final stops = asList(m['stops']).map(LiveStop.fromJson).toList()
      ..sort((a, b) => a.stopOrder.compareTo(b.stopOrder));
    return LiveRouteResult(
      route: RouteModel.fromJson(m['route']),
      stops: stops,
      sosActive: asBool(m['sosActive']),
    );
  }
}

/// `GET /api/tutor/students/:id` (refrescar estado)
class StudentRefreshResult {
  final Student student;
  final RouteModel route;
  const StudentRefreshResult({required this.student, required this.route});

  factory StudentRefreshResult.fromJson(Object? json) {
    final m = asMap(json);
    return StudentRefreshResult(
      student: Student.fromJson(m['student']),
      route: RouteModel.fromJson(m['route']),
    );
  }
}

class TutorLiveStop {
  final double lat;
  final double lng;
  final int stopOrder;
  const TutorLiveStop({
    required this.lat,
    required this.lng,
    required this.stopOrder,
  });

  LatLng get latLng => LatLng(lat, lng);

  factory TutorLiveStop.fromJson(Object? json) {
    final m = asMap(json);
    return TutorLiveStop(
      lat: asDouble(m['lat']),
      lng: asDouble(m['lng']),
      stopOrder: asInt(m['stopOrder']),
    );
  }
}

/// `GET /api/tutor/students/:id/live`
class TutorLiveResult {
  final RouteModel route;
  final Student student;
  final List<TutorLiveStop> stops;
  const TutorLiveResult({
    required this.route,
    required this.student,
    required this.stops,
  });

  factory TutorLiveResult.fromJson(Object? json) {
    final m = asMap(json);
    final stops = asList(m['stops']).map(TutorLiveStop.fromJson).toList()
      ..sort((a, b) => a.stopOrder.compareTo(b.stopOrder));
    return TutorLiveResult(
      route: RouteModel.fromJson(m['route']),
      student: Student.fromJson(m['student']),
      stops: stops,
    );
  }
}

/// `POST /api/driver/routes/:routeId/sos`
class SosResult {
  final String status;
  final String coordinatorPhone;
  const SosResult({this.status = 'paused', this.coordinatorPhone = ''});

  factory SosResult.fromJson(Object? json) {
    final m = asMap(json);
    return SosResult(
      status: asString(m['status'], 'paused'),
      coordinatorPhone: asString(m['coordinatorPhone']),
    );
  }
}
