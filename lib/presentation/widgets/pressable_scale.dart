import 'package:flutter/material.dart';

import '../../core/neon_theme.dart';
import 'spring_scale_transition.dart';

/// Bọc 1 nút bấm để co nhẹ (scale) lúc nhấn xuống — micro-bounce dùng chung
/// cho mọi nút (A3). Tái dùng 1 chỗ thay vì lặp GestureDetector+AnimatedScale
/// ở từng widget nút.
///
/// FEAT-82: cũng là điểm sửa keyboard/gamepad activation DUY NHẤT cần cho
/// gần như toàn bộ kit — `CommonButton`/`NeonButton`/`AvatarFrame`/
/// `LeaderboardList`/`CommonListTile`/`RewardChoicePanel`/`SoundToggleFab`/
/// `SegmentedTabBar`/`CandyToggleSwitch`/`LevelSelectGrid`/
/// `DailyLoginCalendarWidget` đều bọc qua đúng widget này (verify bằng
/// grep trước khi sửa, không phải giả định) — sửa 1 chỗ, cả kit được
/// focusable + Enter/Space (và D-pad gamepad, ánh xạ qua cùng
/// `ActivateIntent` Flutter framework tự bind sẵn) kích hoạt được, thay vì
/// gesture-only như trước (gap đã ghi nhận cụ thể trong Quyết định của
/// FEAT-53/PauseOverlay).
///
/// **Không đổi hành vi gì với người chơi chỉ dùng cảm ứng**: không có
/// `Focus`/`Actions` nào được gắn khi [onTap] là `null` (giữ nguyên
/// "no-op" convention `AvatarFrame`/`LeaderboardList` đã ghi), và viền
/// focus chỉ vẽ khi `FocusManager.instance.highlightMode` đang
/// [FocusHighlightMode.traditional] — chế độ đó CHỈ được framework tự
/// chuyển sang sau 1 tương tác bàn phím/gamepad/chuột thật, không bao giờ
/// từ 1 cú chạm màn hình.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.onTap,
    required this.child,
    this.scale = 0.94,
    this.springPreset = SpringMotionPreset.snappy,
    this.focusNode,
    this.autofocus = false,
  });

  final VoidCallback? onTap;
  final Widget child;
  final double scale;
  final SpringMotionPreset springPreset;

  /// Caller-supplied focus node — when omitted, this widget manages its
  /// own internally (created/disposed with the widget's own lifecycle).
  final FocusNode? focusNode;

  /// Requests focus as soon as this widget is first built — for a caller
  /// (e.g. a modal's first/most-important action) wanting keyboard/
  /// gamepad focus to land here immediately, same reasoning
  /// `FocusTrapScope`'s own `autofocus` param exists for.
  final bool autofocus;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  bool _focused = false;
  FocusNode? _internalFocusNode;
  bool _reducedMotion = false;
  late final SpringSimulationController _spring = SpringSimulationController(
    vsync: this,
    preset: widget.springPreset,
    initialValue: 0,
  );

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = NeonTheme.reducedMotion(context);
    if (_reducedMotion && _spring.value != (_down ? 1 : 0)) {
      _spring.jumpTo(_down ? 1 : 0);
    }
  }

  void _setDown(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
    _spring.animateTo(v ? 1 : 0, reducedMotion: _reducedMotion);
  }

  void _setFocused(bool v) {
    if (_focused != v) setState(() => _focused = v);
  }

  @override
  void dispose() {
    _spring.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final content = GestureDetector(
      onTapDown: enabled ? (_) => _setDown(true) : null,
      onTapCancel: enabled ? () => _setDown(false) : null,
      onTapUp: enabled ? (_) => _setDown(false) : null,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _spring.animation,
        child: widget.child,
        builder: (context, child) => Transform.scale(
          scale: 1 + (widget.scale - 1) * _spring.value,
          child: child,
        ),
      ),
    );

    // onTap == null: giữ nguyên hệt trước FEAT-82 — không Focus/Actions
    // nào cả, không thể focus vào 1 nút đã disable.
    if (!enabled) return content;

    // `Actions` MUST be an ANCESTOR of `Focus`, not a child of it —
    // `Shortcuts` resolves an intent by walking UP the tree starting from
    // the focused node's own context, so an `Actions` handler nested
    // BELOW `Focus` (inside its `child`) is invisible to that walk (found
    // by actually running this: Enter/Space silently did nothing until
    // the nesting order was swapped).
    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onFocusChange: _setFocused,
        child: Builder(
          builder: (context) {
            final showFocusRing =
                _focused &&
                FocusManager.instance.highlightMode ==
                    FocusHighlightMode.traditional;
            return DecoratedBox(
              decoration: BoxDecoration(
                border: showFocusRing
                    ? Border.all(color: NeonTheme.gold, width: 3)
                    : null,
                borderRadius: BorderRadius.circular(999),
              ),
              child: content,
            );
          },
        ),
      ),
    );
  }
}
