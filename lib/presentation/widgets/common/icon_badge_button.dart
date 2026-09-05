import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';

/// Nút icon tròn (vd settings/shop) có thể gắn 1 badge nhỏ ở góc — chấm tròn
/// báo có-thông-báo (`showBadge`), hoặc số lượng (`badgeCount`) khi cần đếm.
class IconBadgeButton extends StatelessWidget {
  const IconBadgeButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.showBadge = false,
    this.badgeCount,
    this.color,
    this.badgeColor,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback? onTap;

  /// Hiện 1 chấm badge trơn (không số) khi true.
  final bool showBadge;

  /// Khi > 0, hiện badge dạng số thay cho chấm trơn (badgeCount > 99 -> "99+").
  final int? badgeCount;

  final Color? color;

  /// Màu badge. Mặc định: đỏ.
  final Color? badgeColor;

  final double size;

  bool get _hasCount => badgeCount != null && badgeCount! > 0;
  bool get _badgeVisible => showBadge || _hasCount;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final c = enabled ? (color ?? NeonTheme.purple) : NeonTheme.muted;
    final darker = Color.lerp(c, Colors.black, 0.22)!;
    return Semantics(
      button: true,
      enabled: enabled,
      label: icon.toString(),
      child: PressableScale(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.lerp(c, Colors.white, 0.18)!, c],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: darker, width: 3),
                  boxShadow: enabled ? NeonTheme.drop(y: 4, blur: 8) : null,
                ),
                child: Icon(icon, color: Colors.white, size: size * 0.5),
              ),
              if (_badgeVisible)
                Positioned(
                  right: -2,
                  top: -2,
                  child: _hasCount ? _buildCountBadge() : _buildDotBadge(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDotBadge() {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: badgeColor ?? NeonTheme.red,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }

  Widget _buildCountBadge() {
    final text = badgeCount! > 99 ? '99+' : '$badgeCount';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: badgeColor ?? NeonTheme.red,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
      ),
    );
  }
}
