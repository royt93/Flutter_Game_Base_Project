import 'package:flutter/material.dart';
import '../../core/debug_log.dart';
import '../../core/neon_theme.dart';
import 'pressable_scale.dart';

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
      margin: const EdgeInsets.symmetric(horizontal: NeonTheme.s24),
      padding: const EdgeInsets.all(NeonTheme.s24),
      decoration: BoxDecoration(
        color: NeonTheme.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color, width: 4),
        boxShadow: [
          ...NeonTheme.glow(color, blur: 26, spread: 2),
          ...NeonTheme.drop(y: 8, blur: 24),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(NeonTheme.s16),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: NeonTheme.drop(y: 3, blur: 8),
              ),
              child: Icon(icon, color: Colors.white, size: 40),
            ),
            const SizedBox(height: NeonTheme.s16),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NeonTheme.ink,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: NeonTheme.s16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NeonTheme.inkSoft,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (content != null) ...[
            const SizedBox(height: NeonTheme.s16),
            content,
          ],
          const SizedBox(height: NeonTheme.s24),
          Row(
            children: [
              for (final a in actions) ...[
                Expanded(child: _DialogButton(action: a)),
                if (a != actions.last) const SizedBox(width: NeonTheme.s16),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Hiển thị dạng route (dùng cho màn KHÔNG có Flame GameWidget: settings...).
  ///
  /// Dùng [showDialog] native (Navigator cục bộ của [context]) thay cho
  /// `Get.dialog` — vì ở chế độ full-screen `Get.dialog` không push được route
  /// (no-op) khiến dialog không hiện.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Color color,
    required List<NeonDialogAction> actions,
    String? message,
    Widget? content,
    IconData? icon,
    bool dismissible = false,
  }) {
    final nav = Navigator.of(context, rootNavigator: true);
    // bọc mỗi action: đóng route trước rồi chạy onTap gốc ở frame kế.
    final wrapped = actions
        .map(
          (a) => NeonDialogAction(
            label: a.label,
            color: a.color,
            onTap: () {
              if (nav.canPop()) nav.pop();
              WidgetsBinding.instance.addPostFrameCallback((_) => a.onTap());
            },
          ),
        )
        .toList();
    dlog('NeonDialog.show CALL title=$title (showDialog native)');
    return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => Dialog(
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
    return PressableScale(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: NeonTheme.s16,
          vertical: NeonTheme.s16,
        ),
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
