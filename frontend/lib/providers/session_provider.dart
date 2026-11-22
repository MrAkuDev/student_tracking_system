import 'package:flutter/foundation.dart';

import '../models/api_results.dart';
import '../models/driver_models.dart';
import '../models/enums.dart';
import '../models/misc_models.dart';
import '../models/route_model.dart';
import '../models/student_model.dart';
import '../services/session_service.dart';

/// Rol actual + datos de sesión (persistidos). Un solo rol activo a la vez.
class SessionProvider extends ChangeNotifier {
  SessionProvider({SessionService? service})
      : _service = service ?? SessionService();

  final SessionService _service;

  UserRole? _role;
  Coordinator? _coordinator;
  Student? _student;
  RouteModel? _tutorRoute;
  SchoolInfo? _school;
  String? _coordinatorPhone;
  DriverRoute? _driverRoute;

  UserRole? get role => _role;
  bool get hasSession => _role != null;

  /// Coordinador autenticado (rol coordinator).
  Coordinator? get coordinator => _coordinator;
  String? get coordinatorId => _coordinator?.id;

  /// Alumno asociado al código del tutor (rol tutor).
  Student? get student => _student;
  String? get studentId => _student?.id;

  /// Ruta del alumno (rol tutor).
  RouteModel? get tutorRoute => _tutorRoute;
  SchoolInfo? get school => _school;

  /// Teléfono del coordinador (tutor y chofer lo reciben al acceder).
  String? get coordinatorPhone => _coordinatorPhone;

  /// Ruta sanitizada del chofer (rol driver).
  DriverRoute? get driverRoute => _driverRoute;
  String? get driverRouteId => _driverRoute?.id;

  /// Lee la sesión guardada (llamar una vez al arrancar).
  Future<void> restore() async {
    final s = await _service.load();
    if (s == null) return;
    _role = s.role;
    _coordinator = s.coordinator;
    _student = s.student;
    _tutorRoute = s.route;
    _school = s.school;
    _coordinatorPhone = s.coordinatorPhone;
    _driverRoute = s.driverRoute;
    // Sesión incompleta → descartar.
    final valid = switch (s.role) {
      UserRole.coordinator => _coordinator != null,
      UserRole.tutor => _student != null && _tutorRoute != null,
      UserRole.driver => _driverRoute != null,
    };
    if (!valid) {
      await logout(notify: false);
    }
  }

  Future<void> loginCoordinator(Coordinator coordinator) async {
    _clearData();
    _role = UserRole.coordinator;
    _coordinator = coordinator;
    _coordinatorPhone = coordinator.phone;
    await _persist();
    notifyListeners();
  }

  Future<void> loginTutor(TutorAccessResult result) async {
    _clearData();
    _role = UserRole.tutor;
    _student = result.student;
    _tutorRoute = result.route;
    _school = result.school;
    _coordinatorPhone = result.coordinatorPhone;
    await _persist();
    notifyListeners();
  }

  Future<void> loginDriver(DriverAccessResult result) async {
    _clearData();
    _role = UserRole.driver;
    _driverRoute = result.route;
    _coordinatorPhone = result.coordinatorPhone;
    await _persist();
    notifyListeners();
  }

  /// Actualiza el alumno (y opcionalmente su ruta) del tutor.
  Future<void> updateStudent(Student student, {RouteModel? route}) async {
    _student = student;
    if (route != null) _tutorRoute = route;
    await _persist();
    notifyListeners();
  }

  /// Actualiza la ruta del chofer (estatus, paradas, polilínea).
  Future<void> updateDriverRoute(DriverRoute route) async {
    _driverRoute = route;
    await _persist();
    notifyListeners();
  }

  /// Cierra sesión y vuelve a "sin rol". La navegación la hace quien llama
  /// (ver `confirmAndLogout` en `widgets/role_switch.dart`).
  Future<void> logout({bool notify = true}) async {
    _clearData();
    await _service.clear();
    if (notify) notifyListeners();
  }

  void _clearData() {
    _role = null;
    _coordinator = null;
    _student = null;
    _tutorRoute = null;
    _school = null;
    _coordinatorPhone = null;
    _driverRoute = null;
  }

  Future<void> _persist() async {
    final role = _role;
    if (role == null) return;
    try {
      await _service.save(SessionSnapshot(
        role: role,
        coordinator: _coordinator,
        student: _student,
        route: _tutorRoute,
        school: _school,
        coordinatorPhone: _coordinatorPhone,
        driverRoute: _driverRoute,
      ));
    } catch (e) {
      debugPrint('SessionProvider._persist falló: $e');
    }
  }
}
