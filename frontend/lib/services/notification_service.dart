import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import 'time_utils.dart';

/// Payloads que viajan en la notificación (para saber qué abrir al tocarla).
class NotificationPayloads {
  NotificationPayloads._();
  static const String confirmService = 'confirm_service';
  static const String proximity = 'proximity';
  static const String arrivedStop = 'arrived_stop';
  static const String routeStatus = 'route_status';
  static const String arrivedSchool = 'arrived_school';
}

/// Notificaciones locales Android: canal de alta prioridad, sonido, vibración
/// y visibilidad en pantalla bloqueada.
///
/// `main.dart` asigna [onTap] (navegación según payload) y consume
/// [launchPayload] si la app se abrió desde una notificación.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String channelId = 'sts_high_priority';
  static const String channelName = 'Alertas STS';
  static const String channelDescription =
      'Avisos del transporte escolar: confirmación del servicio, cercanía y llegada.';
  static const String _smallIcon = 'ic_stat_sts';
  static const int scheduledConfirmId = 1001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Se invoca al tocar una notificación (app abierta o en segundo plano).
  void Function(String? payload)? onTap;

  /// Payload de la notificación que abrió la app desde cero (consumir una vez).
  String? launchPayload;

  bool _initialized = false;
  int _nextId = 2000;

  Future<void> init() async {
    if (_initialized) return;
    try {
      // Las fechas programadas se expresan en UTC (instantes absolutos).
      tz.setLocalLocation(tz.UTC);

      const settings = InitializationSettings(
        android: AndroidInitializationSettings(_smallIcon),
      );
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          onTap?.call(response.payload);
        },
      );

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );

      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch != null && launch.didNotificationLaunchApp) {
        launchPayload = launch.notificationResponse?.payload;
      }
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService.init falló: $e');
    }
  }

  /// Pide el permiso POST_NOTIFICATIONS (Android 13+). `true` si concedido.
  Future<bool> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    } catch (e) {
      debugPrint('NotificationService.requestPermission falló: $e');
      return false;
    }
  }

  NotificationDetails _details({bool fullScreen = false}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(<int>[0, 500, 250, 500]),
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
        fullScreenIntent: fullScreen,
        icon: _smallIcon,
        color: AppColors.primary,
        ticker: 'STS',
      ),
    );
  }

  /// Muestra una notificación inmediata de alta prioridad.
  /// [fullScreen] la hace aparecer sobre la pantalla bloqueada.
  Future<void> showNow(
    String title,
    String body, {
    String? payload,
    int? id,
    bool fullScreen = false,
  }) async {
    if (!_initialized) await init();
    try {
      await _plugin.show(
        id ?? _nextId++,
        title,
        body,
        _details(fullScreen: fullScreen),
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService.showNow falló: $e');
    }
  }

  /// Programa "La recolección empezará pronto, confirma el servicio" 1 hora
  /// antes de [startTime] ("07:30"). Si esa hora ya pasó hoy, la programa para
  /// mañana. Reemplaza la programación anterior. Devuelve la fecha programada.
  Future<DateTime?> scheduleOneHourBefore(
    String startTime, {
    String payload = NotificationPayloads.confirmService,
  }) async {
    if (!_initialized) await init();
    try {
      final start = TimeUtils.parseHHmm(startTime);
      final now = DateTime.now();
      var at = DateTime(now.year, now.month, now.day, start.hour, start.minute)
          .subtract(AppConfig.confirmNotificationLead);
      if (!at.isAfter(now.add(const Duration(seconds: 5)))) {
        at = at.add(const Duration(days: 1));
      }
      await _plugin.cancel(scheduledConfirmId);
      await _plugin.zonedSchedule(
        scheduledConfirmId,
        'Confirma tu servicio',
        'La recolección empezará pronto, confirma el servicio',
        tz.TZDateTime.fromMillisecondsSinceEpoch(
            tz.UTC, at.millisecondsSinceEpoch),
        _details(fullScreen: true),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      return at;
    } catch (e) {
      debugPrint('NotificationService.scheduleOneHourBefore falló: $e');
      return null;
    }
  }

  Future<void> cancelScheduled() async {
    try {
      await _plugin.cancel(scheduledConfirmId);
    } catch (e) {
      debugPrint('NotificationService.cancelScheduled falló: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('NotificationService.cancelAll falló: $e');
    }
  }
}
