import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum PrimaryButtonVariant { filled, outlined, danger }

/// Botón principal grande de STS con estado de carga integrado.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.variant = PrimaryButtonVariant.filled,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final PrimaryButtonVariant variant;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = loading ? null : onPressed;
    final child = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: variant == PrimaryButtonVariant.outlined
                  ? AppColors.primary
                  : Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(label, overflow: TextOverflow.ellipsis),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, size: 20),
              ],
            ],
          );

    Widget button;
    switch (variant) {
      case PrimaryButtonVariant.filled:
        button = FilledButton(onPressed: effectiveOnPressed, child: child);
        break;
      case PrimaryButtonVariant.outlined:
        button = OutlinedButton(onPressed: effectiveOnPressed, child: child);
        break;
      case PrimaryButtonVariant.danger:
        button = FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.sos,
            foregroundColor: Colors.white,
          ),
          onPressed: effectiveOnPressed,
          child: child,
        );
        break;
    }

    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
