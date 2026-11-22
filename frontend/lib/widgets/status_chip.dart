import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme/app_colors.dart';

/// Chip semántico compacto para estatus de ruta, recolección o confirmación.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  factory StatusChip.route(RouteStatus status, {Key? key}) => StatusChip(
        key: key,
        label: status.label,
        color: AppColors.forRoute(status),
        icon: switch (status) {
          RouteStatus.idle => Icons.schedule,
          RouteStatus.inProgress => Icons.directions_bus,
          RouteStatus.paused => Icons.pause_circle_outline,
          RouteStatus.breakdown => Icons.warning_amber_rounded,
          RouteStatus.arrivedSchool => Icons.school,
          RouteStatus.completed => Icons.check_circle_outline,
        },
      );

  factory StatusChip.pickup(PickupStatus status, {Key? key}) => StatusChip(
        key: key,
        label: status.label,
        color: AppColors.forPickup(status),
        icon: status.isPickedUp ? Icons.check_circle : Icons.circle,
      );

  factory StatusChip.service(TodayServiceStatus status, {Key? key}) =>
      StatusChip(
        key: key,
        label: status.label,
        color: AppColors.forService(status),
      );

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.tint(color),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
