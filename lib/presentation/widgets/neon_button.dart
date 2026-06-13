import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/neon_theme.dart';

/// Nút bấm phong cách neon: viền sáng + glow + chữ phát sáng.
class NeonButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final double width;
  final IconData? icon;

  const NeonButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.width = 240,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final c = enabled ? color : Colors.grey;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: NeonTheme.panel.withOpacity(0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c, width: 2.5),
          boxShadow: enabled ? NeonTheme.glow(c, blur: 16) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: c, size: 22),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                shadows: [Shadow(color: c, blurRadius: 12)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
