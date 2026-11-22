import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../config/route_args.dart';
import '../../config/routes.dart';
import '../../models/student_model.dart';
import '../../providers/session_provider.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/sts_app_bar.dart';
import '../../widgets/sts_map.dart';

/// Tutor 5 — Establecer el punto de abordaje en el mapa.
class TutorPickupPinScreen extends StatefulWidget {
  const TutorPickupPinScreen({super.key});

  @override
  State<TutorPickupPinScreen> createState() => _TutorPickupPinScreenState();
}

class _TutorPickupPinScreenState extends State<TutorPickupPinScreen> {
  final _mapController = MapController();
  late LatLng _selectedPin;
  bool _locating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionProvider>();
    _selectedPin = session.student?.pickupLocation.latLng ??
        session.tutorRoute?.schoolLocation.latLng ??
        AppConfig.defaultMapCenter;
  }

  Future<void> _centerOnCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final locationService = context.read<LocationService>();
      final pos = await locationService.currentLatLng();
      if (!mounted) return;
      if (pos == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo obtener tu ubicación actual. Toca el mapa para fijar el pin.',
            ),
          ),
        );
        return;
      }
      setState(() => _selectedPin = pos);
      _mapController.move(pos, 16);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _finish() async {
    final session = context.read<SessionProvider>();
    final student = session.student;
    if (student == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay una sesión de tutor activa.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await session.updateStudent(
        student.copyWith(
          pickupLocation: PickupLocation(
            lat: _selectedPin.latitude,
            lng: _selectedPin.longitude,
            isSet: true,
          ),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushNamed(AppRoutes.tutorSaving);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        AppRoutes.argsOf<TutorFlowArgs>(context) ?? const TutorFlowArgs();
    final route = context.watch<SessionProvider>().tutorRoute;

    return Scaffold(
      appBar: StsAppBar(
        title: args.editMode ? 'Editar punto de abordaje' : 'Punto de abordaje',
        showBack: true,
        showRoleSwitch: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Establece el punto de abordaje',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nadie tendrá acceso a esta ubicación más que el dueño de este dispositivo.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Stack(
                  children: [
                    StsMap(
                      controller: _mapController,
                      initialCenter: _selectedPin,
                      initialZoom: AppConfig.defaultZoom,
                      pickupPin: _selectedPin,
                      schoolPoint: route?.schoolLocation.latLng,
                      onTap: (point) => setState(() => _selectedPin = point),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 64,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(235),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'Toca el mapa para mover el pin (${_selectedPin.latitude.toStringAsFixed(4)}, ${_selectedPin.longitude.toStringAsFixed(4)})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'tutor_my_location',
                        tooltip: 'Mi ubicación actual',
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        onPressed: _locating ? null : _centerOnCurrentLocation,
                        child: _locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Icon(Icons.my_location),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Finalizar',
                icon: Icons.check,
                loading: _saving,
                onPressed: _finish,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
