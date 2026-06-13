import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';

/// Một nút hành động trong [NeonDialog].
class NeonDialogAction {
  final String label;
  final Color color;
  final VoidCallback onTap;

  /// true = tự đóng dialog trước khi chạy onTap.
  final bool closeFirst;

  const NeonDialogAction({
    required this.label,
    required this.color,
    required this.onTap,
    this.closeFirst = true,
  });
}

/// Dialog neon dùng chung cho toàn app (win/lose, xác nhận, thông báo...).
class NeonDialog {
  static Future<T?> show<T>({
    required String title,
    required Color color,
    required List<NeonDialogAction> actions,
    String? message,
    Widget? content,
    IconData? icon,
    bool dismissible = false,
  }) {
    return Get.dialog<T>(
      barrierDismissible: dismissible,
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B1B3A), Color(0xFF120F26)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color, width: 2.5),
            boxShadow: NeonTheme.glow(color, blur: 28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 46, shadows: [
                  Shadow(color: color, blurRadius: 22),
                ]),
                const SizedBox(height: 12),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  shadows: [Shadow(color: color, blurRadius: 20)],
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
              if (content != null) ...[const SizedBox(height: 14), content],
              const SizedBox(height: 24),
              Row(
                children: [
                  for (final a in actions) ...[
                    Expanded(child: _DialogButton(action: a)),
                    if (a != actions.last) const SizedBox(width: 12),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final NeonDialogAction action;
  const _DialogButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Đóng dialog trước; nếu onTap có điều hướng (vd pop màn chơi) thì chạy
        // ở frame kế tiếp để tránh 2 lần pop đồng bộ bị GetX nuốt mất.
        if (action.closeFirst && (Get.isDialogOpen ?? false)) {
          Get.back();
          WidgetsBinding.instance
              .addPostFrameCallback((_) => action.onTap());
        } else {
          action.onTap();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: action.color, width: 2),
          boxShadow: NeonTheme.glow(action.color, blur: 10),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            action.label,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'Orbitron',
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              shadows: [Shadow(color: action.color, blurRadius: 8)],
            ),
          ),
        ),
      ),
    );
  }
}
