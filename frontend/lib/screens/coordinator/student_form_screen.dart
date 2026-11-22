import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/route_args.dart';
import '../../config/routes.dart';
import '../../models/student_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/share_helper.dart';
import '../../widgets/sts_app_bar.dart';

/// Coordinador 3 — Agregar o editar alumno y datos de su tutor.
class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({super.key});

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _studentFirstCtrl = TextEditingController();
  final _studentLastCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();

  final _tutorFirstCtrl = TextEditingController();
  final _tutorLastCtrl = TextEditingController();
  final _phone1Ctrl = TextEditingController();
  final _phone2Ctrl = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  String? _routeId;
  Student? _editingStudent;

  bool get _isEditing => _editingStudent != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = AppRoutes.argsOf<StudentFormArgs>(context);
      _routeId = args?.routeId;
      _editingStudent = args?.student;
      final s = _editingStudent;
      if (s != null) {
        _studentFirstCtrl.text = s.firstName;
        _studentLastCtrl.text = s.lastName;
        _gradeCtrl.text = s.grade;
        _tutorFirstCtrl.text = s.tutor.firstName;
        _tutorLastCtrl.text = s.tutor.lastName;
        _phone1Ctrl.text = s.tutor.phone1;
        _phone2Ctrl.text = s.tutor.phone2;
      }
    }
  }

  @override
  void dispose() {
    _studentFirstCtrl.dispose();
    _studentLastCtrl.dispose();
    _gradeCtrl.dispose();
    _tutorFirstCtrl.dispose();
    _tutorLastCtrl.dispose();
    _phone1Ctrl.dispose();
    _phone2Ctrl.dispose();
    super.dispose();
  }

  String? _required(String? v, String label) {
    if (v == null || v.trim().isEmpty) {
      return 'Ingresa $label';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final routeId = _routeId;
    if (routeId == null && !_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró la ruta asociada.'),
          backgroundColor: AppColors.sos,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final payload = StudentPayload(
      firstName: _studentFirstCtrl.text.trim(),
      lastName: _studentLastCtrl.text.trim(),
      grade: _gradeCtrl.text.trim(),
      tutor: TutorInfo(
        firstName: _tutorFirstCtrl.text.trim(),
        lastName: _tutorLastCtrl.text.trim(),
        phone1: _phone1Ctrl.text.trim(),
        phone2: _phone2Ctrl.text.trim(),
      ),
    );

    try {
      final api = context.read<ApiService>();
      if (_isEditing) {
        await api.updateStudent(_editingStudent!.id, payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alumno actualizado correctamente')),
        );
        Navigator.of(context).pop(true);
      } else {
        final created = await api.createStudent(routeId!, payload);
        if (!mounted) return;
        setState(() => _saving = false);
        await _showCreatedCodeDialog(created);
        if (!mounted) return;
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.sos),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la información del alumno.'),
          backgroundColor: AppColors.sos,
        ),
      );
    }
  }

  Future<void> _showCreatedCodeDialog(Student student) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Alumno registrado',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Comparte este código con el tutor de ${student.fullName} para que pueda acceder a STS:',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withAlpha(100)),
              ),
              child: Column(
                children: [
                  SelectableText(
                    student.shortCode,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.primary,
                    ),
                  ),
                  if (student.uuid.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SelectableText(
                      student.uuid,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Compartir código al tutor',
              icon: Icons.share_outlined,
              onPressed: () => shareCode(
                ctx,
                title: 'Código STS — ${student.fullName}',
                shortCode: student.shortCode,
                uuid: student.uuid,
                description:
                    'Usa este código en la app STS para registrar el punto de abordaje.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StsAppBar(
        title: _isEditing ? 'Editar alumno' : 'Nuevo alumno',
        showBack: true,
        showRoleSwitch: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionHeader(
                  icon: Icons.school_outlined,
                  title: 'Información alumno',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _studentFirstCtrl,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => _required(v, 'el nombre del alumno'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _studentLastCtrl,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Apellido'),
                  validator: (v) => _required(v, 'el apellido del alumno'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _gradeCtrl,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Grado escolar',
                    hintText: 'Ej. 3° Primaria',
                  ),
                  validator: (v) => _required(v, 'el grado escolar'),
                ),
                const SizedBox(height: 24),
                const _SectionHeader(
                  icon: Icons.person_outline,
                  title: 'Información tutor',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tutorFirstCtrl,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => _required(v, 'el nombre del tutor'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tutorLastCtrl,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Apellido'),
                  validator: (v) => _required(v, 'el apellido del tutor'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone1Ctrl,
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Número 1',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => _required(v, 'el teléfono principal'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone2Ctrl,
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Número 2 (opcional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Guardar',
                  icon: Icons.save_outlined,
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
