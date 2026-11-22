import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/route_args.dart';
import '../../config/routes.dart';
import '../../models/enums.dart';
import '../../providers/demo_mode_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../services/time_utils.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/sts_app_bar.dart';

/// Tutor 7 — Inicio / Próximas recolecciones (Lunes a Viernes).
class TutorHomeScreen extends StatefulWidget {
  const TutorHomeScreen({super.key});

  @override
  State<TutorHomeScreen> createState() => _TutorHomeScreenState();
}

class _TutorHomeScreenState extends State<TutorHomeScreen> {
  bool _initialLoading = true;
  String? _error;
  final Set<String> _updatingDays = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final session = context.read<SessionProvider>();
    final student = session.student;
    if (student == null) {
      if (mounted) {
        setState(() {
          _initialLoading = false;
          _error = 'No hay una sesión de tutor activa.';
        });
      }
      return;
    }

    try {
      final api = context.read<ApiService>();
      final res = await api.getTutorStudent(student.id);
      await session.updateStudent(res.student, route: res.route);
      if (!mounted) return;
      setState(() {
        _error = null;
        _initialLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _error = 'No se pudo actualizar la información.';
      });
    }
  }

  Future<void> _toggleDay(String day, bool currentEnabled) async {
    final session = context.read<SessionProvider>();
    final student = session.student;
    if (student == null || _updatingDays.contains(day)) return;

    setState(() => _updatingDays.add(day));
    try {
      final api = context.read<ApiService>();
      final updated = await api.setTutorSchedule(
        student.id,
        day: day,
        enabled: !currentEnabled,
      );
      await session.updateStudent(updated);
      if (!mounted) return;
      final label = kWeekdayLabels[day] ?? day;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentEnabled
                ? '$label reactivado para recolección.'
                : 'Recolección cancelada para el $label.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el horario. Intenta de nuevo.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingDays.remove(day));
      }
    }
  }

  Future<void> _simulateOneHourNotification() async {
    await NotificationService.instance.showNow(
      'Confirma tu servicio',
      'La recolección empezará pronto, confirma el servicio',
      payload: NotificationPayloads.confirmService,
      fullScreen: true,
    );
    if (!mounted) return;
    Navigator.of(context).pushNamed(AppRoutes.tutorConfirmService);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final demo = context.watch<DemoModeProvider>();
    final student = session.student;
    final route = session.tutorRoute;

    return Scaffold(
      appBar: const StsAppBar(
        title: 'Próximas recolecciones',
        showBack: true,
        showDemoToggle: true,
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'tutor_edit_data_fab',
        tooltip: 'Editar datos y punto de abordaje',
        onPressed: () => Navigator.of(context).pushNamed(
          AppRoutes.tutorValidateData,
          arguments: const TutorFlowArgs(editMode: true),
        ),
        child: const Icon(Icons.manage_accounts_rounded),
      ),
      body: SafeArea(
        child: _initialLoading && student == null
            ? const LoadingView(message: 'Cargando recolecciones...')
            : student == null
                ? ErrorView(
                    message: _error ?? 'No hay sesión de tutor activa.',
                    onRetry: _refresh,
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      children: [
                        // Resumen del alumno y su ruta
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.directions_bus_rounded,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student.fullName.isNotEmpty
                                            ? student.fullName
                                            : 'Estudiante',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        route != null
                                            ? '${route.name} · ${TimeUtils.to12h(route.startTime)}'
                                            : 'Ruta asignada',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusChip.service(student.todayServiceStatus),
                              ],
                            ),
                          ),
                        ),

                        // Tarjeta rápida de seguimiento en vivo cuando la ruta está activa y el alumno confirmado
                        if (route != null &&
                            route.status.isActiveTrip &&
                            student.todayServiceStatus ==
                                TodayServiceStatus.confirmed) ...[
                          const SizedBox(height: 12),
                          Card(
                            color: AppColors.primaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.gps_fixed_rounded,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Transporte en curso',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      StatusChip.route(route.status),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  PrimaryButton(
                                    label: 'Ver seguimiento en vivo',
                                    icon: Icons.map_outlined,
                                    onPressed: () => Navigator.of(context)
                                        .pushNamed(AppRoutes.tutorLiveTracking),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.tint(AppColors.warning),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                        const Text(
                          'Horario semanal',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Lista de los 5 días hábiles
                        for (final day in kWeekdayKeys) ...[
                          _WeekdayScheduleTile(
                            label: kWeekdayLabels[day] ?? day,
                            enabled: student.weeklySchedule.isEnabled(day),
                            loading: _updatingDays.contains(day),
                            onToggle: () => _toggleDay(
                              day,
                              student.weeklySchedule.isEnabled(day),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Nota: El mismo día podrás cancelar el servicio 1 hora antes.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Panel / botón discreto de Demo
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: demo.enabled
                                ? AppColors.primaryContainer
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: demo.enabled
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.notifications_active_outlined,
                                    size: 18,
                                    color: demo.enabled
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    demo.enabled
                                        ? 'Modo Demo activo'
                                        : 'Control de demostración',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: demo.enabled
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              PrimaryButton(
                                label: 'Simular notificación (1h antes)',
                                icon: Icons.notifications_outlined,
                                variant: demo.enabled
                                    ? PrimaryButtonVariant.filled
                                    : PrimaryButtonVariant.outlined,
                                onPressed: _simulateOneHourNotification,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _WeekdayScheduleTile extends StatelessWidget {
  const _WeekdayScheduleTile({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onToggle,
  });

  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.success : AppColors.textSecondary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: enabled ? AppColors.success : AppColors.border,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      decoration: enabled ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    enabled ? 'Recolección activa' : 'Cancelado',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            if (loading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              )
            else
              IconButton(
                tooltip: enabled ? 'Cancelar día' : 'Reactivar día',
                onPressed: onToggle,
                icon: Icon(
                  enabled
                      ? Icons.cancel_outlined
                      : Icons.add_circle_outline_rounded,
                  color: enabled ? AppColors.sos : AppColors.primary,
                  size: 26,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
