import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/route_args.dart';
import '../../config/routes.dart';
import '../../providers/session_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/sts_app_bar.dart';

/// Tutor 3 — Bienvenida tras validar el código del alumno.
class TutorWelcomeScreen extends StatelessWidget {
  const TutorWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final student = context.watch<SessionProvider>().student;
    final tutorName = student != null && student.tutor.firstName.trim().isNotEmpty
        ? student.tutor.firstName.trim()
        : 'Tutor';

    return Scaffold(
      appBar: const StsAppBar(
        title: '',
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
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Icon(
                    Icons.waving_hand_rounded,
                    size: 46,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Bienvenido $tutorName',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Antes de continuar, asegurémonos que tus datos están correctos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const Spacer(flex: 2),
              PrimaryButton(
                label: 'Empezar',
                trailingIcon: Icons.arrow_forward,
                onPressed: () => Navigator.of(context).pushNamed(
                  AppRoutes.tutorValidateData,
                  arguments: const TutorFlowArgs(editMode: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
