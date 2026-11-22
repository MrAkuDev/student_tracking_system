import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/route_args.dart';
import '../../config/routes.dart';
import '../../providers/session_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/sts_app_bar.dart';

/// Tutor 4 — Validar / editar datos del tutor y del estudiante.
class TutorValidateDataScreen extends StatefulWidget {
  const TutorValidateDataScreen({super.key});

  @override
  State<TutorValidateDataScreen> createState() =>
      _TutorValidateDataScreenState();
}

class _TutorValidateDataScreenState extends State<TutorValidateDataScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _tutorFirstNameCtrl;
  late final TextEditingController _tutorLastNameCtrl;
  late final TextEditingController _tutorPhone1Ctrl;
  late final TextEditingController _tutorPhone2Ctrl;

  late final TextEditingController _studentFirstNameCtrl;
  late final TextEditingController _studentLastNameCtrl;
  late final TextEditingController _studentGradeCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final student = context.read<SessionProvider>().student;
    _tutorFirstNameCtrl =
        TextEditingController(text: student?.tutor.firstName ?? '');
    _tutorLastNameCtrl =
        TextEditingController(text: student?.tutor.lastName ?? '');
    _tutorPhone1Ctrl = TextEditingController(text: student?.tutor.phone1 ?? '');
    _tutorPhone2Ctrl = TextEditingController(text: student?.tutor.phone2 ?? '');

    _studentFirstNameCtrl =
        TextEditingController(text: student?.firstName ?? '');
    _studentLastNameCtrl = TextEditingController(text: student?.lastName ?? '');
    _studentGradeCtrl = TextEditingController(text: student?.grade ?? '');
  }

  @override
  void dispose() {
    _tutorFirstNameCtrl.dispose();
    _tutorLastNameCtrl.dispose();
    _tutorPhone1Ctrl.dispose();
    _tutorPhone2Ctrl.dispose();
    _studentFirstNameCtrl.dispose();
    _studentLastNameCtrl.dispose();
    _studentGradeCtrl.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obligatorio';
    }
    return null;
  }

  Future<void> _onContinue(TutorFlowArgs args) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final session = context.read<SessionProvider>();
    final student = session.student;
    if (student == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay una sesión de tutor activa.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = student.copyWith(
        firstName: _studentFirstNameCtrl.text.trim(),
        lastName: _studentLastNameCtrl.text.trim(),
        grade: _studentGradeCtrl.text.trim(),
        tutor: student.tutor.copyWith(
          firstName: _tutorFirstNameCtrl.text.trim(),
          lastName: _tutorLastNameCtrl.text.trim(),
          phone1: _tutorPhone1Ctrl.text.trim(),
          phone2: _tutorPhone2Ctrl.text.trim(),
        ),
      );

      await session.updateStudent(updated);
      if (!mounted) return;
      Navigator.of(context).pushNamed(
        AppRoutes.tutorPickupPin,
        arguments: TutorFlowArgs(editMode: args.editMode),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        AppRoutes.argsOf<TutorFlowArgs>(context) ?? const TutorFlowArgs();

    return Scaffold(
      appBar: const StsAppBar(
        title: 'Tus Datos',
        showBack: true,
        showRoleSwitch: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tus Datos',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Verifica o corrige tu información de contacto.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tutorFirstNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: _requiredValidator,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tutorLastNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: _requiredValidator,
                  decoration: const InputDecoration(
                    labelText: 'Apellido',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tutorPhone1Ctrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: _requiredValidator,
                  decoration: const InputDecoration(
                    labelText: 'Número 1',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tutorPhone2Ctrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Número 2 (opcional)',
                    prefixIcon: Icon(Icons.phone_in_talk_outlined),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Datos del estudiante',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _studentFirstNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: _requiredValidator,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.face_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _studentLastNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: _requiredValidator,
                  decoration: const InputDecoration(
                    labelText: 'Apellido',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _studentGradeCtrl,
                  textInputAction: TextInputAction.done,
                  validator: _requiredValidator,
                  decoration: const InputDecoration(
                    labelText: 'Grado',
                    hintText: 'Ej. 3° Primaria',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Continuar',
                  trailingIcon: Icons.arrow_forward,
                  loading: _saving,
                  onPressed: () => _onContinue(args),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
