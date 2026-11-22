import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../providers/server_config_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/sts_app_bar.dart';

/// Configuración de URL del backend (útil para emulador 10.0.2.2 o red local).
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late final TextEditingController _urlCtrl;
  bool _testing = false;
  bool _saving = false;
  String? _statusMessage;
  bool _statusOk = false;

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
              onPressed: _testConnection,
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Guardar',
              icon: Icons.save_outlined,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
