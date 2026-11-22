import 'package:latlong2/latlong.dart';

/// Constantes y utilidades de configuración global de STS.
///
/// La URL del servidor es editable en tiempo de ejecución y se persiste en
/// `SharedPreferences` mediante `ServerConfigProvider` (este archivo solo
/// guarda el valor por defecto, la clave y la normalización).
class AppConfig {
  AppConfig._();

  static const String appName = 'STS';
  static const String appSubtitle = 'Student Tracking System';

  // --- Servidor ---------------------------------------------------------
  /// Emulador Android → host de la PC. En dispositivo físico usar la IP LAN.
  static const String defaultServerUrl = 'http://10.0.2.2:3000';
  static const String prefServerUrl = 'sts_server_url';
  static const String prefDemoMode = 'sts_demo_mode';

  // --- Proximidad (metros) ---------------------------------------------
  static const double approachingMeters = 300; // "acercándose"
  static const double arrivedStopMeters = 50; // "en parada"
  static const double arrivedSchoolMeters = 60; // "llegó a la escuela"

  // --- Tiempos -----------------------------------------------------------
  /// Tiempo tras "Llegó a la escuela" antes de volver a Próximas recolecciones.
  static const Duration postArrivalReturnDelay = Duration(minutes: 5);
  static const Duration postArrivalReturnDelayDemo = Duration(seconds: 10);

  /// La notificación de confirmación se programa 1 hora antes de `startTime`.
  static const Duration confirmNotificationLead = Duration(hours: 1);

  /// Frecuencia con la que el chofer emite su ubicación en simulación.
  static const Duration simulationTick = Duration(seconds: 1);

  // --- Mapas -------------------------------------------------------------
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osrmBaseUrl =
      'https://router.project-osrm.org/route/v1/driving';

  /// Identificador de la app (User-Agent de OSM exige uno propio).
  static const String userAgentPackage = 'com.sts.sts_app';

  /// Escuela por defecto (Chihuahua, México) si el servidor no responde.
  static const LatLng defaultMapCenter = LatLng(28.6353, -106.0889);
  static const double defaultZoom = 15;

  // --- Utilidades --------------------------------------------------------

  /// Normaliza lo que escribe el usuario: agrega `http://`, quita espacios y
  /// barras finales. Cadena vacía → URL por defecto.
  static String normalizeUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return defaultServerUrl;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}
