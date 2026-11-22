import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

/// Permisos y ubicación (geolocator).
class LocationService {
  /// Verifica servicio GPS y pide permiso si hace falta.
  Future<LocationAccess> ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return LocationAccess.serviceDisabled;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationAccess.deniedForever;
    }
    if (permission == LocationPermission.denied) return LocationAccess.denied;
    return LocationAccess.granted;
  }

  /// Ubicación actual (pide permiso). `null` si no es posible.
  Future<LatLng?> currentLatLng() async {
    final access = await ensurePermission();
    if (access != LocationAccess.granted) return null;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('LocationService.currentLatLng falló: $e');
      return null;
    }
  }

  /// Stream de posiciones (llamar antes a [ensurePermission]).
  Stream<LatLng> positionStream({int distanceFilterMeters = 5}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      ),
    ).map((p) => LatLng(p.latitude, p.longitude));
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
