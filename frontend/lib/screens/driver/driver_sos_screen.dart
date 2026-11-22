import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';
import '../../services/launcher_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/sts_app_bar.dart';

/// Chofer 3 — Reportar problema / SOS.
class DriverSosScreen extends StatefulWidget {
  const DriverSosScreen({super.key});

  @override
  State<DriverSosScreen> createState() => _DriverSosScreenState();
}

class _DriverSosScreenState extends State<DriverSosScreen> {
  bool _sending = false;
  bool _reported = false;

  Future<void> _sendSos() async {
    final session = context.read<SessionProvider>();
    final route = session.driverRoute;
    if (route == null) {
      _showSnack('No se encontró una ruta activa.');
      return;
    }

    setState(() => _sending = true);
    try {
      final api = context.read<ApiService>();
      final res = await api.sendSos(route.id);
      if (!mounted) return;

      await session.updateDriverRoute(
        route.copyWith(status: RouteStatus.paused),
      );
      if (!mounted) return;

      final phone = res.coordinatorPhone.isNotEmpty
          ? res.coordinatorPhone
          : (session.coordinatorPhone ?? '');

      final called =
          phone.isNotEmpty ? await LauncherService.call(phone) : false;
      if (!mounted) return;

      setState(() => _reported = true);
      _showSnack(
        called
            ? 'Alerta SOS enviada. Ruta en pausa y abriendo llamada al coordinador.'
            : 'Alerta SOS enviada. La ruta pasó a estado En pausa.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnack('No se pudo enviar la alerta SOS.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final phone = context.watch<SessionProvider>().coordinatorPhone;

    return Scaffold(
      appBar: const StsAppBar(
        title: 'Reportar problema',
        showBack: true,
        showRoleSwitch: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    color: AppColors.tint(AppColors.sos),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.sos.withAlpha(90),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    size: 56,
                    color: AppColors.sos,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Reportar problema',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Contacta de inmediato al coordinador para reportar cualquier problema.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.pause_circle_outline_rounded,
                            color: AppColors.warning,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Al presionar Reportar, la ruta pasará automáticamente a "En pausa" y se notificará al coordinador y a los tutores.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (phone != null && phone.isNotEmpty) ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_in_talk_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Teléfono del coordinador',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    phone,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Reportar',
                icon: Icons.notifications_active_rounded,
                variant: PrimaryButtonVariant.danger,
                loading: _sending,
                onPressed: _sendSos,
              ),
              if (_reported) ...[
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'Volver a la ruta',
                  icon: Icons.arrow_back_rounded,
                  variant: PrimaryButtonVariant.outlined,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
