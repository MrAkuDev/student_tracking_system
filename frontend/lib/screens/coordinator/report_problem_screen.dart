import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/route_args.dart';
import '../../config/routes.dart';
import '../../models/enums.dart';
import '../../models/route_model.dart';
import '../../models/student_model.dart';
import '../../services/api_service.dart';
import '../../services/launcher_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/state_views.dart';
import '../../widgets/sts_app_bar.dart';

/// Coordinador 6 — Reportar problema e información de contacto del tutor.
class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();

  bool _initialized = false;
  bool _loading = true;
  bool _submitting = false;
  bool _finishTripOnReport = true;
  String? _error;

  String? _routeId;
  RouteModel? _route;
  List<Student> _students = [];
  String? _selectedStudentId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = AppRoutes.argsOf<RouteIdArgs>(context);
      _routeId = args?.routeId;
      if (_routeId == null) {
        setState(() {
          _loading = false;
          _error = 'No se recibió el identificador de la ruta.';
        });
      } else {
        _loadRoute();
      }
    }
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    final routeId = _routeId;
    if (routeId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detail = await context.read<ApiService>().getRoute(routeId);
      if (!mounted) return;
      final sorted = List<Student>.from(detail.students)
        ..sort((a, b) {
          final aConf = a.todayServiceStatus == TodayServiceStatus.confirmed;
          final bConf = b.todayServiceStatus == TodayServiceStatus.confirmed;
          if (aConf != bConf) return aConf ? -1 : 1;
          return a.fullName.compareTo(b.fullName);
        });
      setState(() {
        _route = detail.route;
        _students = sorted;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la información de la ruta.';
        _loading = false;
      });
    }
  }

  Student? get _selectedStudent {
    final id = _selectedStudentId;
    if (id == null) return null;
    for (final s in _students) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> _callTutor(String phone) async {
    final ok = await LauncherService.call(phone);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el marcador para $phone')),
      );
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final routeId = _routeId;
    if (routeId == null || _submitting) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      final api = context.read<ApiService>();
      await api.reportIncident(
        routeId,
        description: _descriptionCtrl.text.trim(),
        involvedStudentId: _selectedStudentId,
        reportedByRole: 'coordinator',
      );

      if (_route?.status == RouteStatus.arrivedSchool && _finishTripOnReport) {
        try {
          await api.confirmArrival(routeId);
        } catch (_) {
          // El incidente ya quedó guardado aunque no se cierre el viaje.
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Problema reportado correctamente.')),
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
          content: Text('No se pudo enviar el reporte.'),
          backgroundColor: AppColors.sos,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StsAppBar(
        title: 'Reportar Problema',
        showBack: true,
        showRoleSwitch: false,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingView(message: 'Cargando alumnos de la ruta...');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _loadRoute);
    }

    final selected = _selectedStudent;
    final isArrivedSchool = _route?.status == RouteStatus.arrivedSchool;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¿Qué pasó?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionCtrl,
              enabled: !_submitting,
              minLines: 5,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Describe el problema',
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Describe brevemente lo sucedido';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            const Text(
              '¿Involucra a algún alumno?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _selectedStudentId,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_search_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Ninguno'),
                ),
                ..._students.map(
                  (s) => DropdownMenuItem<String?>(
                    value: s.id,
                    child: Text(
                      s.todayServiceStatus == TodayServiceStatus.confirmed
                          ? '${s.fullName} (${s.grade}) · Confirmado'
                          : '${s.fullName} (${s.grade})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _selectedStudentId = value),
            ),
            if (selected != null) ...[
              const SizedBox(height: 20),
              _TutorContactCard(
                student: selected,
                onCall: _callTutor,
              ),
            ],
            if (isArrivedSchool) ...[
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _finishTripOnReport,
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _finishTripOnReport = v ?? true),
                title: const Text(
                  'Finalizar el viaje después de enviar el reporte',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Reportar',
              icon: Icons.report_outlined,
              variant: PrimaryButtonVariant.danger,
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorContactCard extends StatelessWidget {
  const _TutorContactCard({
    required this.student,
    required this.onCall,
  });

  final Student student;
  final void Function(String phone) onCall;

  @override
  Widget build(BuildContext context) {
    final tutor = student.tutor;
    final hasPhone1 = tutor.phone1.trim().isNotEmpty;
    final hasPhone2 = tutor.phone2.trim().isNotEmpty;

    return Card(
      color: AppColors.primaryContainer.withAlpha(110),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withAlpha(90)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.support_agent, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Después del reporte, comunícate con el tutor',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tutor.fullName.isNotEmpty ? tutor.fullName : 'Tutor sin nombre',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (hasPhone1)
              _PhoneRow(
                label: 'Número 1',
                phone: tutor.phone1,
                onCall: () => onCall(tutor.phone1),
              ),
            if (hasPhone2) ...[
              const SizedBox(height: 8),
              _PhoneRow(
                label: 'Número 2',
                phone: tutor.phone2,
                onCall: () => onCall(tutor.phone2),
              ),
            ],
            if (!hasPhone1 && !hasPhone2)
              const Text(
                'No hay teléfonos registrados para este tutor.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({
    required this.label,
    required this.phone,
    required this.onCall,
  });

  final String label;
  final String phone;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                phone,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onCall,
          icon: const Icon(Icons.call, size: 18),
          label: const Text('Llamar'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
        ),
      ],
    );
  }
}
