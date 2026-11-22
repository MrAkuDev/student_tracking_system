import 'package:flutter/material.dart';

import '../models/enums.dart';

/// Paleta oficial de STS (sección 3 del prompt).
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2563EB);
  static const Color primaryContainer = Color(0xFFDBEAFE);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);

  // Semánticos
  static const Color success = Color(0xFF16A34A); // confirmado / recogido
  static const Color pending = Color(0xFF2563EB); // pendiente
  static const Color warning = Color(0xFFD97706); // en pausa / acercándose
  static const Color sos = Color(0xFFDC2626); // SOS / avería / reportar

  /// Color del marcador de la escuela.
  static const Color school = Color(0xFF0F172A);

  /// Fondo suave (alpha ~12 %) para chips/banners de un color semántico.
  static Color tint(Color c) => c.withAlpha(30);

  static Color forRoute(RouteStatus s) {
    switch (s) {
      case RouteStatus.idle:
        return textSecondary;
      case RouteStatus.inProgress:
        return primary;
      case RouteStatus.paused:
        return warning;
      case RouteStatus.breakdown:
        return sos;
      case RouteStatus.arrivedSchool:
        return success;
      case RouteStatus.completed:
        return success;
    }
  }

  static Color forPickup(PickupStatus s) {
    switch (s) {
      case PickupStatus.pending:
        return pending;
      case PickupStatus.approaching:
        return warning;
      case PickupStatus.arrivedStop:
        return warning;
      case PickupStatus.pickedUp:
        return success;
      case PickupStatus.droppedAtSchool:
        return success;
    }
  }

  static Color forService(TodayServiceStatus s) {
    switch (s) {
      case TodayServiceStatus.pending:
        return textSecondary;
      case TodayServiceStatus.confirmed:
        return success;
      case TodayServiceStatus.rejected:
        return sos;
    }
  }
}
