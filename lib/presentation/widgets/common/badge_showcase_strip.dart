import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

/// Caller-supplied badge content to showcase on a player profile.
@immutable
class BadgeShowcaseItem {
  BadgeShowcaseItem({
    required this.id,
    required this.label,
    this.icon,
    this.child,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be blank');
    }
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be blank');
    }
    if (icon != null && child != null) {
      throw ArgumentError('provide either icon or child, not both');
    }
  }

  final String id;
  final String label;
  final IconData? icon;
  final Widget? child;
}

/// Fixed number of badge showcase slots. Empty slots let the caller open a
/// badge picker; ownership and persistence remain outside this widget.
class BadgeShowcaseStrip extends StatefulWidget {
  BadgeShowcaseStrip({
    super.key,
    required this.slotCount,
    required this.badges,
    required this.onSlotTap,
    this.emptyLabel = 'Empty badge slot',
    this.readOnly = false,
  }) {
    if (slotCount < 1 || slotCount > 8) {
      throw ArgumentError.value(slotCount, 'slotCount', 'must be in 1..8');
    }
    if (badges.length > slotCount) {
      throw ArgumentError.value(
        badges.length,
        'badges',
        'must not exceed slotCount',
      );
    }
    final ids = <String>{};
    for (final badge in badges) {
      if (!ids.add(badge.id)) {
        throw ArgumentError.value(badge.id, 'badges', 'duplicate id');
      }
    }
    if (emptyLabel.trim().isEmpty) {
      throw ArgumentError.value(emptyLabel, 'emptyLabel', 'must not be blank');
    }
  }

  final int slotCount;
  final List<BadgeShowcaseItem> badges;
  final ValueChanged<int> onSlotTap;
  final String emptyLabel;
  final bool readOnly;

  @override
  State<BadgeShowcaseStrip> createState() => _BadgeShowcaseStripState();
}

class _BadgeShowcaseStripState extends State<BadgeShowcaseStrip>
    with SingleTickerProviderStateMixin {
  static const double _slotSize = 64;
  static const double _gap = 8;
  late final AnimationController _pulse;
  late final Map<String, String> _previousSlotIds;
  Set<int> _pulsingSlots = const {};

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1,
    );
    _previousSlotIds = _slotIds(widget);
  }

  @override
  void didUpdateWidget(covariant BadgeShowcaseStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _slotIds(widget);
    final old = Map<String, String>.of(_previousSlotIds);
    _previousSlotIds
      ..clear()
      ..addAll(next);
    if (NeonTheme.reducedMotion(context)) return;
    final changed = <int>{};
    for (var index = 0; index < widget.slotCount; index++) {
      if (old['$index'] != next['$index'] && next['$index'] != null) {
        changed.add(index);
      }
    }
    if (changed.isNotEmpty) {
      _pulsingSlots = changed;
      _pulse.forward(from: 0);
    }
  }

  static Map<String, String> _slotIds(BadgeShowcaseStrip widget) => {
    for (var index = 0; index < widget.badges.length; index++)
      '$index': widget.badges[index].id,
  };

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final extent = math.max(_slotSize, 24 * textScale + 12);
    return SizedBox(
      height: extent + 42 * textScale + 16,
      child: ListView.builder(
        key: const ValueKey('badgeShowcaseList'),
        scrollDirection: Axis.horizontal,
        itemExtent: extent + _gap,
        itemCount: widget.slotCount,
        itemBuilder: (context, index) => _slot(index),
      ),
    );
  }

  Widget _slot(int index) {
    final hasBadge = index < widget.badges.length;
    final badge = hasBadge ? widget.badges[index] : null;
    final spoken = badge == null
        ? '${index + 1}, ${widget.emptyLabel}'
        : '${index + 1}, ${badge.label}';
    final canTap = !widget.readOnly;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _slotSize,
          height: _slotSize,
          decoration: BoxDecoration(
            color: NeonTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: badge == null
                  ? NeonTheme.inkSoft.withValues(alpha: 0.45)
                  : NeonTheme.gold,
              width: badge == null ? 1.5 : 2.5,
            ),
          ),
          child: Center(
            child: badge == null
                ? Icon(Icons.add_rounded, size: 28, color: NeonTheme.inkSoft)
                : (badge.child ??
                      Icon(
                        badge.icon ?? Icons.emoji_events_rounded,
                        size: 30,
                        color: NeonTheme.gold,
                      )),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: _slotSize + 8,
          child: Text(
            badge?.label ?? widget.emptyLabel,
            key: ValueKey('badgeShowcaseLabel_$index'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: NeonTheme.inkSoft, fontSize: 11),
          ),
        ),
      ],
    );
    Widget item = content;
    if (_pulsingSlots.contains(index)) {
      item = AnimatedBuilder(
        animation: _pulse,
        child: content,
        builder: (_, child) => Transform.scale(
          scale: 1 + 0.08 * math.sin(math.pi * _pulse.value),
          child: child,
        ),
      );
    }
    return Semantics(
      container: true,
      button: canTap,
      enabled: canTap,
      selected: hasBadge,
      label: spoken,
      onTap: canTap ? () => widget.onSlotTap(index) : null,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('badgeShowcaseSlot_$index'),
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: canTap ? () => widget.onSlotTap(index) : null,
        child: Opacity(
          opacity: widget.readOnly && !hasBadge ? 0.45 : 1,
          child: item,
        ),
      ),
    );
  }
}
