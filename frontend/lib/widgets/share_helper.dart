import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Copia el código corto al portapapeles y abre el diálogo nativo para compartir.
Future<void> shareCode(
  BuildContext context, {
  required String title,
  required String shortCode,
  String? uuid,
  String? description,
}) async {
  await Clipboard.setData(ClipboardData(text: shortCode));
  final buffer = StringBuffer()
    ..writeln(title)
    ..writeln('Código: $shortCode');
  if (uuid != null && uuid.isNotEmpty) {
    buffer.writeln('UUID: $uuid');
  }
  if (description != null && description.isNotEmpty) {
    buffer.writeln(description);
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Código $shortCode copiado al portapapeles')),
    );
  }

  try {
    await Share.share(buffer.toString().trim(), subject: title);
  } catch (_) {
    // En entornos sin hoja nativa de compartir ya quedó copiado al portapapeles.
  }
}
