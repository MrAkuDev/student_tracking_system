import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/state_views.dart';

/// Tutor 6 — Pantalla de carga mientras se guarda perfil, pin y recordatorio.
class TutorSavingScreen extends StatefulWidget {
  const TutorSavingScreen({super.key});

  @override
  State<TutorSavingScreen> createState() => _TutorSavingScreenState();
}

class _TutorSavingScreenState extends State<TutorSavingScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _save());
  }

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _error = null);

    final session = context.read<SessionProvider>();
    final api = context.read<ApiService>();
    final student = session.student;
    final route = session.tutorRoute;

    if (student == null) {
      setState(() => _error = 'No hay una sesión de tutor activa.');
      return;
    }

    try {
      final saved = await api.updateTutorProfile(
        student.id,
        tutor: student.tutor,
        firstName: student.firstName,
        lastName: student.lastName,
        grade: student.grade,
        pickupLocation: student.pickupLocation.latLng,
      );
      await session.updateStudent(saved);

      if (route != null) {
        await NotificationService.instance
            .scheduleOneHourBefore(route.startTime);
      }

      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.tutorHome,
        (_) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'No se pudo guardar tu información. Revisa tu conexión e intenta de nuevo.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _error != null
          ? AppBar(
              title: const Text('Error al guardar'),
            )
          : null,
      body: SafeArea(
        child: _error != null
            ? ErrorView(
                message: _error!,
                onRetry: _save,
              )
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          strokeWidth: 4.5,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 28),
                      Text(
                        'Guardando tu información',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Por favor espera un momento...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
