import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';

/// Một nút hành động trong dialog. onTap tự chịu trách nhiệm đóng (route/overlay).
class NeonDialogAction {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const NeonDialogAction({
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class NeonDialog {
  /// Panel hình ảnh thuần (không route) — dùng được cho cả overlay trong game
  /// (render TRÊN GameWidget của Flame) lẫn route dialog.
  static Widget panel({
    required String title,
    required Color color,
    required List<NeonDialogAction> actions,
    String? message,
    Widget? content,
    IconData? icon,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      margin: const EdgeInsets.symmetric(horizontal: 32),
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
    );
  }

  /// Hiển thị dạng route (dùng cho màn KHÔNG có Flame GameWidget: settings...).
  static Future<T?> show<T>({
    required String title,
    required Color color,
    required List<NeonDialogAction> actions,
    String? message,
    Widget? content,
    IconData? icon,
    bool dismissible = false,
  }) {
    // bọc mỗi action: đóng route trước (frame kế) rồi chạy onTap gốc
    final wrapped = actions
        .map((a) => NeonDialogAction(
              label: a.label,
              color: a.color,
              onTap: () {
                if (Get.isDialogOpen ?? false) Get.back();
                WidgetsBinding.instance.addPostFrameCallback((_) => a.onTap());
              },
            ))
        .toList();
    return Get.dialog<T>(
      barrierDismissible: dismissible,
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: panel(
          title: title,
          color: color,
          actions: wrapped,
          message: message,
          content: content,
          icon: icon,
        ),
      ),
    );
  }

  /// Overlay barrier full-screen bọc panel — render TRONG cây widget (trên Flame).
  static Widget overlay({required Widget panel, VoidCallback? onBarrier}) {
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: onBarrier,
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),
          Center(child: panel),
        ],
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
      onTap: action.onTap,
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
