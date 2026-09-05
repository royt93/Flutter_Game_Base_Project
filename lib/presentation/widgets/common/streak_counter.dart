import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Fire icon + a streak day count (consecutive logins, ...). Same
/// layout/spacing as [CurrencyCounter] but simpler — no count-up animation
/// needed.
class StreakCounter extends StatelessWidget {
  const StreakCounter({
    super.key,
    required this.days,
    this.icon = Icons.local_fire_department,
    this.color,
    this.fontSize = 18,
  });

  final int days;
  final IconData icon;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = color ?? NeonTheme.orange;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: c, size: fontSize + 6),
        const SizedBox(width: 4),
        Text(
          '$days',
          style: TextStyle(
            color: NeonTheme.ink,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
