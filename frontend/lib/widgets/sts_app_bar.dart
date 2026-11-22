import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/demo_mode_provider.dart';
import '../theme/app_colors.dart';
import 'role_switch.dart';

/// AppBar estándar de STS con botón opcional de Demo y menú discreto de
/// "Cambiar de rol / Cerrar sesión".
class StsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const StsAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = true,
    this.showRoleSwitch = true,
    this.showDemoToggle = false,
    this.actions,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final bool showRoleSwitch;
  final bool showDemoToggle;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final demo = showDemoToggle ? context.watch<DemoModeProvider>() : null;
    return AppBar(
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Atrás',
              onPressed: onBack ??
                  () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      confirmAndLogout(context);
                    }
                  },
            )
          : null,
      title: subtitle == null
          ? Text(title)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
      actions: [
        if (demo != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ActionChip(
              avatar: Icon(
                Icons.science_outlined,
                size: 16,
                color: demo.enabled ? AppColors.primary : AppColors.textSecondary,
              ),
              label: Text(
                'Demo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      demo.enabled ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              backgroundColor:
                  demo.enabled ? AppColors.primaryContainer : AppColors.surface,
              side: BorderSide(
                color: demo.enabled ? AppColors.primary : AppColors.border,
              ),
              onPressed: () => demo.toggle(),
            ),
          ),
        if (actions != null) ...actions!,
        if (showRoleSwitch) const RoleSwitchAction(),
      ],
    );
  }
}
