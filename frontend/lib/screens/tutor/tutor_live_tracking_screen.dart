import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../config/routes.dart';
import '../../models/api_results.dart';
import '../../models/enums.dart';
import '../../models/route_model.dart';
import '../../models/socket_events.dart';
import '../../models/student_model.dart';
import '../../providers/demo_mode_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';
import '../../services/launcher_service.dart';
import '../../services/notification_service.dart';
import '../../services/socket_service.dart';
import '../../services/time_utils.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/state_views.dart';
import '../../widgets/sts_app_bar.dart';
import '../../widgets/sts_map.dart';

/// Seguimiento en vivo del transporte escolar para el tutor.
class TutorLiveTrackingScreen extends StatefulWidget {
  const TutorLiveTrackingScreen({super.key});

  @override
  State<TutorLiveTrackingScreen> createState() =>
      _TutorLiveTrackingScreenState();
}

class _TutorLiveTrackingScreenState extends State<TutorLiveTrackingScreen> {
  final _mapController = MapController();
  final List<StreamSubscription<dynamic>> _subs = <StreamSubscription<dynamic>>[];

  bool _loading = true;
  String? _error;

  RouteModel? _route;
  Student? _student;
  List<TutorLiveStop> _stops = const [];
  List<LatLng> _polyline = const [];
  LatLng? _busPoint;
  RouteStatus _routeStatus = RouteStatus.idle;
  PickupStatus _pickupStatus = PickupStatus.pending;

  Timer? _postArrivalTimer;
  int? _secondsRemaining;
  bool _arrivalTimerStarted = false;

