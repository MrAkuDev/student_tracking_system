import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'geo_utils.dart';
import 'osrm_service.dart';

/// Resultado del cálculo de hora estimada de llegada.
class EtaEstimate {
  /// Hora estimada de llegada al destino (punto del tutor o escuela).
  final DateTime arrivalAt;

  /// Duración restante estimada.
  final Duration remaining;

  /// `true` si se calculó con OSRM (calles); `false` si es aproximación.
  final bool fromRouting;

  const EtaEstimate({
    required this.arrivalAt,
    required this.remaining,
    required this.fromRouting,
  });
}

/// Puntualidad del viaje respecto a la primera estimación.
enum Punctuality { onTime, delayed, unknown }

/// Cálculo de ETA y puntualidad para el seguimiento en vivo.
///
/// - ETA: ruta por calles (OSRM) desde el autobús pasando por las paradas
///   pendientes hasta el destino, + [stopDwell] por cada parada intermedia.
///   Si OSRM falla, usa distancia en línea recta × 1.35 a [fallbackSpeedKmh].
/// - Puntualidad: se compara la ETA actual contra la primera ETA calculada
///   del viaje (línea base, persistida). Si se atrasa más de [delayTolerance]
///   se considera "Con retraso".
class EtaService {
  EtaService(this._osrm);

  final OsrmService _osrm;

  static const Duration stopDwell = Duration(minutes: 1);
  static const double fallbackSpeedKmh = 25;
  static const double _roadFactor = 1.35;
  static const Duration delayTolerance = Duration(minutes: 5);

  /// [waypoints]: autobús → paradas intermedias → destino.
  Future<EtaEstimate?> estimate(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return null;
    final intermediateStops = waypoints.length - 2;
    final dwell = stopDwell * intermediateStops;

    final geo = await _osrm.fetchRoute(
      waypoints,
      timeout: const Duration(seconds: 8),
    );
    Duration travel;
    bool fromRouting;
    if (!geo.isFallback && geo.durationSeconds != null) {
      travel = Duration(seconds: geo.durationSeconds!.round());
      fromRouting = true;
    } else {
      var meters = 0.0;
      for (var i = 0; i < waypoints.length - 1; i++) {
        meters += GeoUtils.haversineMeters(waypoints[i], waypoints[i + 1]);
      }
      final seconds = (meters * _roadFactor) / (fallbackSpeedKmh * 1000 / 3600);
      travel = Duration(seconds: seconds.round());
      fromRouting = false;
    }
    final remaining = travel + dwell;
    return EtaEstimate(
      arrivalAt: DateTime.now().add(remaining),
      remaining: remaining,
      fromRouting: fromRouting,
    );
  }

  // ---------------- Línea base (persistida por viaje) ----------------

  static String _key(String routeId, String studentId, String phase) =>
      'sts_eta_base_${routeId}_${studentId}_$phase';

  /// Devuelve la línea base guardada o, si no existe (o es vieja), guarda
  /// [current] como nueva línea base.
  static Future<DateTime> baselineFor({
    required String routeId,
    required String studentId,
    required String phase,
    required DateTime current,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(routeId, studentId, phase);
    final saved = prefs.getInt(key);
    if (saved != null) {
      final base = DateTime.fromMillisecondsSinceEpoch(saved);
      // Válida solo para el viaje de hoy (máx. 6 h de antigüedad).
      if (DateTime.now().difference(base).abs() < const Duration(hours: 6)) {
        return base;
      }
    }
    await prefs.setInt(key, current.millisecondsSinceEpoch);
    return current;
  }

  static Future<void> clearBaselines(String routeId, String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    for (final phase in const ['pickup', 'school']) {
      await prefs.remove(_key(routeId, studentId, phase));
    }
  }

  static Punctuality punctuality(DateTime current, DateTime baseline) {
    return current.difference(baseline) > delayTolerance
        ? Punctuality.delayed
        : Punctuality.onTime;
  }
}
