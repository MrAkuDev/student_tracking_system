import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/sts_app_bar.dart';

/// Coordinador 0 — Inicio de sesión del coordinador.
class CoordinatorLoginScreen extends StatefulWidget {
  const CoordinatorLoginScreen({super.key});

  @override
  State<CoordinatorLoginScreen> createState() => _CoordinatorLoginScreenState();
}

class _CoordinatorLoginScreenState extends State<CoordinatorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final session = context.read<SessionProvider>();
      final coordinator = await api.coordinatorLogin(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
      );
      await session.loginCoordinator(coordinator);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.coordinatorHome,
        (_) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Ocurrió un error inesperado al iniciar sesión.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _fillDemoCredentials() {
    _usernameCtrl.text = 'admin';
    _passwordCtrl.text = '1234';
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StsAppBar(
        title: 'Coordinador',
        showBack: true,
        showRoleSwitch: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 38,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Iniciar sesión como coordinador',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingresa tus credenciales para gestionar rutas y alumnos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.tint(AppColors.sos),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.sos.withAlpha(110)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.sos,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.sos,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _usernameCtrl,
                  enabled: !_loading,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresa tu usuario';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  enabled: !_loading,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      tooltip: _obscurePassword ? 'Mostrar' : 'Ocultar',
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Ingresa tu contraseña';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Ingresar',
                  icon: Icons.login,
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 20),
                Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _loading ? null : _fillDemoCredentials,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        'Demo: admin / 1234',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
