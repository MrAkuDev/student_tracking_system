import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Acciones nativas del sistema (llamadas, enlaces).
class LauncherService {
  LauncherService._();

  /// Abre el marcador del teléfono con [phone] prellenado (`tel:`).
  /// Devuelve `false` si no se pudo abrir.
  static Future<bool> call(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('LauncherService.call falló: $e');
      return false;
    }
  }
}
