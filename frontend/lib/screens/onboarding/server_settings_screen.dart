import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../config/routes.dart';
import '../../providers/server_config_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/sts_app_bar.dart';

/// Configuración de URL del backend y utilidades de reinicio/seed de BD.
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late final TextEditingController _urlCtrl;
  bool _testing = false;
  bool _saving = false;
  bool _resetting = false;
  bool _seeding = false;
  String? _statusMessage;
  bool _statusOk = false;

  bool get _busy => _testing || _saving || _resetting || _seeding;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(
      text: context.read<ServerConfigProvider>().baseUrl,
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _statusMessage = null;
    });
    final url = AppConfig.normalizeUrl(_urlCtrl.text);
    try {
      await context.read<ApiService>().health(baseUrl: url);
      if (!mounted) return;
      setState(() {
        _statusOk = true;
        _statusMessage = 'Conexión exitosa con $url';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusOk = false;
        _statusMessage = e.message;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<ServerConfigProvider>().setBaseUrl(_urlCtrl.text);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Servidor guardado: ${context.read<ServerConfigProvider>().baseUrl}',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _resetDatabase() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Resetear base de datos',
      message:
          'Se eliminarán todas las rutas, alumnos e incidentes. Solo quedará el acceso de coordinador (admin / 1234) y la escuela base.\n\n¿Deseas continuar?',
      confirmLabel: 'Sí, resetear',
      cancelLabel: 'Cancelar',
      isDanger: true,
    );
    if (!ok || !mounted) return;

    setState(() {
      _resetting = true;
      _statusMessage = null;
    });
    final url = AppConfig.normalizeUrl(_urlCtrl.text);
    try {
      final msg = await context.read<ApiService>().resetDatabase(baseUrl: url);
      if (!mounted) return;
      await _clearSessionIfActive(msg);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusOk = false;
        _statusMessage = e.message;
      });
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  Future<void> _seedDemo() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Cargar datos demo (Seed)',
      message:
          'Se reiniciará la base de datos y se cargarán las rutas y alumnos de demostración (RUT-101, RUT-102, ALU-1001..ALU-1003).\n\n¿Deseas continuar?',
      confirmLabel: 'Sí, cargar demo',
      cancelLabel: 'Cancelar',
    );
    if (!ok || !mounted) return;

    setState(() {
      _seeding = true;
      _statusMessage = null;
    });
    final url = AppConfig.normalizeUrl(_urlCtrl.text);
    try {
      final msg =
          await context.read<ApiService>().seedDemoDatabase(baseUrl: url);
      if (!mounted) return;
      await _clearSessionIfActive(msg);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusOk = false;
        _statusMessage = e.message;
      });
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  /// Si había una sesión abierta (p. ej. tutor o chofer de una ruta borrada),
  /// cierra sesión para evitar referencias a IDs que ya no existen.
  Future<void> _clearSessionIfActive(String message) async {
    final session = context.read<SessionProvider>();
    if (session.hasSession) {
      context.read<SocketService>().disconnect();
      await session.logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.roleSelection,
        (_) => false,
      );
      return;
    }
    setState(() {
      _statusOk = true;
      _statusMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StsAppBar(
        title: 'Configurar servidor',
        showRoleSwitch: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'URL del Backend STS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Por defecto la app usa el servidor en la nube (Render). Para pruebas locales en emulador Android usa http://10.0.2.2:3000 o la IP local de tu PC.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL del servidor',
                hintText: AppConfig.defaultServerUrl,
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.cloud_outlined, size: 16),
                  label: const Text('Nube (Render)'),
                  onPressed: () =>
                      _urlCtrl.text = AppConfig.defaultServerUrl,
                ),
                ActionChip(
                  label: const Text('Emulador (10.0.2.2)'),
                  onPressed: () =>
                      _urlCtrl.text = AppConfig.emulatorServerUrl,
                ),
                ActionChip(
                  label: const Text('Localhost'),
                  onPressed: () => _urlCtrl.text = 'http://localhost:3000',
                ),
              ],
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.tint(
                    _statusOk ? AppColors.success : AppColors.sos,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _statusOk ? AppColors.success : AppColors.sos,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusOk
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      color: _statusOk ? AppColors.success : AppColors.sos,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _statusOk ? AppColors.success : AppColors.sos,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Probar conexión',
              icon: Icons.wifi_tethering,
              variant: PrimaryButtonVariant.outlined,
              loading: _testing,
              onPressed: _busy ? null : _testConnection,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Guardar',
              icon: Icons.save_outlined,
              loading: _saving,
              onPressed: _busy ? null : _save,
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 20),
            const Text(
              'Base de datos (Pruebas y Demo)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Reinicia los datos del servidor seleccionado para empezar con rutas limpias o restaurar el escenario de demostración.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Cargar datos demo (Seed)',
              icon: Icons.dataset_outlined,
              variant: PrimaryButtonVariant.outlined,
              loading: _seeding,
              onPressed: _busy ? null : _seedDemo,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Resetear base de datos',
              icon: Icons.delete_sweep_outlined,
              variant: PrimaryButtonVariant.danger,
              loading: _resetting,
              onPressed: _busy ? null : _resetDatabase,
            ),
          ],
        ),
      ),
    );
  }
}
