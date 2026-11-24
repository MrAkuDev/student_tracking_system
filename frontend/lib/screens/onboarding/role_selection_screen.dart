import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../config/routes.dart';
import '../../providers/demo_mode_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/demo_mode_helper.dart';

/// Pantalla inicial de selección de rol ("¡Hola!" / "Por favor escoge tu rol").
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demo = context.watch<DemoModeProvider>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ActionChip(
              avatar: Icon(
                Icons.science_outlined,
                size: 16,
                color: demo.enabled ? AppColors.primary : AppColors.textSecondary,
              ),
              label: Text(
                demo.enabled ? 'Demo activo' : 'Demo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      demo.enabled ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              backgroundColor:
                  demo.enabled ? AppColors.primaryContainer : AppColors.surface,
              side: BorderSide(
                color: demo.enabled ? AppColors.primary : AppColors.border,
              ),
              onPressed: () => toggleDemoMode(context),
            ),
          ),
          IconButton(
            tooltip: 'Configurar servidor',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.serverSettings),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.directions_bus_rounded,
                    size: 42,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Bienvenido',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Por favor escoge tu rol',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 36),
              _RoleCardButton(
                title: 'Tutor',
                subtitle: 'Sigue el transporte y confirma el servicio de tu hijo',
                icon: Icons.family_restroom_rounded,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.tutorCode),
              ),
              const SizedBox(height: 16),
              _RoleCardButton(
                title: 'Coordinador',
                subtitle: 'Administra rutas, alumnos y monitoreo en tiempo real',
                icon: Icons.admin_panel_settings_rounded,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.coordinatorLogin),
              ),
              const SizedBox(height: 16),
              _RoleCardButton(
                title: 'Chofer',
                subtitle: 'Visualiza tu ruta, confirma paradas y alertas SOS',
                icon: Icons.directions_bus_filled_rounded,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.driverCode),
              ),
              const SizedBox(height: 36),
              const Text(
                '${AppConfig.appName} · ${AppConfig.appSubtitle}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCardButton extends StatelessWidget {
  const _RoleCardButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
