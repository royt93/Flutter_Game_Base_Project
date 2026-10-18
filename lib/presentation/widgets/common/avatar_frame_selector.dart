import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';
import 'avatar_frame.dart';

/// One selectable avatar frame. Ownership and unlock rules stay with the caller.
@immutable
class AvatarFrameOption {
  const AvatarFrameOption({
    required this.id,
    required this.label,
    required this.color,
    this.locked = false,
    this.lockHint,
  });

  final String id;
  final String label;
  final Color color;
  final bool locked;

  /// Caller-formatted unlock hint, read by screen readers for locked frames.
  final String? lockHint;
}

/// Lazy grid of avatar frames to pick from, each previewed on the caller's own
/// avatar. Presentation-only: the caller owns the option list, unlock state and
/// persistence of the choice.
///
/// Tapping the already-selected frame does nothing. Tapping a locked frame calls
/// [onLockedTap] and never changes the selection.
class AvatarFrameSelector extends StatefulWidget {
  AvatarFrameSelector({
    super.key,
    required this.options,
    required this.previewChild,
    required this.onSelect,
    this.onLockedTap,
    this.selectedId,
    this.selectedLabel = 'In use',
    this.lockedLabel = 'Locked',
    this.emptyMessage = 'No frames available',
    this.maxGridHeight = 360,
    this.expand = false,
  }) {
    final ids = <String>{};
    for (final option in options) {
      if (option.id.trim().isEmpty) {
        throw ArgumentError.value(option.id, 'options', 'id must not be blank');
      }
      if (!ids.add(option.id)) {
        throw ArgumentError.value(option.id, 'options', 'duplicate id');
      }
      if (option.label.trim().isEmpty) {
        throw ArgumentError.value(
          option.label,
          'options',
          'label must not be blank',
        );
      }
      final hint = option.lockHint;
      if (hint != null && hint.trim().isEmpty) {
        throw ArgumentError.value(
          hint,
          'options',
          'lockHint must not be blank',
        );
      }
    }
    final selected = selectedId;
    if (selected != null) {
      final match = options.where((o) => o.id == selected);
      if (match.isEmpty) {
        throw ArgumentError.value(
          selected,
          'selectedId',
          'must be one of the option ids',
        );
      }
      if (match.first.locked) {
        throw ArgumentError.value(
          selected,
          'selectedId',
          'must not be a locked frame',
        );
      }
    }
    for (final (name, value) in [
      ('selectedLabel', selectedLabel),
      ('lockedLabel', lockedLabel),
      ('emptyMessage', emptyMessage),
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError.value(value, name, 'must not be blank');
      }
    }
    if (!maxGridHeight.isFinite || maxGridHeight <= 0) {
      throw ArgumentError.value(
        maxGridHeight,
        'maxGridHeight',
        'must be finite and > 0',
      );
    }
  }

  final List<AvatarFrameOption> options;

  /// Avatar content shown inside every preview frame (image, icon, initials).
  final Widget previewChild;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  /// Called with the id of a locked frame. When null, locked frames are inert.
  final ValueChanged<String>? onLockedTap;
  final String selectedLabel;
  final String lockedLabel;
  final String emptyMessage;

  /// Upper bound for the grid height when [expand] is false.
  final double maxGridHeight;

  /// Fill the parent's bounded height instead of sizing to the content. The
  /// parent must provide a bounded height; [maxGridHeight] is ignored.
  final bool expand;

  @override
  State<AvatarFrameSelector> createState() => _AvatarFrameSelectorState();
}

