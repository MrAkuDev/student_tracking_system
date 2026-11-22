import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/route_args.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/sts_app_bar.dart';

/// Coordinador 5 — Confirmación de llegada a la escuela.
class ConfirmArrivalScreen extends StatefulWidget {
  const ConfirmArrivalScreen({super.key});

  @override
  State<ConfirmArrivalScreen> createState() => _ConfirmArrivalScreenState();
}

class _ConfirmArrivalScreenState extends State<ConfirmArrivalScreen> {
  bool _initialized = false;
  bool _submitting = false;
  String? _routeId;
  String _routeName = 'Ruta';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = AppRoutes.argsOf<RouteIdArgs>(context);
      _routeId = args?.routeId;
      if (_routeId != null) {
        _loadRouteName(_routeId!);
      }
    }
  }

  Future<void> _loadRouteName(String routeId) async {
    try {
      final detail = await context.read<ApiService>().getRoute(routeId);
      if (!mounted) return;
      setState(() => _routeName = detail.route.name);
    } catch (_) {
      // Mantiene el título por defecto si no se pudo precargar.
    }
  }

  Future<void> _confirmArrival() async {
    final routeId = _routeId;
    if (routeId == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      await context.read<ApiService>().confirmArrival(routeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Llegada confirmada. Viaje finalizado correctamente.'),
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.coordinatorHome,
        (_) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.sos),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo confirmar la llegada.'),
          backgroundColor: AppColors.sos,
        ),
      );
    }
  }

  void _reportProblem() {
    final routeId = _routeId;
    if (routeId == null) return;
    Navigator.of(context).pushNamed(
      AppRoutes.coordinatorReportProblem,
      arguments: RouteIdArgs(routeId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StsAppBar(
        title: _routeName,
        showBack: true,
        showRoleSwitch: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.tint(AppColors.success),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.success.withAlpha(110),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    size: 48,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _routeName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'El transporte llegó al destino. Confirma que todos los alumnos se encuentran.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Confirmar',
                icon: Icons.check_circle_outline,
                loading: _submitting,
                onPressed: _routeId == null ? null : _confirmArrival,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _submitting || _routeId == null
                    ? null
                    : _reportProblem,
                icon: const Icon(
                  Icons.report_problem_outlined,
                  color: AppColors.sos,
                ),
                label: const Text(
                  'Reportar problema',
                  style: TextStyle(
                    color: AppColors.sos,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
