import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../config/route_args.dart';
import '../../config/routes.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/sts_app_bar.dart';
import '../../widgets/sts_map.dart';

/// Selector interactivo de ubicación de la escuela para una ruta.
class SchoolLocationPickerScreen extends StatefulWidget {
  const SchoolLocationPickerScreen({super.key});

  @override
  State<SchoolLocationPickerScreen> createState() =>
      _SchoolLocationPickerScreenState();
}

class _SchoolLocationPickerScreenState
    extends State<SchoolLocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _addressCtrl = TextEditingController();

  bool _initialized = false;
  bool _locating = false;
  LatLng _selected = AppConfig.defaultMapCenter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = AppRoutes.argsOf<SchoolPickerArgs>(context);
      if (args != null) {
        _selected = args.initial;
        _addressCtrl.text = args.address ?? '';
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _centerOnCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await context.read<LocationService>().currentLatLng();
      if (!mounted) return;
      if (pos == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo obtener tu ubicación actual. Verifica los permisos de GPS.',
            ),
          ),
        );
        return;
      }
      setState(() => _selected = pos);
      _mapController.move(pos, AppConfig.defaultZoom);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _save() {
    Navigator.of(context).pop(
      SchoolPickerResult(
        location: _selected,
        address: _addressCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StsAppBar(
        title: 'Ubicación de la escuela',
        showBack: true,
        showRoleSwitch: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Toca en el mapa para fijar el destino final de la ruta.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _addressCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Dirección o nombre de la escuela',
                      hintText: 'Ej. Av. Universidad 1200, Col. Centro',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Stack(
                  children: [
                    StsMap(
                      controller: _mapController,
                      initialCenter: _selected,
                      initialZoom: AppConfig.defaultZoom,
                      schoolPoint: _selected,
                      schoolLabel: 'Escuela',
                      onTap: (point) => setState(() => _selected = point),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'school_picker_my_location',
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.primary,
                        tooltip: 'Usar mi ubicación actual',
                        onPressed: _locating ? null : _centerOnCurrentLocation,
                        child: _locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                children: [
                  Text(
                    'Coordenadas: ${_selected.latitude.toStringAsFixed(5)}, ${_selected.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: 'Guardar ubicación',
                    icon: Icons.check,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
