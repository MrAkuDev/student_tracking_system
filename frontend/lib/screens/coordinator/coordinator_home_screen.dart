import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/route_args.dart';
import '../../config/routes.dart';
import '../../models/route_model.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';
import '../../services/time_utils.dart';
import '../../theme/app_colors.dart';
import '../../widgets/share_helper.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/sts_app_bar.dart';

/// Coordinador 1 — Inicio / Mis Rutas.
class CoordinatorHomeScreen extends StatefulWidget {
  const CoordinatorHomeScreen({super.key});

  @override
  State<CoordinatorHomeScreen> createState() => _CoordinatorHomeScreenState();
}

class _CoordinatorHomeScreenState extends State<CoordinatorHomeScreen> {
  List<RouteModel> _routes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final api = context.read<ApiService>();
      final session = context.read<SessionProvider>();
      final list = await api.getRoutes(coordinatorId: session.coordinatorId);
      if (!mounted) return;
      setState(() {
        _routes = list;
        _error = null;
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
        _error = 'No se pudieron cargar las rutas.';
        _loading = false;
      });
    }
  }

  Future<void> _openCreateRoute() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.coordinatorRouteEdit,
      arguments: const RouteEditArgs(),
    );
    if (!mounted) return;
    await _loadRoutes(showLoader: false);
  }

  Future<void> _openEditRoute(RouteModel route) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.coordinatorRouteEdit,
      arguments: RouteEditArgs(routeId: route.id),
    );
    if (!mounted) return;
    await _loadRoutes(showLoader: false);
  }

  Future<void> _openLiveRoute(RouteModel route) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.coordinatorLive,
      arguments: RouteIdArgs(route.id),
    );
    if (!mounted) return;
    await _loadRoutes(showLoader: false);
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = context.watch<SessionProvider>().coordinator;
    final subtitle = (coordinator != null && coordinator.name.isNotEmpty)
        ? coordinator.name
        : 'Coordinador';

    return Scaffold(
      appBar: StsAppBar(
        title: 'Bienvenido',
        subtitle: subtitle,
        showBack: true,
        showRoleSwitch: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Mis Rutas',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _openCreateRoute,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Nueva'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingView(message: 'Cargando rutas...');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _loadRoutes);
    }
    if (_routes.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadRoutes(showLoader: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            EmptyView(
              icon: Icons.directions_bus_outlined,
              title: 'Aún no tienes rutas',
              subtitle: 'Toca el botón "+ Nueva" para crear tu primera ruta.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadRoutes(showLoader: false),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: _routes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _RouteCard(
          route: _routes[index],
          onLive: () => _openLiveRoute(_routes[index]),
          onEdit: () => _openEditRoute(_routes[index]),
          onShare: () => shareCode(
            context,
            title: 'Ruta ${_routes[index].name}',
            shortCode: _routes[index].shortCode,
            uuid: _routes[index].uuid,
            description: 'Código de acceso para el chofer en STS.',
          ),
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.onLive,
    required this.onEdit,
    required this.onShare,
  });

  final RouteModel route;
  final VoidCallback onLive;
  final VoidCallback onEdit;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final isActive = route.status.isActiveTrip;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                route.shortCode,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.schedule,
                              size: 15,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              TimeUtils.to12h(route.startTime),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip.route(route.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.groups_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${route.studentCount} alumnos · ${route.confirmedCount} confirmados',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _ActionIconButton(
                    icon: Icons.directions_bus,
                    tooltip: 'Ver ruta en vivo',
                    highlighted: isActive,
                    onPressed: onLive,
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Editar ruta',
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.share_outlined,
                    tooltip: 'Compartir código',
                    onPressed: onShare,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.highlighted = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primaryContainer : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted ? AppColors.primary : AppColors.border,
        ),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: 20,
          color: highlighted ? AppColors.primary : AppColors.textPrimary,
        ),
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }
}
