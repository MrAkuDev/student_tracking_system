import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/api_results.dart';
import '../models/enums.dart';
import '../models/json_utils.dart';
import '../models/misc_models.dart';
import '../models/route_model.dart';
import '../models/student_model.dart';
import '../models/driver_models.dart';
import '../providers/server_config_provider.dart';

/// Error legible (en español) de cualquier llamada al backend.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// Cliente REST tipado del contrato de `building.md` §3.
/// Lee la URL base del `ServerConfigProvider` en cada llamada.
class ApiService {
  ApiService(this._config, {http.Client? client})
      : _client = client ?? http.Client();

  final ServerConfigProvider _config;
  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 35);

  // ===================== Núcleo HTTP =====================

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    String? baseUrl,
    Duration? timeout,
  }) async {
    final base = baseUrl ?? _config.baseUrl;
    var uri = Uri.parse('$base$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    final encoded = body == null ? null : jsonEncode(body);
    final t = timeout ?? _timeout;

    try {
      http.Response res;
      switch (method) {
        case 'GET':
          res = await _client.get(uri, headers: headers).timeout(t);
          break;
        case 'POST':
          res = await _client
              .post(uri, headers: headers, body: encoded ?? '{}')
              .timeout(t);
          break;
        case 'PUT':
          res = await _client
              .put(uri, headers: headers, body: encoded ?? '{}')
              .timeout(t);
          break;
        case 'PATCH':
          res = await _client
              .patch(uri, headers: headers, body: encoded ?? '{}')
              .timeout(t);
          break;
        case 'DELETE':
          res = await _client.delete(uri, headers: headers).timeout(t);
          break;
        default:
          throw ApiException('Método HTTP no soportado: $method');
      }

      final text = utf8.decode(res.bodyBytes);
      dynamic data;
      if (text.isNotEmpty) {
        try {
          data = jsonDecode(text);
        } on FormatException {
          data = null;
        }
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return data;
      }
      String message = 'Error del servidor (${res.statusCode}).';
      if (data is Map && data['error'] != null) {
        message = data['error'].toString();
      }
      throw ApiException(message, res.statusCode);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
          'El servidor tardó demasiado en responder. Revisa tu conexión.');
    } on SocketException {
      throw const ApiException(
          'No se pudo conectar con el servidor. Revisa la URL en Configuración.');
    } on http.ClientException {
      throw const ApiException(
          'No se pudo conectar con el servidor. Revisa la URL en Configuración.');
    } on HandshakeException {
      throw const ApiException('Error de conexión segura con el servidor.');
    } on FormatException {
      throw const ApiException('URL del servidor inválida.');
    }
  }

  // ===================== Utilidad =====================

  /// `GET /api/health`. Lanza [ApiException] si falla. [baseUrl] permite probar
  /// una URL sin guardarla.
  Future<void> health({String? baseUrl}) async {
    final data = await _send(
      'GET',
      '/api/health',
      baseUrl: baseUrl,
      timeout: const Duration(seconds: 45),
    );
    if (data is Map && data['ok'] == true) return;
    throw const ApiException('El servidor respondió, pero no es un backend STS.');
  }

  /// `GET /api/config/school`
  Future<SchoolInfo> getSchoolConfig() async =>
      SchoolInfo.fromJson(await _send('GET', '/api/config/school'));

  /// `POST /api/admin/reset-db` — borra rutas, alumnos e incidentes, conservando
  /// el coordinador por defecto (admin/1234) y la escuela base.
  Future<String> resetDatabase({String? baseUrl}) async {
    final data = await _send(
      'POST',
      '/api/admin/reset-db',
      baseUrl: baseUrl,
      timeout: const Duration(seconds: 45),
    );
    return asString(
      asMap(data)['message'],
      'Base de datos reiniciada correctamente.',
    );
  }

  /// `POST /api/admin/seed-demo` — reinicia y carga el dataset demo.
  Future<String> seedDemoDatabase({String? baseUrl}) async {
    final data = await _send(
      'POST',
      '/api/admin/seed-demo',
      baseUrl: baseUrl,
      timeout: const Duration(seconds: 45),
    );
    return asString(
      asMap(data)['message'],
      'Seed demo cargado correctamente.',
    );
  }

  // ===================== Auth / acceso =====================

  /// `POST /api/coordinator/login`
  Future<Coordinator> coordinatorLogin(String username, String password) async {
    final data = await _send('POST', '/api/coordinator/login',
        body: {'username': username.trim(), 'password': password});
    return Coordinator.fromJson(asMap(data)['coordinator']);
  }

  /// `POST /api/tutor/access` (code = shortCode o uuid del alumno)
  Future<TutorAccessResult> tutorAccess(String code) async =>
      TutorAccessResult.fromJson(
          await _send('POST', '/api/tutor/access', body: {'code': code.trim()}));

  /// `POST /api/driver/access` (code = shortCode o uuid de la ruta)
  Future<DriverAccessResult> driverAccess(String code) async =>
      DriverAccessResult.fromJson(
          await _send('POST', '/api/driver/access', body: {'code': code.trim()}));

  // ===================== Coordinador =====================

  /// `GET /api/routes`
  Future<List<RouteModel>> getRoutes({String? coordinatorId}) async {
    final data = await _send('GET', '/api/routes',
        query: coordinatorId == null ? null : {'coordinatorId': coordinatorId});
    return asList(data).map(RouteModel.fromJson).toList();
  }

  /// `POST /api/routes`
  Future<RouteModel> createRoute({
    String? name,
    String? startTime,
    SchoolLocation? schoolLocation,
    String? coordinatorId,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (startTime != null) body['startTime'] = startTime;
    if (schoolLocation != null) body['schoolLocation'] = schoolLocation.toJson();
    if (coordinatorId != null) body['coordinatorId'] = coordinatorId;
    return RouteModel.fromJson(await _send('POST', '/api/routes', body: body));
  }

  /// `GET /api/routes/:id`
  Future<RouteDetailResult> getRoute(String routeId) async =>
      RouteDetailResult.fromJson(await _send('GET', '/api/routes/$routeId'));

  /// `PUT /api/routes/:id`
  Future<RouteModel> updateRoute(
    String routeId, {
    String? name,
    String? startTime,
    SchoolLocation? schoolLocation,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (startTime != null) body['startTime'] = startTime;
    if (schoolLocation != null) body['schoolLocation'] = schoolLocation.toJson();
    return RouteModel.fromJson(
        await _send('PUT', '/api/routes/$routeId', body: body));
  }

  /// `DELETE /api/routes/:id`
  Future<void> deleteRoute(String routeId) async {
    await _send('DELETE', '/api/routes/$routeId');
  }

  /// `POST /api/routes/:id/students`
  Future<Student> createStudent(String routeId, StudentPayload payload) async =>
      Student.fromJson(await _send('POST', '/api/routes/$routeId/students',
          body: payload.toJson()));

  /// `PUT /api/students/:id`
  Future<Student> updateStudent(String studentId, StudentPayload payload) async =>
      Student.fromJson(
          await _send('PUT', '/api/students/$studentId', body: payload.toJson()));

  /// `DELETE /api/students/:id`
  Future<void> deleteStudent(String studentId) async {
    await _send('DELETE', '/api/students/$studentId');
  }

  /// `POST /api/routes/:id/start` — 409 si ya está en curso; 400 si no hay
  /// alumnos confirmados ("No hay alumnos confirmados para hoy").
  Future<StartRouteResult> startRoute(String routeId) async =>
      StartRouteResult.fromJson(await _send('POST', '/api/routes/$routeId/start'));

  /// `PUT /api/routes/:id/polyline`
  Future<void> saveRoutePolyline(String routeId, List<LatLng> polyline) async {
    await _send('PUT', '/api/routes/$routeId/polyline',
        body: {'polyline': polylineToJson(polyline)});
  }

  /// `PATCH /api/routes/:id/status` (solo inProgress | paused | breakdown)
  Future<RouteModel> setRouteStatus(String routeId, RouteStatus status) async =>
      RouteModel.fromJson(await _send('PATCH', '/api/routes/$routeId/status',
          body: {'status': status.value}));

  /// `POST /api/routes/:id/arrived-school`
  Future<RouteModel> markArrivedSchool(String routeId) async =>
      RouteModel.fromJson(
          await _send('POST', '/api/routes/$routeId/arrived-school'));

  /// `POST /api/routes/:id/confirm-arrival`
  Future<RouteModel> confirmArrival(String routeId) async =>
      RouteModel.fromJson(
          await _send('POST', '/api/routes/$routeId/confirm-arrival'));

  /// `POST /api/routes/:id/incidents`
  Future<Incident> reportIncident(
    String routeId, {
    required String description,
    String? involvedStudentId,
    String reportedByRole = 'coordinator',
  }) async {
    final body = <String, dynamic>{
      'description': description,
      'reportedByRole': reportedByRole,
    };
    if (involvedStudentId != null) body['involvedStudentId'] = involvedStudentId;
    final data =
        await _send('POST', '/api/routes/$routeId/incidents', body: body);
    return Incident.fromJson(asMap(data)['incident']);
  }

  /// `GET /api/routes/:id/live`
  Future<LiveRouteResult> getRouteLive(String routeId) async =>
      LiveRouteResult.fromJson(await _send('GET', '/api/routes/$routeId/live'));

  // ===================== Tutor =====================

  /// `GET /api/tutor/students/:id`
  Future<StudentRefreshResult> getTutorStudent(String studentId) async =>
      StudentRefreshResult.fromJson(
          await _send('GET', '/api/tutor/students/$studentId'));

  /// `PUT /api/tutor/students/:id/profile`. Si se envía [pickupLocation] el
  /// backend marca `isSet = true`.
  Future<Student> updateTutorProfile(
    String studentId, {
    TutorInfo? tutor,
    String? firstName,
    String? lastName,
    String? grade,
    LatLng? pickupLocation,
  }) async {
    final body = <String, dynamic>{};
    if (tutor != null) body['tutor'] = tutor.toJson();
    if (firstName != null) body['firstName'] = firstName;
    if (lastName != null) body['lastName'] = lastName;
    if (grade != null) body['grade'] = grade;
    if (pickupLocation != null) {
      body['pickupLocation'] = {
        'lat': pickupLocation.latitude,
        'lng': pickupLocation.longitude,
      };
    }
    return Student.fromJson(await _send(
        'PUT', '/api/tutor/students/$studentId/profile',
        body: body));
  }

  /// `PATCH /api/tutor/students/:id/schedule` (day: monday..friday)
  Future<Student> setTutorSchedule(
    String studentId, {
    required String day,
    required bool enabled,
  }) async =>
      Student.fromJson(await _send(
          'PATCH', '/api/tutor/students/$studentId/schedule',
          body: {'day': day, 'enabled': enabled}));

  /// `POST /api/tutor/students/:id/today-confirmation`
  Future<Student> setTodayConfirmation(
    String studentId, {
    required bool confirmed,
  }) async =>
      Student.fromJson(await _send(
          'POST', '/api/tutor/students/$studentId/today-confirmation',
          body: {'decision': confirmed ? 'confirmed' : 'rejected'}));

  /// `GET /api/tutor/students/:id/live`
  Future<TutorLiveResult> getTutorLive(String studentId) async =>
      TutorLiveResult.fromJson(
          await _send('GET', '/api/tutor/students/$studentId/live'));

  // ===================== Chofer =====================

  /// `GET /api/driver/routes/:routeId/stops`
  Future<DriverRoute> getDriverStops(String routeId) async =>
      DriverRoute.fromJson(
          await _send('GET', '/api/driver/routes/$routeId/stops'));

  /// `POST /api/driver/routes/:routeId/confirm-pickup`
  Future<List<DriverStop>> confirmPickup(
      String routeId, String studentId) async {
    final data = await _send('POST', '/api/driver/routes/$routeId/confirm-pickup',
        body: {'studentId': studentId});
    return asList(asMap(data)['stops']).map(DriverStop.fromJson).toList();
  }

  /// `POST /api/driver/routes/:routeId/sos`
  Future<SosResult> sendSos(String routeId) async =>
      SosResult.fromJson(await _send('POST', '/api/driver/routes/$routeId/sos'));

  /// `POST /api/driver/routes/:routeId/arrived-school` (simulación)
  Future<void> driverArrivedSchool(String routeId) async {
    await _send('POST', '/api/driver/routes/$routeId/arrived-school');
  }

  void dispose() => _client.close();
}