  // Evita repetir notificaciones locales idénticas en la misma sesión de viaje.
  String? _lastNotifiedKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _postArrivalTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _clearSubs() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  Future<void> _load() async {
    final session = context.read<SessionProvider>();
    final studentId = session.studentId;
    if (studentId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No hay una sesión de tutor activa.';
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final res = await api.getTutorLive(studentId);
      await session.updateStudent(res.student, route: res.route);

      if (!mounted) return;
      setState(() {
        _route = res.route;
        _student = res.student;
        _stops = res.stops;
        _polyline = res.route.polyline;
        _busPoint = res.route.currentLocation?.latLng;
        _routeStatus = res.route.status;
        _pickupStatus = res.student.pickupStatus;
        _loading = false;
      });

      _connectSocket(res.route.id, res.student.id);

      if (_isArrivedState) {
        _startPostArrivalCountdown();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar el seguimiento en vivo.';
      });
    }
  }

  void _connectSocket(String routeId, String studentId) {
    _clearSubs();
    final socket = context.read<SocketService>();
    socket.joinRoute(routeId, UserRole.tutor);
    socket.joinStudent(studentId);

    _subs.add(
      socket.onBusLocation.listen((BusLocationEvent e) {
        if (!mounted || e.routeId != routeId) return;
        setState(() => _busPoint = e.latLng);
      }),
    );

    _subs.add(
      socket.onPolylineUpdated.listen((PolylineEvent e) {
        if (!mounted || e.routeId != routeId) return;
        setState(() => _polyline = e.polyline);
      }),
    );

    _subs.add(
      socket.onRouteStatusChanged.listen((RouteStatusEvent e) {
        if (!mounted || e.routeId != routeId) return;
        setState(() => _routeStatus = e.status);
        _notifyForRouteStatus(e.status);
        if (e.status == RouteStatus.arrivedSchool ||
            e.status == RouteStatus.completed) {
          _startPostArrivalCountdown();
        }
      }),
    );

    _subs.add(
      socket.onStudentPickupUpdated.listen((PickupUpdateEvent e) {
        if (!mounted || e.studentId != studentId) return;
        setState(() => _pickupStatus = e.pickupStatus);
        if (e.pickupStatus == PickupStatus.approaching) {
          _notifyOnce(
            'pickup_approaching',
            'Transporte cerca',
            'Transporte cerca de tu ubicación',
            NotificationPayloads.proximity,
          );
        } else if (e.pickupStatus == PickupStatus.arrivedStop) {
          _notifyOnce(
            'pickup_arrived_stop',
            'El transporte llegó',
            'El transporte llegó a tu punto',
            NotificationPayloads.arrivedStop,
          );
        } else if (e.pickupStatus == PickupStatus.droppedAtSchool) {
          _notifyOnce(
            'arrived_school',
            'Llegó a la escuela',
            'El transporte llegó a la escuela de forma segura.',
            NotificationPayloads.arrivedSchool,
          );
          _startPostArrivalCountdown();
        }
      }),
    );

    _subs.add(
      socket.onProximityAlert.listen((ProximityEvent e) {
        if (!mounted || e.studentId != studentId) return;
        if (e.isArrivedStop) {
          setState(() => _pickupStatus = PickupStatus.arrivedStop);
          _notifyOnce(
            'pickup_arrived_stop',
            'El transporte llegó',
            'El transporte llegó a tu punto',
            NotificationPayloads.arrivedStop,
          );
        } else if (e.isApproaching) {
          if (_pickupStatus == PickupStatus.pending) {
            setState(() => _pickupStatus = PickupStatus.approaching);
          }
          _notifyOnce(
            'pickup_approaching',
            'Transporte cerca',
            'Transporte cerca de tu ubicación',
            NotificationPayloads.proximity,
          );
        }
      }),
    );

    _subs.add(
      socket.onTripCompleted.listen((TripCompletedEvent e) {
        if (!mounted || e.routeId != routeId) return;
        setState(() {
          _routeStatus = RouteStatus.completed;
          _pickupStatus = PickupStatus.droppedAtSchool;
        });
        _notifyOnce(
          'arrived_school',
          'Llegó a la escuela',
          'El transporte llegó a la escuela de forma segura.',
          NotificationPayloads.arrivedSchool,
        );
        _startPostArrivalCountdown();
      }),
    );
  }

  void _notifyForRouteStatus(RouteStatus status) {
    switch (status) {
      case RouteStatus.paused:
        _notifyOnce(
          'status_paused',
          'Transporte en pausa',
          'El transporte se encuentra en pausa temporalmente.',
          NotificationPayloads.routeStatus,
        );
        break;
      case RouteStatus.breakdown:
        _notifyOnce(
          'status_breakdown',
          'Avería reportada',
          'Se ha reportado una avería en la ruta escolar.',
          NotificationPayloads.routeStatus,
        );
        break;
      case RouteStatus.arrivedSchool:
      case RouteStatus.completed:
        _notifyOnce(
          'arrived_school',
          'Llegó a la escuela',
          'El transporte llegó a la escuela de forma segura.',
          NotificationPayloads.arrivedSchool,
        );
        break;
      case RouteStatus.idle:
      case RouteStatus.inProgress:
        break;
    }
  }

  void _notifyOnce(String key, String title, String body, String payload) {
    if (_lastNotifiedKey == key) return;
    _lastNotifiedKey = key;
    NotificationService.instance.showNow(title, body, payload: payload);
  }

  bool get _isArrivedState =>
      _routeStatus == RouteStatus.arrivedSchool ||
      _routeStatus == RouteStatus.completed ||
      _pickupStatus == PickupStatus.droppedAtSchool;

  void _startPostArrivalCountdown() {
    if (_arrivalTimerStarted || !mounted) return;
    _arrivalTimerStarted = true;
    final delay = context.read<DemoModeProvider>().postArrivalDelay;
    var remaining = delay.inSeconds;
    if (remaining < 1) remaining = 1;

    setState(() => _secondsRemaining = remaining);

    _postArrivalTimer?.cancel();
    _postArrivalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      remaining -= 1;
      if (remaining <= 0) {
        timer.cancel();
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.tutorHome,
          (_) => false,
        );
      } else {
        setState(() => _secondsRemaining = remaining);
      }
    });
  }

  ({String text, Color color, IconData icon}) _statusBanner() {
    if (_isArrivedState) {
      return (
        text: 'Llegó a la escuela',
        color: AppColors.success,
        icon: Icons.school_rounded,
      );
    }
    switch (_routeStatus) {
      case RouteStatus.idle:
        return (
          text: 'Preparando transporte',
          color: AppColors.primary,
          icon: Icons.schedule_rounded,
        );
      case RouteStatus.paused:
        return (
          text: 'Transporte en pausa',
          color: AppColors.warning,
          icon: Icons.pause_circle_filled_rounded,
        );
      case RouteStatus.breakdown:
        return (
          text: 'Avería reportada',
          color: AppColors.sos,
          icon: Icons.warning_amber_rounded,
        );
      case RouteStatus.arrivedSchool:
      case RouteStatus.completed:
        return (
          text: 'Llegó a la escuela',
          color: AppColors.success,
          icon: Icons.school_rounded,
        );
      case RouteStatus.inProgress:
        switch (_pickupStatus) {
          case PickupStatus.pickedUp:
            return (
              text: 'Estudiante a bordo - Rumbo a la escuela',
              color: AppColors.success,
              icon: Icons.check_circle_rounded,
            );
          case PickupStatus.arrivedStop:
            return (
              text: 'El transporte llegó a tu punto',
              color: AppColors.warning,
              icon: Icons.location_on_rounded,
            );
          case PickupStatus.approaching:
            return (
              text: 'Transporte cerca de tu ubicación',
              color: AppColors.warning,
              icon: Icons.near_me_rounded,
            );
          case PickupStatus.droppedAtSchool:
            return (
              text: 'Llegó a la escuela',
              color: AppColors.success,
              icon: Icons.school_rounded,
            );
          case PickupStatus.pending:
            return (
              text: 'Transporte en camino',
              color: AppColors.primary,
              icon: Icons.directions_bus_rounded,
            );
        }
    }
  }

  List<LatLng> _effectivePolyline() {
    if (_polyline.length >= 2) return _polyline;
    final pts = <LatLng>[
      for (final s in _stops) s.latLng,
    ];
    final school = _route?.schoolLocation.latLng;
    if (school != null) pts.add(school);
    return pts.length >= 2 ? pts : const [];
  }

  String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _showRouteDetailsSheet() {
    final route = _route;
    final student = _student;
    final session = context.read<SessionProvider>();
    final coordinatorPhone = session.coordinatorPhone?.trim() ?? '';
    final banner = _statusBanner();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Detalles de la ruta',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.directions_bus_outlined,
                label: 'Ruta',
                value: route != null ? route.name : '—',
              ),
              _DetailRow(
                icon: Icons.qr_code_2_outlined,
                label: 'Código de ruta',
                value: route != null && route.shortCode.isNotEmpty
                    ? route.shortCode
                    : '—',
              ),
              _DetailRow(
                icon: Icons.access_time_rounded,
                label: 'Hora de inicio',
                value: route != null ? TimeUtils.to12h(route.startTime) : '—',
              ),
              _DetailRow(
                icon: banner.icon,
                label: 'Estatus actual',
                value: banner.text,
                valueColor: banner.color,
              ),
              _DetailRow(
                icon: Icons.person_outline,
                label: 'Alumno',
                value: student != null && student.fullName.isNotEmpty
                    ? student.fullName
                    : '—',
              ),
              if (coordinatorPhone.isNotEmpty) ...[
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Llamar al coordinador ($coordinatorPhone)',
                  icon: Icons.phone_rounded,
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final ok = await LauncherService.call(coordinatorPhone);
                    if (!ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No se pudo abrir la app de teléfono.'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final banner = _statusBanner();
    final route = _route;
    final student = _student;

    return Scaffold(
      appBar: StsAppBar(
        title: 'Seguimiento en vivo',
        subtitle: route?.name,
        showBack: true,
        onBack: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.tutorHome,
              (_) => false,
            );
          }
        },
        showDemoToggle: true,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton(
              heroTag: 'tutor_live_info_fab',
              tooltip: 'Detalles de la ruta',
              onPressed: _showRouteDetailsSheet,
              child: const Icon(Icons.info_outline_rounded),
            ),
      body: SafeArea(
        child: _loading
            ? const LoadingView(message: 'Conectando con el transporte...')
            : _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : Column(
                    children: [
                      // Barra superior de estatus dinámica
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        color: banner.color,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(banner.icon, color: Colors.white, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    banner.text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_secondsRemaining != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Regresando a Próximas recolecciones en ${_formatCountdown(_secondsRemaining!)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            StsMap(
                              controller: _mapController,
                              borderRadius: 0,
                              initialCenter: _busPoint ??
                                  student?.pickupLocation.latLng ??
                                  route?.schoolLocation.latLng ??
                                  AppConfig.defaultMapCenter,
                              initialZoom: AppConfig.defaultZoom,
                              polyline: _effectivePolyline(),
                              pickupPin: student?.pickupLocation.latLng,
                              schoolPoint: route?.schoolLocation.latLng,
                              busPoint: _busPoint,
                            ),
                            if (_busPoint != null)
                              Positioned(
                                left: 12,
                                bottom: 16,
                                child: FloatingActionButton.small(
                                  heroTag: 'tutor_center_bus',
                                  tooltip: 'Centrar en el transporte',
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primary,
                                  onPressed: () {
                                    final bus = _busPoint;
                                    if (bus != null) {
                                      _mapController.move(bus, 16);
                                    }
                                  },
                                  child: const Icon(Icons.directions_bus),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: valueColor ?? AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
