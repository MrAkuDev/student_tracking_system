import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/demo_mode_provider.dart';
import '../theme/app_colors.dart';

/// Alterna el Modo Demo:
/// - Si ya está activo, lo desactiva directamente sin mostrar diálogo.
/// - Si está inactivo, muestra una ventana emergente explicando qué activa
///   el Modo Demo con el botón "Activar".
Future<void> toggleDemoMode(BuildContext context) async {
  final demo = context.read<DemoModeProvider>();
  if (demo.enabled) {
    await demo.setEnabled(false);
    return;
  }

  final activate = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.science_outlined, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Modo Demo', style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'El Modo Demo facilita probar todo el flujo de la aplicación sin necesidad de desplazarte físicamente:',
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          SizedBox(height: 12),
          _BulletItem(
            text:
                'Chofer: habilita el simulador de recorrido para avanzar por la ruta, saltar a la siguiente parada y simular la llegada a la escuela.',
          ),
          SizedBox(height: 8),
          _BulletItem(
            text:
                'Tutor: destaca el botón para simular la notificación de 1 hora antes y reduce el regreso automático tras llegar a la escuela de 5 minutos a 10 segundos.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Activar'),
        ),
      ],
    ),
  );

  if (activate == true && context.mounted) {
    await demo.setEnabled(true);
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(Icons.circle, size: 6, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