class _AvatarFrameSelectorState extends State<AvatarFrameSelector>
    with SingleTickerProviderStateMixin {
  static const double _avatarSize = 56;
  static const double _gap = 8;

  // Created in initState and settled (value 1) so a frame already selected on
  // mount never pulses.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant AvatarFrameSelector old) {
    super.didUpdateWidget(old);
    if (widget.selectedId != null &&
        widget.selectedId != old.selectedId &&
        !NeonTheme.reducedMotion(context)) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _tap(AvatarFrameOption option) {
    if (option.locked) {
      widget.onLockedTap?.call(option.id);
    } else if (option.id != widget.selectedId) {
      widget.onSelect(option.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) {
      final empty = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            widget.emptyMessage,
            key: const ValueKey('avatarFrameEmpty'),
            textAlign: TextAlign.center,
            style: TextStyle(color: NeonTheme.inkSoft, fontSize: 14),
          ),
        ),
      );
      return widget.expand ? empty : SizedBox(height: 96, child: empty);
    }

    final scaler = MediaQuery.textScalerOf(context);
    final scale = scaler.scale(1);
    // Avatar + gap + two label lines (1.25 line height) + vertical padding +
    // the selected border (2.5 per side, counts as inner padding) + 4dp of
    // slack: bold glyph metrics differ across platforms (macOS vs the Linux CI
    // runner), and an exact fit overflowed by 1px there.
    final cellExtent =
        _avatarSize + 6 + 2 * scaler.scale(12) * 1.25 + 20 + 5 + 4;
    final minCellWidth = 92 + (scale - 1).clamp(0.0, 1.0) * 24;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(
          2,
          ((constraints.maxWidth + _gap) / (minCellWidth + _gap)).floor(),
        );
        final grid = GridView.builder(
          key: const ValueKey('avatarFrameGrid'),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: _gap,
            crossAxisSpacing: _gap,
            mainAxisExtent: cellExtent,
          ),
          itemCount: widget.options.length,
          itemBuilder: (context, index) => _cell(widget.options[index]),
        );
        if (widget.expand) return grid;

        final rows = (widget.options.length + columns - 1) ~/ columns;
        final content = rows * cellExtent + (rows - 1) * _gap;
        return SizedBox(
          height: math.min(content, widget.maxGridHeight),
          child: grid,
        );
      },
    );
  }

  Widget _cell(AvatarFrameOption option) {
    final selected = option.id == widget.selectedId;
    final locked = option.locked;
    final inert = locked && widget.onLockedTap == null;
    final accent = locked ? NeonTheme.muted : option.color;
    final hint = option.lockHint;
    final spoken = selected
        ? '${option.label}, ${widget.selectedLabel}'
        : locked
        ? '${option.label}, ${widget.lockedLabel}${hint == null ? '' : ', $hint'}'
        : option.label;

    Widget avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        Opacity(
          opacity: locked ? 0.45 : 1,
          child: AvatarFrame(
            color: accent,
            size: _avatarSize,
            child: widget.previewChild,
          ),
        ),
        if (selected || locked)
          PositionedDirectional(
            end: -4,
            top: -4,
            child: Container(
              key: ValueKey(
                selected ? 'avatarFrameSelectedMark' : 'avatarFrameLockMark',
              ),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: selected ? accent : NeonTheme.card,
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 1.5),
              ),
              child: Icon(
                selected ? Icons.check_rounded : Icons.lock_rounded,
                size: 14,
                color: selected ? Colors.white : NeonTheme.inkSoft,
              ),
            ),
          ),
      ],
    );
    if (selected) {
      avatar = AnimatedBuilder(
        animation: _pulse,
        child: avatar,
        builder: (_, child) => Transform.scale(
          scale: 1 + 0.08 * math.sin(math.pi * _pulse.value),
          child: child,
        ),
      );
    }

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: !inert,
      label: spoken,
      excludeSemantics: true,
      onTap: inert || selected ? null : () => _tap(option),
      child: PressableScale(
        onTap: inert || selected ? null : () => _tap(option),
        child: Container(
          key: ValueKey('avatarFrameOption_${option.id}'),
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
          decoration: BoxDecoration(
            color: NeonTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(alpha: selected ? 0.95 : 0.35),
              width: selected ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              avatar,
              const SizedBox(height: 6),
              Text(
                option.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: locked ? NeonTheme.inkSoft : NeonTheme.ink,
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
