import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Diálogo modal de confirmación reutilizable (SÍ / NO).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool isDanger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: isDanger
              ? FilledButton.styleFrom(
                  backgroundColor: AppColors.sos,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(88, 44),
                )
              : FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}
