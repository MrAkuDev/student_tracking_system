import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/driver_models.dart';
import '../models/enums.dart';
import '../models/json_utils.dart';
import '../models/misc_models.dart';
import '../models/route_model.dart';
import '../models/student_model.dart';

/// Datos de sesión persistidos (un único JSON en SharedPreferences).
class SessionSnapshot {
  final UserRole role;
  final Coordinator? coordinator;
  final Student? student;
  final RouteModel? route; // ruta del tutor
  final SchoolInfo? school;
  final String? coordinatorPhone;
  final DriverRoute? driverRoute;

  const SessionSnapshot({
    required this.role,
    this.coordinator,
    this.student,
    this.route,
    this.school,
    this.coordinatorPhone,
    this.driverRoute,
  });

  Map<String, dynamic> toJson() => {
        'role': role.value,
        'coordinator': coordinator?.toJson(),
        'student': student?.toJson(),
        'route': route?.toJson(),
        'school': school?.toJson(),
        'coordinatorPhone': coordinatorPhone,
        'driverRoute': driverRoute?.toJson(),
      };

  static SessionSnapshot? fromJson(Object? json) {
    final m = asMap(json);
    final role = UserRole.tryParse(asStringOrNull(m['role']));
    if (role == null) return null;
    return SessionSnapshot(
      role: role,
      coordinator:
          m['coordinator'] == null ? null : Coordinator.fromJson(m['coordinator']),
      student: m['student'] == null ? null : Student.fromJson(m['student']),
      route: m['route'] == null ? null : RouteModel.fromJson(m['route']),
      school: m['school'] == null ? null : SchoolInfo.fromJson(m['school']),
      coordinatorPhone: asStringOrNull(m['coordinatorPhone']),
      driverRoute:
          m['driverRoute'] == null ? null : DriverRoute.fromJson(m['driverRoute']),
    );
  }
}

class SessionService {
  static const String _key = 'sts_session_v1';

  Future<void> save(SessionSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(snapshot.toJson()));
  }

  Future<SessionSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SessionSnapshot.fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('SessionService.load: sesión corrupta, se descarta ($e)');
      await prefs.remove(_key);
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
