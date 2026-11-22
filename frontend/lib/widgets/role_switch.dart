import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/routes.dart';
import '../providers/session_provider.dart';
import '../services/socket_service.dart';
import 'confirm_dialog.dart';

/// Pide confirmación, cierra sesión, desconecta sockets y regresa a
/// `RoleSelectionScreen` limpiando el stack de navegación.
Future<void> confirmAndLogout(BuildContext context) async {
  final ok = await showConfirmDialog(
    context,
    title: 'Cambiar de rol',
    message: '¿Deseas cerrar la sesión actual y volver a la selección de rol?',
    confirmLabel: 'Sí, salir',
    cancelLabel: 'Cancelar',
  );
  if (!ok || !context.mounted) return;
  context.read<SocketService>().disconnect();
  await context.read<SessionProvider>().logout();
  if (!context.mounted) return;
  Navigator.of(context).pushNamedAndRemoveUntil(
    AppRoutes.roleSelection,
    (_) => false,
  );
}

/// Botón discreto para el AppBar que permite cambiar de rol / cerrar sesión.
class RoleSwitchAction extends StatelessWidget {
  const RoleSwitchAction({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Opciones',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'logout') {
          confirmAndLogout(context);
        } else if (value == 'server') {
          Navigator.of(context).pushNamed(AppRoutes.serverSettings);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'logout',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.swap_horiz),
            title: Text('Cambiar de rol / Cerrar sesión'),
          ),
        ),
        PopupMenuItem(
          value: 'server',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.settings_ethernet),
            title: Text('Configurar servidor'),
          ),
        ),
      ],
    );
  }
}
