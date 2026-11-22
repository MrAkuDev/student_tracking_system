import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../providers/session_provider.dart';
import '../../services/time_utils.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/role_switch.dart';
import '../../widgets/sts_app_bar.dart';

/// Chofer 4 — Término del viaje.
class DriverTripFinishedScreen extends StatelessWidget {
  const DriverTripFinishedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final route = context.watch<SessionProvider>().driverRoute;
    final formattedTime = TimeUtils.to12h(route?.startTime ?? '07:30');

    return Scaffold(
      appBar: StsAppBar(
        title: 'Viaje finalizado',
        showBack: true,
        onBack: () => Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.driverRoute,
          (_) => false,
        ),
        showRoleSwitch: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: AppColors.tint(AppColors.success),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.success.withAlpha(90),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 62,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Viaje finalizado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Gracias por tu servicio. El próximo viaje aparecerá aquí cuando esté disponible.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Siguiente ruta programada: mañana a las $formattedTime',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (route != null &&
                                (route.name.isNotEmpty ||
                                    route.shortCode.isNotEmpty)) ...[
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (route.name.isNotEmpty) route.name,
                                  if (route.shortCode.isNotEmpty)
                                    route.shortCode,
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Volver a espera de ruta',
                icon: Icons.directions_bus_rounded,
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.driverRoute,
                    (_) => false,
                  );
                },
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () => confirmAndLogout(context),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Cambiar de rol'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
