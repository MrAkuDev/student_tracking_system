import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/route_args.dart';
import '../../config/routes.dart';
import '../../models/driver_models.dart';
import '../../models/enums.dart';
import '../../models/route_model.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/sts_app_bar.dart';
import '../../widgets/sts_map.dart';

/// Coordinador 4 — Monitoreo en vivo de ruta, control de estatus y alumnos.
class CoordinatorLiveRouteScreen extends StatefulWidget {
  const CoordinatorLiveRouteScreen({super.key});

  @override
  State<CoordinatorLiveRouteScreen> createState() =>
      _CoordinatorLiveRouteScreenState();
}

class _CoordinatorLiveRouteScreenState
    extends State<CoordinatorLiveRouteScreen> {
  final MapController _mapController = MapController();
  final List<StreamSubscription<dynamic>> _subs = [];

  bool _initialized = false;
  bool _loading = true;
  bool _updatingStatus = false;
  String? _error;

  String? _routeId;
  RouteModel? _route;
  List<LiveStop> _stops = [];
  LatLng? _busPoint;
  bool _sosActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = AppRoutes.argsOf<RouteIdArgs>(context);
      _routeId = args?.routeId;
      if (_routeId == null) {
        setState(() {
          _loading = false;
          _error = 'No se recibió el identificador de la ruta.';
        });
      } else {
        _loadLive();
        _connectSocket(_routeId!);
      }
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _mapController.dispose();
    super.dispose();
  }

  void _connectSocket(String routeId) {
    final socket = context.read<SocketService>();
    socket.joinRoute(routeId, UserRole.coordinator);

    _subs.addAll([
      socket.onBusLocation.listen((e) {
        if (!mounted || e.routeId != routeId) return;
        setState(() => _busPoint = e.latLng);
      }),
      socket.onRouteStatusChanged.listen((e) {
        if (!mounted || e.routeId != routeId) return;
        setState(() {
          if (_route != null) {
            _route = _route!.copyWith(status: e.status);
          }
          if (e.reason == 'sos') {
            _sosActive = true;
          } else if (e.status == RouteStatus.inProgress ||
              e.status == RouteStatus.arrivedSchool ||
              e.status == RouteStatus.completed) {
            _sosActive = false;
          }
        });
      }),
      socket.onPolylineUpdated.listen((e) {
        if (!mounted || e.routeId != routeId) return;
        setState(() {
          if (_route != null) {
            _route = _route!.copyWith(polyline: e.polyline);
          }
        });
      }),
      socket.onStudentPickupUpdated.listen((e) {
        if (!mounted || e.routeId != routeId) return;
        setState(() {
          _stops = _stops
              .map(
                (s) => s.studentId == e.studentId
                    ? s.copyWith(status: e.pickupStatus)
                    : s,
              )
              .toList();
        });
      }),
      socket.onDriverSos.listen((e) {
        if (!mounted || e.routeId != routeId) return;
        setState(() {
          _sosActive = true;
          if (_route != null) {
            _route = _route!.copyWith(status: RouteStatus.paused);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Alerta SOS recibida del chofer! Ruta en pausa.'),
            backgroundColor: AppColors.sos,
          ),
        );
      }),
      socket.onTripCompleted.listen((e) {
        if (!mounted || e.routeId != routeId) return;
        setState(() {
          _sosActive = false;
          if (_route != null) {
            _route = _route!.copyWith(status: RouteStatus.completed);
          }
        });
      }),
    ]);
  }

  Future<void> _loadLive() async {
    final routeId = _routeId;
    if (routeId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await context.read<ApiService>().getRouteLive(routeId);
      if (!mounted) return;
      setState(() {
        _route = result.route;
        _stops = result.stops;
        _busPoint = result.route.currentLocation?.latLng;
        _sosActive = result.sosActive;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el estado en vivo de la ruta.';
        _loading = false;
      });
    }
  }

  Future<void> _setStatus(RouteStatus target) async {
    final route = _route;
    if (route == null || route.status == target || _updatingStatus) return;

    setState(() => _updatingStatus = true);
    try {
      final updated =
          await context.read<ApiService>().setRouteStatus(route.id, target);
      if (!mounted) return;
      setState(() {
        _route = updated;
        if (target == RouteStatus.inProgress) {
          _sosActive = false;
        }
        _updatingStatus = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _updatingStatus = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.sos),
      );
    }
  }

  void _openConfirmArrival() {
    final id = _routeId;
    if (id == null) return;
    Navigator.of(context).pushNamed(
      AppRoutes.coordinatorConfirmArrival,
      arguments: RouteIdArgs(id),
    );
  }

  List<LatLng> _effectivePolyline(RouteModel route) {
    if (route.polyline.length >= 2) return route.polyline;
    if (_stops.isEmpty) return const [];
    return [
      ..._stops.map((s) => s.latLng),
      route.schoolLocation.latLng,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    return Scaffold(
      appBar: StsAppBar(
        title: route?.name ?? 'Ruta en vivo',
        subtitle: route != null ? route.shortCode : null,
        showBack: true,
        showRoleSwitch: false,
        actions: [
          if (route != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: StatusChip.route(route.status)),
            ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingView(message: 'Conectando con la ruta en vivo...');
    }
    if (_error != null || _route == null) {
      return ErrorView(
        message: _error ?? 'Ruta no disponible.',
        onRetry: _loadLive,
      );
    }

    final route = _route!;
    final canChangeManualStatus = route.status == RouteStatus.inProgress ||
        route.status == RouteStatus.paused ||
        route.status == RouteStatus.breakdown;

    final showSosBanner = _sosActive &&
        (route.status == RouteStatus.paused ||
            route.status == RouteStatus.breakdown ||
            route.status == RouteStatus.inProgress);

    final pickedUpCount = _stops.where((s) => s.status.isPickedUp).length;

    return Column(
      children: [
        if (showSosBanner)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.sos,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Alerta SOS activa del chofer. Comunícate con él y actualiza el estatus cuando corresponda.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (canChangeManualStatus)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: _StatusChoiceButton(
                    label: 'En progreso',
                    color: AppColors.primary,
                    selected: route.status == RouteStatus.inProgress,
                    enabled: !_updatingStatus,
                    onTap: () => _setStatus(RouteStatus.inProgress),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusChoiceButton(
                    label: 'En pausa',
                    color: AppColors.warning,
                    selected: route.status == RouteStatus.paused,
                    enabled: !_updatingStatus,
                    onTap: () => _setStatus(RouteStatus.paused),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusChoiceButton(
                    label: 'Avería',
                    color: AppColors.sos,
                    selected: route.status == RouteStatus.breakdown,
                    enabled: !_updatingStatus,
                    onTap: () => _setStatus(RouteStatus.breakdown),
                  ),
                ),
              ],
            ),
          ),
        if (route.status == RouteStatus.arrivedSchool)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tint(AppColors.success),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.success.withAlpha(110)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.school, color: AppColors.success),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El transporte llegó a la escuela.',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: 'Confirmar llegada',
                    icon: Icons.check_circle_outline,
                    onPressed: _openConfirmArrival,
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: StsMap(
              controller: _mapController,
              polyline: _effectivePolyline(route),
              stops: _stops
                  .map(
                    (s) => StsStopMarker(
                      point: s.latLng,
                      label: s.stopLabel,
                      pickedUp: s.status.isPickedUp,
                      highlighted: s.status == PickupStatus.arrivedStop ||
                          s.status == PickupStatus.approaching,
                    ),
                  )
                  .toList(),
              schoolPoint: route.schoolLocation.latLng,
              schoolLabel: 'Escuela',
              busPoint: _busPoint,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Alumnos confirmados hoy',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '$pickedUpCount / ${_stops.length} recogidos',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _stops.isEmpty
                      ? const EmptyView(
                          icon: Icons.directions_bus_outlined,
                          title: 'Sin paradas activas',
                          subtitle:
                              'Inicia la ruta para ver la lista de alumnos confirmados de hoy.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: _stops.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final stop = _stops[index];
                            final picked = stop.status.isPickedUp;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              leading: Icon(
                                picked ? Icons.check_circle : Icons.circle,
                                color: picked
                                    ? AppColors.success
                                    : AppColors.pending,
                                size: 24,
                              ),
                              title: Text(
                                stop.fullName.isNotEmpty
                                    ? stop.fullName
                                    : stop.stopLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                stop.stopLabel,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: StatusChip.pickup(stop.status),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChoiceButton extends StatelessWidget {
  const _StatusChoiceButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: SizedBox(
        width: double.infinity,
        child: Text(
          label,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: color,
      backgroundColor: AppColors.tint(color),
      side: BorderSide(color: color.withAlpha(selected ? 255 : 100)),
      onSelected: enabled ? (_) => onTap() : null,
    );
  }
}
