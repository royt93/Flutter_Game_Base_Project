import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../../../core/utils/format.dart';

/// Single booster slot definition (FEAT-129).
class BoosterSlot {
  BoosterSlot({
    required this.id,
    required this.label,
    this.icon,
    this.iconData = Icons.flash_on_rounded,
    this.count = 0,
    this.cooldown = Duration.zero,
    this.isLocked = false,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be empty');
    }
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'must be non-negative');
    }
    if (cooldown.isNegative) {
      throw ArgumentError.value(cooldown, 'cooldown', 'must not be negative');
    }
  }

  final String id;
  final String label;
  final Widget? icon;
  final IconData iconData;
  final int count;
  final Duration cooldown;
  final bool isLocked;

  /// Ready for use: unlocked, not cooling down, count > 0.
  bool get isReady => !isLocked && cooldown <= Duration.zero && count > 0;

  /// Empty: unlocked, not cooling down, count == 0.
  bool get isEmpty => !isLocked && cooldown <= Duration.zero && count <= 0;

  /// In cooldown: unlocked, cooldown > 0.
  bool get isCoolingDown => !isLocked && cooldown > Duration.zero;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoosterSlot &&
          id == other.id &&
          label == other.label &&
          count == other.count &&
          cooldown == other.cooldown &&
          isLocked == other.isLocked;

  @override
  int get hashCode => Object.hash(id, label, count, cooldown, isLocked);
}

/// A compact casual game power-up bar showing 1 to 5 booster slots (FEAT-129).
///
/// Features:
/// - Distinct visual states: Ready, Empty (with + buy badge), Cooldown (with ticking countdown),
///   and Locked (with lock overlay).
/// - 1-second countdown timer per cooling-down slot, transitioning to ready automatically.
/// - Badge pop animation on count increases, respecting Reduce Motion.
/// - RepaintBoundary and per-slot state isolation so unchanged slots don't rebuild.
/// - Full accessibility semantics for slot state and count.
class BoosterSlotBar extends StatelessWidget {
  BoosterSlotBar({
    super.key,
    required this.slots,
    this.onSlotTap,
    this.onEmptySlotTap,
    this.slotSize = 56,
    this.spacing = NeonTheme.s8,
    this.activeColor,
    this.direction = Axis.horizontal,
    this.semanticLabel,
  }) {
    if (slots.isEmpty || slots.length > 5) {
      throw ArgumentError.value(
        slots.length,
        'slots.length',
        'must have 1 to 5 slots',
      );
    }
    if (!slotSize.isFinite || slotSize <= 0) {
      throw ArgumentError.value(
        slotSize,
        'slotSize',
        'must be positive and finite',
      );
    }
    if (!spacing.isFinite || spacing < 0) {
      throw ArgumentError.value(
        spacing,
        'spacing',
        'must be non-negative and finite',
      );
    }
    final ids = <String>{};
    for (final s in slots) {
      if (!ids.add(s.id)) {
        throw ArgumentError.value(
          s.id,
          'slots',
          'duplicate slot ID: "${s.id}"',
        );
      }
    }
  }

  final List<BoosterSlot> slots;
  final void Function(String id)? onSlotTap;
  final void Function(String id)? onEmptySlotTap;
  final double slotSize;
  final double spacing;
  final Color? activeColor;
  final Axis direction;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final children = [
      for (var i = 0; i < slots.length; i++) ...[
        if (i > 0)
          direction == Axis.horizontal
              ? SizedBox(width: spacing)
              : SizedBox(height: spacing),
        _BoosterSlotItem(
          key: ValueKey('boosterSlot_${slots[i].id}'),
          slot: slots[i],
          slotSize: slotSize,
          activeColor: activeColor ?? NeonTheme.cyan,
          onSlotTap: onSlotTap,
          onEmptySlotTap: onEmptySlotTap,
        ),
      ],
    ];

    final rowOrColumn = direction == Axis.horizontal
        ? Row(mainAxisSize: MainAxisSize.min, children: children)
        : Column(mainAxisSize: MainAxisSize.min, children: children);

    if (semanticLabel != null) {
      return Semantics(
        container: true,
        label: semanticLabel,
        child: rowOrColumn,
      );
    }
    return rowOrColumn;
  }
}

class _BoosterSlotItem extends StatefulWidget {
  const _BoosterSlotItem({
    super.key,
    required this.slot,
    required this.slotSize,
    required this.activeColor,
    this.onSlotTap,
    this.onEmptySlotTap,
  });

  final BoosterSlot slot;
  final double slotSize;
  final Color activeColor;
  final void Function(String id)? onSlotTap;
  final void Function(String id)? onEmptySlotTap;

  @override
  State<_BoosterSlotItem> createState() => _BoosterSlotItemState();
}

