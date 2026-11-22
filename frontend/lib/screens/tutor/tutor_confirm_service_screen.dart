import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/sts_app_bar.dart';

/// Día de recolección — Confirmar o rechazar el servicio de hoy.
class TutorConfirmServiceScreen extends StatefulWidget {
  const TutorConfirmServiceScreen({super.key});

  @override
  State<TutorConfirmServiceScreen> createState() =>
      _TutorConfirmServiceScreenState();
}

class _TutorConfirmServiceScreenState extends State<TutorConfirmServiceScreen> {
  bool _submitting = false;

  Future<void> _handleDecision({required bool confirmed}) async {
    if (_submitting) return;

    final accepted = await showConfirmDialog(
      context,
      title: confirmed ? 'Confirmar servicio' : 'Rechazar servicio',
      message: confirmed
          ? '¿Estás seguro de confirmar el servicio?'
          : '¿Estás seguro de rechazar el servicio?',
      confirmLabel: 'SÍ',
      cancelLabel: 'NO',
      isDanger: !confirmed,
    );

    if (!accepted || !mounted) return;

    final session = context.read<SessionProvider>();
    final student = session.student;
    if (student == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay una sesión de tutor activa.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = context.read<ApiService>();
      final updated = await api.setTodayConfirmation(
        student.id,
        confirmed: confirmed,
      );
      await session.updateStudent(updated);

      if (!mounted) return;
      if (confirmed) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.tutorLiveTracking,
          (_) => false,
        );
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.tutorHome,
          (_) => false,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar tu confirmación. Intenta de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<SessionProvider>().student;

    return Scaffold(
      appBar: const StsAppBar(
        title: 'Día de recolección',
        showBack: true,
        showRoleSwitch: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.directions_bus_filled_rounded,
                    size: 44,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Confirma tu servicio',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'El servicio de recolección empezará pronto. Por favor confirma.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              if (student != null && student.fullName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Estudiante: ${student.fullName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
              const SizedBox(height: 44),
              if (_submitting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CircleActionButton(
                      icon: Icons.close_rounded,
                      label: 'No lo necesito',
                      color: AppColors.sos,
                      onTap: () => _handleDecision(confirmed: false),
                    ),
                    _CircleActionButton(
                      icon: Icons.check_rounded,
                      label: 'Confirmar',
                      color: AppColors.success,
                      onTap: () => _handleDecision(confirmed: true),
                    ),
                  ],
                ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 4,
          shadowColor: color.withAlpha(110),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 96,
              height: 96,
              child: Icon(
                icon,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
