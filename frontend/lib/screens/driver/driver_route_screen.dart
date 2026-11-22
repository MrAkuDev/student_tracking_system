import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../config/routes.dart';
import '../../models/driver_models.dart';
import '../../models/enums.dart';
import '../../providers/demo_mode_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';
import '../../services/geo_utils.dart';
import '../../services/location_service.dart';
import '../../services/socket_service.dart';
import '../../services/time_utils.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/sts_app_bar.dart';
import '../../widgets/sts_map.dart';

enum _TrackingMode { gps, simulation }

/// Chofer 1 (Mapa de ruta) + Chofer 2 (Confirmación de recolección) +
/// controles compactos de GPS Real / Modo Simulación.
///
/// PRIVACIDAD: Nunca muestra nombres, apellidos, grados ni tutores;
/// únicamente `stopLabel` (`Punto A`, `Punto B`...), `stopOrder`, coordenadas,
/// estatus y `Escuela`.
class DriverRouteScreen extends StatefulWidget {
  const DriverRouteScreen({super.key});

  @override
  State<DriverRouteScreen> createState() => _DriverRouteScreenState();
}

class _DriverRouteScreenState extends State<DriverRouteScreen> {
  final MapController _mapController = MapController();
  final List<StreamSubscription<dynamic>> _socketSubs = [];

  StreamSubscription<LatLng>? _gpsSub;
  Timer? _simTimer;

  DriverRoute? _route;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  bool _socketConnected = false;
  bool _navigatedToFinished = false;

  // Ubicación actual del bus (GPS real o simulada).
  LatLng? _busPosition;

  // Panel Chofer 2 (confirmación de recolección al estar < 50 m de una parada).
  DriverStop? _pendingConfirmStop;
  bool _confirmingPickup = false;
  bool _markingArrived = false;

  // Controles GPS Real / Simulación.
  _TrackingMode _mode = _TrackingMode.simulation;
  bool _panelExpanded = true;
  bool _gpsActive = false;
  String? _gpsMessage;