class _BoosterSlotItemState extends State<_BoosterSlotItem>
    with SingleTickerProviderStateMixin {
  late Duration _remaining;
  Timer? _timer;
  late final AnimationController _badgePop;

  bool get _isCoolingDown =>
      !widget.slot.isLocked && _remaining > Duration.zero;

  @override
  void initState() {
    super.initState();
    _remaining = widget.slot.cooldown;
    _badgePop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _BoosterSlotItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.slot.count > oldWidget.slot.count &&
        !NeonTheme.reducedMotion(context)) {
      _badgePop.forward(from: 0.0);
    }
    if (widget.slot.cooldown != oldWidget.slot.cooldown) {
      _remaining = widget.slot.cooldown;
      _startTimerIfNeeded();
    }
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    if (_isCoolingDown) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    if (!mounted) return;
    final next = _remaining - const Duration(seconds: 1);
    final clamped = next.isNegative ? Duration.zero : next;
    setState(() => _remaining = clamped);
    if (clamped == Duration.zero) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _badgePop.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.slot.isLocked || _isCoolingDown) return;
    if (widget.slot.count > 0) {
      widget.onSlotTap?.call(widget.slot.id);
    } else {
      widget.onEmptySlotTap?.call(widget.slot.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final cooling = _isCoolingDown;
    final locked = slot.isLocked;
    final ready = !locked && !cooling && slot.count > 0;
    final empty = !locked && !cooling && slot.count <= 0;
    final reducedMotion = NeonTheme.reducedMotion(context);

    final border = Border.all(
      color: ready
          ? widget.activeColor.withValues(alpha: 0.85)
          : NeonTheme.cardAlt,
      width: ready ? 2.0 : 1.5,
    );

    final shadow = ready
        ? NeonTheme.glow(widget.activeColor, blur: 8)
        : NeonTheme.drop(blur: 4);

    final iconColor = ready
        ? widget.activeColor
        : (locked ? NeonTheme.muted.withValues(alpha: 0.5) : NeonTheme.inkSoft);

    // Build accessibility semantics label
    final String statusDesc;
    if (locked) {
      statusDesc = 'locked';
    } else if (cooling) {
      statusDesc = 'cooling down, ${fmtDur(_remaining)} remaining';
    } else if (empty) {
      statusDesc = 'empty, tap to add';
    } else {
      statusDesc = '${slot.count} available';
    }

    final semanticText = '${slot.label}, $statusDesc';

    return RepaintBoundary(
      child: Semantics(
        container: true,
        button: ready || empty,
        label: semanticText,
        enabled: ready || empty,
        child: ExcludeSemantics(
          child: GestureDetector(
            key: ValueKey('boosterSlotTap_${slot.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: (ready || empty) ? _handleTap : null,
            child: SizedBox(
              width: widget.slotSize,
              height: widget.slotSize,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Slot background container
                  Container(
                    width: widget.slotSize,
                    height: widget.slotSize,
                    decoration: BoxDecoration(
                      color: NeonTheme.card,
                      borderRadius: BorderRadius.circular(16),
                      border: border,
                      boxShadow: shadow,
                    ),
                    child: Center(
                      child:
                          slot.icon ??
                          Icon(
                            slot.iconData,
                            size: widget.slotSize * 0.52,
                            color: iconColor,
                          ),
                    ),
                  ),

                  // Cooldown overlay
                  if (cooling)
                    Container(
                      width: widget.slotSize,
                      height: widget.slotSize,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          _remaining.inSeconds > 0
                              ? '${_remaining.inSeconds}s'
                              : '0s',
                          key: ValueKey('boosterSlotCooldown_${slot.id}'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.slotSize * 0.28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                  // Lock overlay
                  if (locked)
                    Container(
                      width: widget.slotSize,
                      height: widget.slotSize,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.lock_rounded,
                          key: ValueKey('boosterSlotLock_${slot.id}'),
                          color: NeonTheme.gold,
                          size: widget.slotSize * 0.38,
                        ),
                      ),
                    ),

                  // Corner badge: count (>0) or (+) button for empty (0)
                  if (!locked && !cooling)
                    PositionedDirectional(
                      end: -4,
                      top: -4,
                      child: AnimatedBuilder(
                        animation: _badgePop,
                        builder: (context, child) {
                          final scale = reducedMotion
                              ? 1.0
                              : 1.0 +
                                    0.2 *
                                        Curves.easeOutBack.transform(
                                          _badgePop.value,
                                        );
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: empty
                            ? Container(
                                key: ValueKey(
                                  'boosterSlotEmptyBadge_${slot.id}',
                                ),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: NeonTheme.card,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: NeonTheme.lime,
                                    width: 1.5,
                                  ),
                                  boxShadow: NeonTheme.drop(blur: 3),
                                ),
                                child: Icon(
                                  Icons.add_rounded,
                                  size: 14,
                                  color: NeonTheme.lime,
                                ),
                              )
                            : Container(
                                key: ValueKey(
                                  'boosterSlotCountBadge_${slot.id}',
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.activeColor,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: NeonTheme.drop(blur: 3),
                                ),
                                child: Text(
                                  '${slot.count}',
                                  style: TextStyle(
                                    color: NeonTheme.ink,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
