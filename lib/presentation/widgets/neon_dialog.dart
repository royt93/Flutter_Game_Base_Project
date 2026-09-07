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

const _kDialogDuration = Duration(milliseconds: 220);
const _kDialogCurve = Curves.easeOutBack;

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
            style: TextStyle(
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
              style: TextStyle(
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
          if (actions.isNotEmpty) ...[
            const SizedBox(height: NeonTheme.s24),
            Row(
              children: [
                for (final a in actions) ...[
                  Expanded(child: NeonDialogButton(action: a)),
                  if (a != actions.last) const SizedBox(width: NeonTheme.s16),
                ],
              ],
            ),
          ],
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
    dlog('NeonDialog.show CALL title=$title (showGeneralDialog native)');
    final transitionDuration = NeonTheme.reducedMotion(context)
        ? Duration.zero
        : _kDialogDuration;
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierLabel: title,
      transitionDuration: transitionDuration,
      pageBuilder: (_, _, _) => Dialog(
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
      transitionBuilder: (context, animation, secondary, child) =>
          FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: _kDialogCurve,
                reverseCurve: Curves.easeIn,
              ),
              child: child,
            ),
          ),
    );
  }

  /// Barrier + panel bọc trong Stack — render TRONG cây widget (trên Flame).
  /// Không tự bọc `Positioned.fill`: nơi gọi (vd `_Overlay` trong
  /// `game_screen.dart`) chịu trách nhiệm định vị full-screen, để có thể lồng
  /// trong `AnimatedSwitcher` (Positioned chỉ hợp lệ khi cha trực tiếp là
  /// Stack, còn AnimatedSwitcher bọc mỗi child qua FadeTransition).
  /// A9: panel scale+fade vào thay vì snap hiện tức thì (TweenAnimationBuilder
  /// tự chạy 1 lần lúc mount vì tween bắt đầu từ giá trị mặc định 0).
  static Widget overlay({required Widget panel, VoidCallback? onBarrier}) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onBarrier,
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),
        Center(
          // panel()/overlay() are static methods with no ambient
          // BuildContext of their own — a Builder gets one at the point the
          // widget tree actually mounts, so reducedMotion can be checked.
          child: Builder(
            builder: (context) => TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: NeonTheme.reducedMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (_, t, child) => Opacity(
                opacity: t.clamp(0, 1),
                child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
              ),
              child: panel,
            ),
          ),
        ),
      ],
    );
  }

  /// Slot overlay LUÔN mount (không bọc `if` bên ngoài) — cho phép animate cả
  /// vào lẫn ra. [panel] null nghĩa là ẩn (barrier fade ra, panel biến mất
  /// qua [AnimatedSwitcher]); barrier tách riêng khỏi [AnimatedSwitcher] của
  /// panel để tránh double-dim khi cross-fade giữa 2 dialog liên tiếp.
  ///
  /// [panelKey] xác định danh tính logic của [panel] (ví dụ enum trạng thái,
  /// id, hoặc điều kiện bool) — dùng để [AnimatedSwitcher] biết khi nào là
  /// "dialog khác" (cần replay animation) so với "vẫn dialog cũ, chỉ rebuild"
  /// (không replay). Bắt buộc truyền (kể cả `null`) để mỗi call site phải chủ
  /// động chọn danh tính thay vì vô tình rơi vào default — 2 panel non-null
  /// khác nhau mà lỡ cùng bỏ qua tham số này sẽ bị coi là "cùng 1 dialog" và
  /// mất animation chuyển cảnh.
  static Widget overlaySlot({
    required Widget? panel,
    required Object? panelKey,
    VoidCallback? onBarrier,
  }) {
    return Stack(
      children: [
        // overlaySlot() is a static method with no ambient BuildContext of
        // its own — a Builder gets one at the point each half of the tree
        // actually mounts, so reducedMotion can be checked.
        Builder(
          builder: (context) {
            final duration = NeonTheme.reducedMotion(context)
                ? Duration.zero
                : _kDialogDuration;
            return AnimatedOpacity(
              duration: duration,
              opacity: panel == null ? 0 : 1,
              child: IgnorePointer(
                ignoring: panel == null,
                child: GestureDetector(
                  onTap: onBarrier,
                  child: Container(color: Colors.black.withValues(alpha: 0.6)),
                ),
              ),
            );
          },
        ),
        Center(
          child: Builder(
            builder: (context) {
              final duration = NeonTheme.reducedMotion(context)
                  ? Duration.zero
                  : _kDialogDuration;
              return AnimatedSwitcher(
                duration: duration,
                switchInCurve: _kDialogCurve,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: panel == null
                    ? const SizedBox.shrink(key: ValueKey('empty'))
                    : KeyedSubtree(key: ValueKey(panelKey), child: panel),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Nút hành động dùng chung trong [NeonDialog.panel] — public để các dialog
/// tự viết (login streak, weekly goal...) nhúng lại 1 nút reactive đơn lẻ vào
/// `content:` khi cần label/onTap đổi theo state mà không thể dùng `actions:`
/// tĩnh của [NeonDialog.show].
class NeonDialogButton extends StatelessWidget {
  final NeonDialogAction action;
  const NeonDialogButton({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      container: true,
      label: action.label,
      child: PressableScale(
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
                color: NeonTheme.ink,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                shadows: [Shadow(color: action.color, blurRadius: 8)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
