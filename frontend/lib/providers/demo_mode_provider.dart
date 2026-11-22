import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Modo Demo global (persistido). Habilita paneles de simulación en los roles
/// y acorta el temporizador post-llegada (10 s en vez de 5 min).
class DemoModeProvider extends ChangeNotifier {
  bool _enabled = false;
  bool get enabled => _enabled;

  /// Tiempo antes de volver a "Próximas recolecciones" tras llegar a la escuela.
  Duration get postArrivalDelay => _enabled
      ? AppConfig.postArrivalReturnDelayDemo
      : AppConfig.postArrivalReturnDelay;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(AppConfig.prefDemoMode) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.prefDemoMode, value);
  }

  Future<void> toggle() => setEnabled(!_enabled);
}
