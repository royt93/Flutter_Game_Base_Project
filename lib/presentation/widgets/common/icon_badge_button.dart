import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';

/// Round icon button (e.g. settings/shop) that can carry a small badge in
/// its corner — a plain notification dot (`showBadge`), or a count
/// (`badgeCount`) when a number is needed.
///
/// The badge pops (scale bounce) the moment it newly appears or its count
/// changes — same "something just happened" moment `StreakCounter`/
/// `ProgressBarStars` already animate — but never on initial mount even if
/// the badge is already showing.
class IconBadgeButton extends StatefulWidget {
  const IconBadgeButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.showBadge = false,
    this.badgeCount,
    this.color,
    this.badgeColor,
    this.size = 44,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onTap;

  /// Screen-reader label. Falls back to [icon]'s debug string (not
  /// human-readable) when omitted — always pass this in real usage.
  final String? semanticLabel;

  /// Shows a plain (numberless) badge dot when true.
  final bool showBadge;

  /// When > 0, shows a numeric badge instead of the plain dot (badgeCount >
  /// 99 -> "99+").
  final int? badgeCount;

  final Color? color;

  /// Badge color. Default: red.
  final Color? badgeColor;

  final double size;

  bool get _hasCount => badgeCount != null && badgeCount! > 0;
  bool get _badgeVisible => showBadge || _hasCount;

  @override
  State<IconBadgeButton> createState() => _IconBadgeButtonState();
}

class _IconBadgeButtonState extends State<IconBadgeButton>
    with SingleTickerProviderStateMixin {
  // Bắt đầu đã settled (value 1.0) — không pop lúc mount dù badge hiện sẵn
  // đang bật. Chỉ forward(from: 0.0) khi badge thực sự vừa xuất hiện hoặc
  // đổi số, theo đúng convention của StreakCounter/ProgressBarStars.
  //
  // Khởi tạo trong initState (không dùng `late final` lazy-init) — nếu
  // badge chưa hiện lúc mount, build() không bao giờ đọc `_controller`, để
  // nó lazy-init thì lần đọc đầu tiên lại xảy ra trong dispose(), lúc
  // element đã deactivate — gây lỗi.
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  }

  @override
  void didUpdateWidget(covariant IconBadgeButton old) {
    super.didUpdateWidget(old);
    final justAppeared = !old._badgeVisible && widget._badgeVisible;
    final countChanged =
        widget._badgeVisible && old.badgeCount != widget.badgeCount;
    if ((justAppeared || countChanged) && !NeonTheme.reducedMotion(context)) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final c = enabled ? (widget.color ?? NeonTheme.purple) : NeonTheme.muted;
    final darker = Color.lerp(c, Colors.black, 0.22)!;
    // ENH-37: appends the badge state so a screen reader hears e.g.
    // "Notifications, new notification" or "Mail, 12 unread" instead of
    // just the bare icon label — the badge dot itself is a decorative
    // colored circle with no meaning to announce on its own.
    final baseLabel = widget.semanticLabel ?? widget.icon.toString();
    final label = widget._hasCount
        ? '$baseLabel, ${widget.badgeCount} unread'
        : widget.showBadge
        ? '$baseLabel, new'
        : baseLabel;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      // The count badge's own Text (e.g. "12") would otherwise duplicate
      // into the merged label alongside the explicit ", N unread" suffix.
      excludeSemantics: true,
      child: PressableScale(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: widget.size,
                height: widget.size,
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
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: widget.size * 0.5,
                ),
              ),
              if (widget._badgeVisible)
                Positioned(
                  right: -2,
                  top: -2,
                  child: AnimatedBuilder(
                    animation: _scale,
                    builder: (context, child) => Transform.scale(
                      key: const Key('iconBadgeButtonBadgeScale'),
                      scale: _scale.value,
                      child: child,
                    ),
                    child: widget._hasCount
                        ? _buildCountBadge()
                        : _buildDotBadge(),
                  ),
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
        color: widget.badgeColor ?? NeonTheme.red,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }

  Widget _buildCountBadge() {
    final text = widget.badgeCount! > 99 ? '99+' : '${widget.badgeCount}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: widget.badgeColor ?? NeonTheme.red,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
