import 'package:flutter/material.dart';

import '../licensing/license_status.dart';

class LicenseStatusBadge extends StatelessWidget {
  const LicenseStatusBadge({
    required this.status,
    required this.isLoading,
    super.key,
  });

  final LicenseStatus status;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final color = _color(status.state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(_icon(status.state), color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            isLoading ? 'Checking licence' : status.displayLabel,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  static Color _color(LicenseState state) => switch (state) {
    LicenseState.active => const Color(0xFF16834B),
    LicenseState.trial => const Color(0xFF2F6DEB),
    LicenseState.gracePeriod => const Color(0xFFC77700),
    LicenseState.activationRequired => const Color(0xFF6B7280),
    LicenseState.expired => const Color(0xFFB42318),
    LicenseState.suspended => const Color(0xFFC77700),
    LicenseState.revoked => const Color(0xFFB42318),
    LicenseState.deactivated => const Color(0xFF6B7280),
    LicenseState.invalid => const Color(0xFFB42318),
  };

  static IconData _icon(LicenseState state) => switch (state) {
    LicenseState.active => Icons.verified_outlined,
    LicenseState.trial => Icons.timer_outlined,
    LicenseState.gracePeriod => Icons.schedule_outlined,
    LicenseState.activationRequired => Icons.key_outlined,
    LicenseState.expired => Icons.event_busy_outlined,
    LicenseState.suspended => Icons.pause_circle_outline,
    LicenseState.revoked => Icons.block_outlined,
    LicenseState.deactivated => Icons.link_off_outlined,
    LicenseState.invalid => Icons.error_outline,
  };
}
