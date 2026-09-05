import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Centered icon + message for "no data yet" states (empty leaderboard, no
/// achievements unlocked, ...). Icon sits in a soft circular badge, mirroring
/// the icon treatment in [NeonDialog.panel] (`neon_dialog.dart`).
class EmptyStatePlaceholder extends StatelessWidget {
  const EmptyStatePlaceholder({
    super.key,
    required this.icon,
    required this.message,
    this.color = NeonTheme.purple,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(NeonTheme.s16),
          decoration: BoxDecoration(
            color: NeonTheme.cardAlt,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 40),
        ),
        const SizedBox(height: NeonTheme.s16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: NeonTheme.inkSoft,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
