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
    this.color,
  });

  final IconData icon;
  final String message;

  /// Defaults to [NeonTheme.purple] — nullable because a `NeonTheme` color
  /// field is no longer a compile-time constant.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? NeonTheme.purple;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(NeonTheme.s16),
          decoration: BoxDecoration(
            color: NeonTheme.cardAlt,
            shape: BoxShape.circle,
            // Nhẹ hơn AvatarFrame's glow vì đây là trạng thái "rỗng", không
            // nên quá nổi bật — chỉ đủ để nhất quán "ngôn ngữ glow" của kit.
            boxShadow: NeonTheme.glow(color, blur: 10, intensity: 0.4),
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
