import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/route_args.dart';
import '../../config/routes.dart';
import '../../models/enums.dart';
import '../../models/route_model.dart';
import '../../models/student_model.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';
import '../../services/osrm_service.dart';
import '../../services/time_utils.dart';
import '../../theme/app_colors.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/share_helper.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/sts_app_bar.dart';

/// Coordinador 2 — Detalle / edición de ruta, escuela, alumnos e inicio de viaje.
class RouteDetailEditScreen extends StatefulWidget {
  const RouteDetailEditScreen({super.key});

  @override
  State<RouteDetailEditScreen> createState() => _RouteDetailEditScreenState();
}

class _RouteDetailEditScreenState extends State<RouteDetailEditScreen> {
  bool _initialized = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  String? _routeId;
  RouteModel? _route;
  List<Student> _students = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = AppRoutes.argsOf<RouteEditArgs>(context);
      _routeId = args?.routeId;
      _loadOrCreate();
    }
  }

  Future<void> _loadOrCreate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      if (_routeId == null) {
        final coordinatorId = context.read<SessionProvider>().coordinatorId;
        final created = await api.createRoute(coordinatorId: coordinatorId);
        if (!mounted) return;
        setState(() {
          _routeId = created.id;
          _route = created;
          _students = [];
          _loading = false;
        });
      } else {
        final detail = await api.getRoute(_routeId!);
        if (!mounted) return;
        setState(() {
          _route = detail.route;
          _students = detail.students;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la ruta.';
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final id = _routeId;
    if (id == null) return;
    try {
      final detail = await context.read<ApiService>().getRoute(id);
      if (!mounted) return;
      setState(() {
        _route = detail.route;
        _students = detail.students;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.sos : null,
      ),
    );
  }

  Future<void> _editRouteName() async {
    final route = _route;
    if (route == null) return;
    final ctrl = TextEditingController(text: route.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Editar nombre de ruta',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nombre de la ruta'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (newName == null || newName.isEmpty || newName == route.name) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await context
          .read<ApiService>()
          .updateRoute(route.id, name: newName);
      if (!mounted) return;
      setState(() => _route = updated);
      _showSnack('Nombre actualizado');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteRoute() async {
    final route = _route;
    if (route == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Eliminar ruta?',
      message:
          'Se eliminará "${route.name}" junto con todos sus alumnos e incidentes. Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      cancelLabel: 'Cancelar',
      isDanger: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<ApiService>().deleteRoute(route.id);
      if (!mounted) return;
      _showSnack('Ruta eliminada');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
      setState(() => _busy = false);
    }
  }

  Future<void> _pickStartTime() async {
    final route = _route;
    if (route == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeUtils.parseHHmm(route.startTime),
    );
    if (picked == null || !mounted) return;

    final hhmm = TimeUtils.toHHmm(picked);
    setState(() => _busy = true);
    try {
      final updated = await context
          .read<ApiService>()
          .updateRoute(route.id, startTime: hhmm);
      if (!mounted) return;
      setState(() => _route = updated);
      _showSnack('Hora de inicio actualizada');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickSchoolLocation() async {
    final route = _route;
    if (route == null) return;
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.coordinatorSchoolPicker,
      arguments: SchoolPickerArgs(
        initial: route.schoolLocation.latLng,
        address: route.schoolLocation.address,
      ),
    );
    if (result is! SchoolPickerResult || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = await context.read<ApiService>().updateRoute(
            route.id,
            schoolLocation: SchoolLocation.fromLatLng(
              result.location,
              address: result.address,
            ),
          );
      if (!mounted) return;
      setState(() => _route = updated);
      _showSnack('Ubicación de la escuela guardada');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openStudentForm({Student? student}) async {
    final route = _route;
    if (route == null) return;
    final changed = await Navigator.of(context).pushNamed(
      AppRoutes.coordinatorStudentForm,
      arguments: StudentFormArgs(routeId: route.id, student: student),
    );
    if (changed == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _deleteStudent(Student student) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Eliminar alumno?',
      message:
          'Se eliminará a ${student.fullName} (${student.shortCode}) de esta ruta.',
      confirmLabel: 'Eliminar',
      cancelLabel: 'Cancelar',
      isDanger: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<ApiService>().deleteStudent(student.id);
      if (!mounted) return;
      setState(() {
        _students.removeWhere((s) => s.id == student.id);
      });
      _showSnack('Alumno eliminado');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startRoute() async {
    final route = _route;
    if (route == null) return;

    if (route.status.isActiveTrip) {
      await Navigator.of(context).pushNamed(
        AppRoutes.coordinatorLive,
        arguments: RouteIdArgs(route.id),
      );
      if (mounted) await _refresh();
      return;
    }

    final confirmedWithPin = _students
        .where(
          (s) =>
              s.todayServiceStatus == TodayServiceStatus.confirmed &&
              s.pickupLocation.isSet,
        )
        .length;
    final confirmedWithoutPin = _students
        .where(
          (s) =>
              s.todayServiceStatus == TodayServiceStatus.confirmed &&
              !s.pickupLocation.isSet,
        )
        .length;

    final extraNote = confirmedWithoutPin > 0
        ? '\n($confirmedWithoutPin confirmado(s) aún no tienen pin de abordaje y no se incluirán.)'
        : '';

    final ok = await showConfirmDialog(
      context,
      title: '¿Iniciar ruta ahora?',
      message:
          'Hay $confirmedWithPin alumno(s) confirmado(s) con punto de abordaje listo para hoy.$extraNote',
      confirmLabel: 'Iniciar ruta',
      cancelLabel: 'Cancelar',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final api = context.read<ApiService>();
      final osrm = context.read<OsrmService>();
      final started = await api.startRoute(route.id);

      // Calcular y guardar polilínea OSRM sin bloquear la navegación si falla.
      final waypoints = [
        ...started.stops.map((s) => s.latLng),
        started.route.schoolLocation.latLng,
      ];
      try {
        final geo = await osrm.fetchRoute(waypoints);
        if (geo.points.length >= 2) {
          await api.saveRoutePolyline(route.id, geo.points);
        }
      } catch (_) {
        // Fallback: el mapa usará línea recta entre paradas y escuela.
      }

      if (!mounted) return;
      setState(() {
        _route = started.route;
        _busy = false;
      });

      await Navigator.of(context).pushNamed(
        AppRoutes.coordinatorLive,
        arguments: RouteIdArgs(route.id),
      );
      if (mounted) await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showSnack('No se pudo iniciar la ruta.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    return Scaffold(
      appBar: StsAppBar(
        title: route?.name ?? 'Ruta',
        subtitle: route != null ? route.shortCode : null,
        showBack: true,
        showRoleSwitch: false,
        actions: route == null
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar nombre',
                  onPressed: _busy ? null : _editRouteName,
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: 'Compartir código de ruta',
                  onPressed: () => shareCode(
                    context,
                    title: 'Ruta ${route.name}',
                    shortCode: route.shortCode,
                    uuid: route.uuid,
                    description: 'Código de acceso para el chofer en STS.',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.sos),
                  tooltip: 'Eliminar ruta',
                  onPressed: _busy ? null : _deleteRoute,
                ),
              ],
      ),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: route == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: PrimaryButton(
                  label: route.status.isActiveTrip
                      ? 'Ver ruta en vivo'
                      : 'Iniciar ruta',
                  icon: route.status.isActiveTrip
                      ? Icons.directions_bus
                      : Icons.play_arrow_rounded,
                  loading: _busy,
                  onPressed: _startRoute,
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingView(message: 'Cargando detalles de la ruta...');
    }
    if (_error != null || _route == null) {
      return ErrorView(
        message: _error ?? 'No se encontró la ruta.',
        onRetry: _loadOrCreate,
      );
    }

    final route = _route!;
    final schoolSubtitle = route.schoolLocation.address.isNotEmpty
        ? route.schoolLocation.address
        : '${route.schoolLocation.lat.toStringAsFixed(4)}, ${route.schoolLocation.lng.toStringAsFixed(4)}';

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Configuración de ruta',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      StatusChip.route(route.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryContainer,
                      child: Icon(Icons.schedule, color: AppColors.primary),
                    ),
                    title: const Text(
                      'Hora de inicio',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    subtitle: Text(
                      TimeUtils.to12h(route.startTime),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy ? null : _pickStartTime,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryContainer,
                      child: Icon(Icons.school, color: AppColors.primary),
                    ),
                    title: const Text(
                      'Definir escuela',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    subtitle: Text(
                      schoolSubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                    ),
                    onTap: _busy ? null : _pickSchoolLocation,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Alumnos (${_students.length})',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _openStudentForm(),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Agregar'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_students.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                child: EmptyView(
                  icon: Icons.school_outlined,
                  title: 'Sin alumnos en esta ruta',
                  subtitle:
                      'Toca "+ Agregar" para registrar alumnos y generar sus códigos.',
                ),
              ),
            )
          else
            ..._students.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StudentCard(
                  student: s,
                  onTap: () => _openStudentForm(student: s),
                  onShare: () => shareCode(
                    context,
                    title: 'Alumno ${s.fullName}',
                    shortCode: s.shortCode,
                    uuid: s.uuid,
                    description: 'Código de acceso para el tutor en STS.',
                  ),
                  onDelete: () => _deleteStudent(s),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.onTap,
    required this.onShare,
    required this.onDelete,
  });

  final Student student;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final missingPin = !student.pickupLocation.isSet;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  student.firstName.isNotEmpty
                      ? student.firstName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${student.grade} · ${student.shortCode}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusChip.service(student.todayServiceStatus),
                        if (missingPin)
                          const StatusChip(
                            label: 'Sin pin',
                            color: AppColors.warning,
                            icon: Icons.location_off_outlined,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.share_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                tooltip: 'Compartir código al tutor',
                onPressed: onShare,
              ),
              IconButton(
                icon: const Icon(
                  Icons.close,
                  size: 20,
                  color: AppColors.sos,
                ),
                tooltip: 'Eliminar alumno',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