  // Estado del simulador.
  List<LatLng> _simPath = const [];
  int _simIndex = 0;
  bool _simPlaying = false;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionProvider>();
    _route = session.driverRoute;
    final demo = context.read<DemoModeProvider>();
    _mode = demo.enabled ? _TrackingMode.simulation : _TrackingMode.gps;
    _panelExpanded = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initConnectionAndLoad();
    });
  }

  @override
  void dispose() {
    for (final sub in _socketSubs) {
      sub.cancel();
    }
    _socketSubs.clear();
    _stopGps();
    _stopSimulation();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initConnectionAndLoad() async {
    final route = _route ?? context.read<SessionProvider>().driverRoute;
    if (route == null) {
      setState(() => _loading = false);
      return;
    }

    final socket = context.read<SocketService>();
    _socketConnected = socket.isConnected;
    socket.joinRoute(route.id, UserRole.driver);

    _socketSubs.addAll([
      socket.onConnectionChanged.listen((connected) {
        if (!mounted) return;
        setState(() => _socketConnected = connected);
      }),
      socket.onRouteStarted.listen((event) {
        if (event.routeId != route.id || !mounted) return;
        _loadRoute(silent: true);
      }),
      socket.onPolylineUpdated.listen((event) {
        if (event.routeId != route.id || !mounted) return;
        final current = _route;
        if (current == null) return;
        final updated = current.copyWith(polyline: event.polyline);
        setState(() {
          _route = updated;
          _rebuildSimulationPath(resetIndex: false);
        });
        context.read<SessionProvider>().updateDriverRoute(updated);
      }),
      socket.onRouteStatusChanged.listen((event) {
        if (event.routeId != route.id || !mounted) return;
        final current = _route;
        if (current == null) return;
        final updated = current.copyWith(status: event.status);
        if (event.status == RouteStatus.paused ||
            event.status == RouteStatus.breakdown) {
          _stopSimulation();
        }
        setState(() => _route = updated);
        context.read<SessionProvider>().updateDriverRoute(updated);
        if (event.status == RouteStatus.completed) {
          _goToTripFinished();
        }
      }),
      socket.onStudentPickupUpdated.listen((event) {
        if (event.routeId != route.id || !mounted) return;
        final current = _route;
        if (current == null) return;
        final updatedStops = current.stops.map((s) {
          if (s.studentId == event.studentId) {
            return s.copyWith(status: event.pickupStatus);
          }
          return s;
        }).toList();
        final updated = current.copyWith(stops: updatedStops);
        setState(() {
          _route = updated;
          if (_pendingConfirmStop?.studentId == event.studentId &&
              event.pickupStatus.isPickedUp) {
            _pendingConfirmStop = null;
          }
        });
        context.read<SessionProvider>().updateDriverRoute(updated);
      }),
      socket.onTripCompleted.listen((event) {
        if (event.routeId != route.id || !mounted) return;
        _goToTripFinished();
      }),
    ]);

    await _loadRoute();
  }

  Future<void> _loadRoute({bool silent = false}) async {
    final routeId =
        _route?.id ?? context.read<SessionProvider>().driverRouteId;
    if (routeId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (!silent) {
      setState(() {
        _loading = _route == null;
        _refreshing = true;
        _error = null;
      });
    }

    try {
      final api = context.read<ApiService>();
      final fresh = await api.getDriverStops(routeId);
      if (!mounted) return;
      final session = context.read<SessionProvider>();
      await session.updateDriverRoute(fresh);
      if (!mounted) return;

      setState(() {
        _route = fresh;
        _loading = false;
        _refreshing = false;
        _error = null;
        _rebuildSimulationPath(resetIndex: _busPosition == null);
        if (_pendingConfirmStop != null) {
          final stillPending = fresh.stops.any(
            (s) =>
                s.studentId == _pendingConfirmStop!.studentId &&
                !s.status.isPickedUp,
          );
          if (!stillPending) _pendingConfirmStop = null;
        }
      });

      if (fresh.status.isActiveTrip && _mode == _TrackingMode.gps && !_gpsActive) {
        _startGps();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = 'No se pudo cargar la información de la ruta.';
      });
    }
  }

  void _goToTripFinished() {
    if (_navigatedToFinished || !mounted) return;
    _navigatedToFinished = true;
    _stopGps();
    _stopSimulation();
    Navigator.of(context).pushReplacementNamed(AppRoutes.driverTripFinished);
  }

  // ===================== Polilínea y Simulación =====================

  List<LatLng> _effectivePolyline(DriverRoute route) {
    if (route.polyline.length >= 2) return route.polyline;
    final pts = <LatLng>[
      for (final s in route.stops) s.latLng,
      route.schoolLocation.latLng,
    ];
    return pts;
  }

  void _rebuildSimulationPath({required bool resetIndex}) {
    final route = _route;
    if (route == null || !route.status.isActiveTrip) {
      _simPath = const [];
      _simIndex = 0;
      return;
    }
    final base = _effectivePolyline(route);
    _simPath = base.length >= 2
        ? GeoUtils.densify(base, stepMeters: 25)
        : List<LatLng>.from(base);

    if (resetIndex || _simIndex >= _simPath.length) {
      _simIndex = 0;
      if (_simPath.isNotEmpty && _busPosition == null) {
        _busPosition = _simPath.first;
      }
    } else if (_busPosition != null && _simPath.isNotEmpty) {
      _simIndex = GeoUtils.indexOfClosest(_simPath, _busPosition!);
    }
  }

  void _switchMode(_TrackingMode next) {
    if (_mode == next) return;
    setState(() {
      _mode = next;
      _gpsMessage = null;
    });
    if (next == _TrackingMode.gps) {
      _stopSimulation();
      _startGps();
    } else {
      _stopGps();
      _rebuildSimulationPath(resetIndex: _busPosition == null);
    }
  }

  // ===================== GPS Real =====================

  Future<void> _startGps() async {
    _stopGps();
    final locService = context.read<LocationService>();
    final access = await locService.ensurePermission();
    if (!mounted) return;

    if (access != LocationAccess.granted) {
      final msg = switch (access) {
        LocationAccess.serviceDisabled =>
          'Activa el GPS del dispositivo para usar GPS Real.',
        LocationAccess.deniedForever =>
          'Permiso de ubicación denegado permanentemente. Habilítalo en Ajustes.',
        _ => 'Permiso de ubicación requerido para GPS Real.',
      };
      setState(() {
        _gpsActive = false;
        _gpsMessage = msg;
      });
      return;
    }

    setState(() {
      _gpsActive = true;
      _gpsMessage = null;
    });

    final current = await locService.currentLatLng();
    if (mounted && current != null && _mode == _TrackingMode.gps) {
      _onNewBusPosition(current, moveCamera: true);
    }

    _gpsSub = locService.positionStream(distanceFilterMeters: 5).listen(
      (pos) {
        if (!mounted || _mode != _TrackingMode.gps) return;
        _onNewBusPosition(pos, moveCamera: true);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _gpsActive = false;
          _gpsMessage = 'Error al leer la señal GPS.';
        });
      },
    );
  }

  void _stopGps() {
    _gpsSub?.cancel();
    _gpsSub = null;
    if (mounted) {
      setState(() => _gpsActive = false);
    } else {
      _gpsActive = false;
    }
  }

  // ===================== Simulación =====================

  void _toggleSimulation() {
    if (_simPlaying) {
      _stopSimulation();
      return;
    }
    final route = _route;
    if (route == null) return;
    if (_simPath.isEmpty) {
      _rebuildSimulationPath(resetIndex: true);
    }
    if (_simPath.isEmpty) {
      _showSnack('No hay puntos de ruta disponibles para simular.');
      return;
    }

    setState(() => _simPlaying = true);
    _simTimer = Timer.periodic(AppConfig.simulationTick, (_) {
      if (!mounted) {
        _stopSimulation();
        return;
      }
      if (_simIndex >= _simPath.length) {
        _stopSimulation();
        return;
      }
      final nextPos = _simPath[_simIndex];
      _simIndex++;
      _onNewBusPosition(nextPos, moveCamera: true, pauseOnStopArrival: true);
      if (_simIndex >= _simPath.length) {
        _stopSimulation();
      }
    });
  }

  void _stopSimulation() {
    _simTimer?.cancel();
    _simTimer = null;
    if (mounted) {
      setState(() => _simPlaying = false);
    } else {
      _simPlaying = false;
    }
  }

  void _jumpToNextStop() {
    final route = _route;
    if (route == null) return;
    _stopSimulation();

    DriverStop? nextPending;
    for (final s in route.stops) {
      if (!s.status.isPickedUp) {
        nextPending = s;
        break;
      }
    }

    if (nextPending == null) {
      _showSnack('Todas las paradas ya fueron recogidas. Puedes llegar a la escuela.');
      return;
    }

    final target = nextPending.latLng;
    if (_simPath.isNotEmpty) {
      _simIndex = GeoUtils.indexOfClosest(_simPath, target, startFrom: 0);
    }
    _onNewBusPosition(target, moveCamera: true);
    setState(() => _pendingConfirmStop = nextPending);
  }

  Future<void> _arriveAtSchool() async {
    final route = _route;
    if (route == null || _markingArrived) return;
    _stopSimulation();

    setState(() => _markingArrived = true);
    try {
      final school = route.schoolLocation.latLng;
      _onNewBusPosition(school, moveCamera: true);
      final api = context.read<ApiService>();
      await api.driverArrivedSchool(route.id);
      if (!mounted) return;
      final updated = route.copyWith(status: RouteStatus.arrivedSchool);
      setState(() {
        _route = updated;
        _pendingConfirmStop = null;
      });
      await context.read<SessionProvider>().updateDriverRoute(updated);
      if (!mounted) return;
      _showSnack('Llegada a la escuela registrada. Esperando confirmación del coordinador.');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnack('No se pudo registrar la llegada a la escuela.');
    } finally {
      if (mounted) setState(() => _markingArrived = false);
    }
  }

  // ===================== Posición y proximidad =====================

  void _onNewBusPosition(
    LatLng pos, {
    bool moveCamera = false,
    bool pauseOnStopArrival = false,
  }) {
    final route = _route;
    if (route == null) return;

    setState(() => _busPosition = pos);
    context
        .read<SocketService>()
        .emitDriverLocation(route.id, pos.latitude, pos.longitude);

    if (moveCamera) {
      try {
        final zoom = _mapController.camera.zoom;
        _mapController.move(pos, zoom < 14 ? AppConfig.defaultZoom : zoom);
      } catch (_) {
        // MapController aún no montado.
      }
    }

    _checkStopProximity(pos, pauseOnStopArrival: pauseOnStopArrival);
  }

  void _checkStopProximity(LatLng pos, {bool pauseOnStopArrival = false}) {
    final route = _route;
    if (route == null) return;

    DriverStop? closestPending;
    double bestDist = double.infinity;

    for (final stop in route.stops) {
      if (stop.status.isPickedUp) continue;
      final d = GeoUtils.haversineMeters(pos, stop.latLng);
      if (d < AppConfig.arrivedStopMeters && d < bestDist) {
        bestDist = d;
        closestPending = stop;
      }
    }

    if (closestPending != null &&
        _pendingConfirmStop?.studentId != closestPending.studentId) {
      if (pauseOnStopArrival) {
        _stopSimulation();
      }
      setState(() => _pendingConfirmStop = closestPending);
    }
  }

  Future<void> _confirmPickup(DriverStop stop) async {
    final route = _route;
    if (route == null || _confirmingPickup) return;

    setState(() => _confirmingPickup = true);
    try {
      final api = context.read<ApiService>();
      final updatedStops = await api.confirmPickup(route.id, stop.studentId);
      updatedStops.sort((a, b) => a.stopOrder.compareTo(b.stopOrder));
      if (!mounted) return;

      final updated = route.copyWith(stops: updatedStops);
      setState(() {
        _route = updated;
        _pendingConfirmStop = null;
      });
      await context.read<SessionProvider>().updateDriverRoute(updated);
      if (!mounted) return;
      _showSnack('Recolección confirmada — ${_labelForStop(stop)}');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnack('No se pudo confirmar la recolección.');
    } finally {
      if (mounted) setState(() => _confirmingPickup = false);
    }
  }

  String _labelForStop(DriverStop stop) =>
      stop.stopLabel.isNotEmpty ? stop.stopLabel : 'Punto ${stop.stopOrder}';

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    final route = _route;

    return Scaffold(
      appBar: StsAppBar(
        title: 'Bienvenido',
        subtitle: route == null
            ? null
            : (route.name.isNotEmpty ? route.name : route.shortCode),
        showBack: true,
        showDemoToggle: true,
      ),
      body: _buildBody(route),
    );
  }

  Widget _buildBody(DriverRoute? route) {
    if (_loading) {
      return const LoadingView(message: 'Cargando ruta...');
    }
    if (route == null) {
      return EmptyView(
        icon: Icons.directions_bus_outlined,
        title: 'No hay una ruta activa',
        subtitle: 'Ingresa tu código de ruta para comenzar.',
      );
    }
    if (_error != null && !route.status.isActiveTrip) {
      return ErrorView(message: _error!, onRetry: () => _loadRoute());
    }

    if (!route.status.isActiveTrip) {
      return _buildWaitingState(route);
    }
    return _buildActiveTrip(route);
  }

  Widget _buildWaitingState(DriverRoute route) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.directions_bus_rounded,
                      size: 46,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Esperando a que el coordinador inicie la ruta...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (route.shortCode.isNotEmpty)
                        StatusChip(
                          label: route.shortCode,
                          color: AppColors.primary,
                          icon: Icons.tag,
                        ),
                      StatusChip(
                        label: TimeUtils.to12h(route.startTime),
                        color: AppColors.textSecondary,
                        icon: Icons.schedule,
                      ),
                      StatusChip(
                        label: _socketConnected ? 'Conectado' : 'Reconectando',
                        color: _socketConnected
                            ? AppColors.success
                            : AppColors.warning,
                        icon: _socketConnected
                            ? Icons.wifi
                            : Icons.wifi_off_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Actualizar',
                    icon: Icons.refresh_rounded,
                    variant: PrimaryButtonVariant.outlined,
                    loading: _refreshing,
                    onPressed: () => _loadRoute(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTrip(DriverRoute route) {
    final polyline = _effectivePolyline(route);
    final pickedCount = route.stops.where((s) => s.status.isPickedUp).length;
    final totalStops = route.stops.length;

    final markers = route.stops.map((s) {
      final isHighlighted = _pendingConfirmStop?.studentId == s.studentId ||
          s.status == PickupStatus.arrivedStop ||
          s.status == PickupStatus.approaching;
      return StsStopMarker(
        point: s.latLng,
        label: _labelForStop(s),
        pickedUp: s.status.isPickedUp,
        highlighted: isHighlighted,
      );
    }).toList();

    return SafeArea(
      child: Column(
        children: [
          // Encabezado compacto
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Todo listo para la ruta',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$pickedCount de $totalStops paradas recogidas',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip.route(route.status),
              ],
            ),
          ),

          // Banner destacado de pausa / avería / llegada a escuela
          if (route.status == RouteStatus.paused ||
              route.status == RouteStatus.breakdown ||
              route.status == RouteStatus.arrivedSchool)
            _buildStatusBanner(route.status),

          // Mapa a gran tamaño con botón flotante SOS siempre accesible
          Expanded(
            child: Stack(
              children: [
                StsMap(
                  controller: _mapController,
                  initialCenter: _busPosition ??
                      (route.stops.isNotEmpty
                          ? route.stops.first.latLng
                          : route.schoolLocation.latLng),
                  polyline: polyline,
                  stops: markers,
                  schoolPoint: route.schoolLocation.latLng,
                  schoolLabel: 'Escuela',
                  busPoint: _busPosition,
                  borderRadius: 0,
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    heroTag: 'driver_sos_fab',
                    backgroundColor: AppColors.sos,
                    foregroundColor: Colors.white,
                    tooltip: 'Reportar problema (SOS)',
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRoutes.driverSos);
                    },
                    child: const Icon(Icons.notifications_active_rounded),
                  ),
                ),
              ],
            ),
          ),

          // Overlay / Panel inferior Chofer 2 (Confirmación de recolección)
          if (_pendingConfirmStop != null)
            _buildPickupConfirmPanel(_pendingConfirmStop!),

          // Panel compacto colapsable de GPS Real / Modo Simulación
          _buildTrackingControlPanel(route),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(RouteStatus status) {
    final (Color color, IconData icon, String text) = switch (status) {
      RouteStatus.paused => (
          AppColors.warning,
          Icons.pause_circle_filled_rounded,
          'Ruta en pausa — Espera indicaciones del coordinador.',
        ),
      RouteStatus.breakdown => (
          AppColors.sos,
          Icons.warning_rounded,
          'Avería reportada — Ruta detenida por seguridad.',
        ),
      RouteStatus.arrivedSchool => (
          AppColors.success,
          Icons.school_rounded,
          'Llegaste a la escuela — Esperando confirmación del coordinador.',
        ),
      _ => (AppColors.primary, Icons.info_outline, status.label),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tint(color),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(110)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupConfirmPanel(DriverStop stop) {
    final label = _labelForStop(stop);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.primary, width: 2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.hail_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Confirmar recolección de alumno — $label',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Confirmar',
            icon: Icons.check_circle_outline_rounded,
            loading: _confirmingPickup,
            onPressed: () => _confirmPickup(stop),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingControlPanel(DriverRoute route) {
    final hasPendingStops = route.stops.any((s) => !s.status.isPickedUp);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _panelExpanded = !_panelExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _mode == _TrackingMode.gps
                        ? Icons.gps_fixed_rounded
                        : Icons.route_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _mode == _TrackingMode.gps
                          ? (_gpsActive ? 'GPS Real activo' : 'GPS Real')
                          : (_simPlaying
                              ? 'Simulación en curso'
                              : 'Modo Simulación'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _panelExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_panelExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<_TrackingMode>(
                    segments: const [
                      ButtonSegment<_TrackingMode>(
                        value: _TrackingMode.gps,
                        icon: Icon(Icons.my_location_rounded, size: 16),
                        label: Text('GPS Real'),
                      ),
                      ButtonSegment<_TrackingMode>(
                        value: _TrackingMode.simulation,
                        icon: Icon(Icons.play_circle_outline_rounded, size: 16),
                        label: Text('Simular Recorrido'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        _switchMode(selection.first);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  if (_mode == _TrackingMode.gps) ...[
                    Row(
                      children: [
                        Icon(
                          _gpsActive
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          size: 18,
                          color: _gpsActive
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _gpsMessage ??
                                (_gpsActive
                                    ? 'Enviando ubicación real en tiempo real.'
                                    : 'Toca activar para transmitir tu ubicación GPS.'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (!_gpsActive)
                          TextButton(
                            onPressed: _startGps,
                            child: const Text('Activar'),
                          ),
                      ],
                    ),
                  ] else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _toggleSimulation,
                          icon: Icon(
                            _simPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 18,
                          ),
                          label: Text(_simPlaying ? 'Pausar' : 'Reproducir'),
                        ),
                        OutlinedButton.icon(
                          onPressed: hasPendingStops ? _jumpToNextStop : null,
                          icon: const Icon(Icons.skip_next_rounded, size: 18),
                          label: const Text('Siguiente parada'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _markingArrived ? null : _arriveAtSchool,
                          icon: _markingArrived
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.school_rounded, size: 18),
                          label: const Text('Llegar a escuela'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            backgroundColor: hasPendingStops
                                ? AppColors.textSecondary
                                : AppColors.success,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
