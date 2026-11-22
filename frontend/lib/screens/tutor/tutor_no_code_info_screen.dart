import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/sts_app_bar.dart';

/// Tutor 2 — Información cuando el tutor aún no tiene código de acceso.
class TutorNoCodeInfoScreen extends StatelessWidget {
  const TutorNoCodeInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StsAppBar(
        title: '¿No tienes código?',
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
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    size: 42,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: const [
                      Text(
                        '¿Cómo obtener tu código?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Cada escuela afiliada al sistema STS (Student Tracking System) tiene personal a cargo de llevar el control de las cuentas y su información. Comunícate con ellos para obtener tu código.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 2),
              PrimaryButton(
                label: 'Regresar',
                icon: Icons.arrow_back,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
