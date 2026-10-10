import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/inventory_service.dart';
import '../../../core/neon_theme.dart';

/// Calculates the top-left offset of a grid cell relative to the grid origin.
Offset inventoryGridCellOffset({
  required int index,
  required int crossAxisCount,
  required double cellSize,
  required double spacing,
}) {
  if (index < 0 || crossAxisCount <= 0 || cellSize < 0 || spacing < 0) {
    return Offset.zero;
  }
  final col = index % crossAxisCount;
  final row = index ~/ crossAxisCount;
  return Offset(col * (cellSize + spacing), row * (cellSize + spacing));
}

/// Calculates the layout translation delta between [oldIndex] and [newIndex].
Offset inventoryGridCellDelta({
  required int oldIndex,
  required int newIndex,
  required int crossAxisCount,
  required double cellSize,
  required double spacing,
}) {
  final oldOffset = inventoryGridCellOffset(
    index: oldIndex,
    crossAxisCount: crossAxisCount,
    cellSize: cellSize,
    spacing: spacing,
  );
  final newOffset = inventoryGridCellOffset(
    index: newIndex,
    crossAxisCount: crossAxisCount,
    cellSize: cellSize,
    spacing: spacing,
  );
  return oldOffset - newOffset;
}

/// Renders one filled cell — [isSelected] reflects [InventoryGrid.selectedSlotId]
/// so the caller decides how to highlight it (this widget holds no
/// selection state of its own, see class doc).
typedef InventoryItemBuilder =
    Widget Function(BuildContext context, InventorySlot slot, bool isSelected);

/// Renders one non-item cell (empty or locked) at [cellIndex] (0-based,
/// stable across rebuilds as long as [InventoryGrid.unlockedCapacity]
/// doesn't change).
typedef InventoryPlaceholderBuilder =
    Widget Function(BuildContext context, int cellIndex);

/// A data-driven grid over an [InventorySnapshot] — like [QuestViewModel]/
/// `LeaderboardEntry`, this widget holds no game logic or catalog of its
/// own; [itemBuilder] is the caller's own renderer (item icon, rarity
/// frame, stack count, equipped badge — this package doesn't ship a
/// concrete item catalog, see `ItemDefinition`'s doc), and a tap never
/// mutates anything here — the caller's own tap handler is expected to
/// call `InventoryService.consume`/`setEquipped`/`moveSlot` itself.
///
/// Cells beyond `snapshot.slots.length` render via [emptyBuilder] (falls
/// back to a plain dim placeholder) up to [unlockedCapacity] (default:
/// `snapshot.capacity`, meaning no locked cells at all), then
/// [lockedBuilder] for the rest — e.g. capacity the player hasn't
/// unlocked yet with an IAP/level-up. [InventorySnapshot] itself has no
/// notion of "locked", so this is purely a presentation concept the
/// caller opts into via [unlockedCapacity].
///
/// **Stable identity across reorder/update**: each filled cell is keyed
/// by [InventorySlot.slotId] (never by its list index) via [KeyedSubtree]
/// — the exact same reasoning as [InventorySlot.slotId]'s own doc comment
/// ("survives a grant/consume elsewhere in the inventory changing the
/// list's indices"). Without this, Flutter would reuse a tile's
/// `State`/subtree by POSITION when the list reorders, silently handing
/// item A's rendered state (an in-progress local animation, say) to
/// wherever item B now sits.
///
/// **Lazy**: built on [GridView.builder] — only visible cells are ever
/// built/laid out, regardless of how large [unlockedCapacity] is.
class InventoryGrid extends StatelessWidget {
  const InventoryGrid({
    super.key,
    required this.snapshot,
    required this.itemBuilder,
    this.unlockedCapacity,
    this.emptyBuilder,
    this.lockedBuilder,
    this.crossAxisCount = 4,
    this.spacing = NeonTheme.s8,
    this.selectedSlotId,
    this.onSlotTap,
    this.onSlotLongPress,
    this.onReorder,
    this.shrinkWrap = false,
    this.physics,
    this.animate = false,
    this.animationDuration = NeonTheme.motionDefault,
    this.animationCurve = NeonTheme.curveSurface,
  });

  final InventorySnapshot snapshot;
  final InventoryItemBuilder itemBuilder;

  /// How many of `max(snapshot.capacity, this)` total cells are usable
  /// (item or empty) rather than locked. `null` means every capacity
  /// slot is unlocked — no locked cells rendered at all.
  final int? unlockedCapacity;
  final InventoryPlaceholderBuilder? emptyBuilder;
  final InventoryPlaceholderBuilder? lockedBuilder;
  final int crossAxisCount;
  final double spacing;

  /// The currently-selected slot's id, or `null` for no selection — this
  /// widget never tracks selection itself (see class doc), a caller
  /// wanting selection re-passes the updated id after [onSlotTap] fires.
  final int? selectedSlotId;
  final ValueChanged<InventorySlot>? onSlotTap;
  final ValueChanged<InventorySlot>? onSlotLongPress;

  /// Fires with the dragged slot's id and the drop target slot's id when
  /// a filled cell is dropped onto another — `null` (the default)
  /// disables drag entirely. Never reorders anything itself; the caller
  /// is expected to call `InventoryService.moveSlot` (or its own
  /// reordering command) from this callback.
  final void Function(int fromSlotId, int toSlotId)? onReorder;

  final bool shrinkWrap;
  final ScrollPhysics? physics;

  /// Enables pop-in scale for newly added items and smooth slide transitions
  /// when items reorder in the grid.
  final bool animate;
  final Duration animationDuration;
  final Curve animationCurve;

  @override
  Widget build(BuildContext context) {
    final unlocked = unlockedCapacity ?? snapshot.capacity;
    final totalCells = math.max(snapshot.capacity, unlocked);

    Widget buildCell(BuildContext context, int index) {
      if (index < snapshot.slots.length) {
        final slot = snapshot.slots[index];
        return KeyedSubtree(
          key: ValueKey(('item', slot.slotId)),
          child: _ItemCell(
            slot: slot,
            index: index,
            crossAxisCount: crossAxisCount,
            spacing: spacing,
            animate: animate,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
            isSelected: slot.slotId == selectedSlotId,
            itemBuilder: itemBuilder,
            onTap: onSlotTap,
            onLongPress: onSlotLongPress,
            onReorder: onReorder,
          ),
        );
      }
      if (index < unlocked) {
        return KeyedSubtree(
          key: ValueKey(('empty', index)),
          child:
              emptyBuilder?.call(context, index) ?? const _DefaultPlaceholder(),
        );
      }
      return KeyedSubtree(
        key: ValueKey(('locked', index)),
        child:
            lockedBuilder?.call(context, index) ??
            const _DefaultPlaceholder(icon: Icons.lock_rounded),
      );
    }

    return GridView.custom(
      shrinkWrap: shrinkWrap,
      physics: physics,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
      ),
      // `GridView.builder`'s plain delegate has no `findChildIndexCallback`
      // — Flutter's sliver reconciliation then only compares "the widget
      // now at index N" against "whatever Element previously occupied
      // index N", NEVER searching the rest of the list for a matching
      // key. A reorder/removal that shifts a slot to a different index
      // would silently hand its OLD Element/State (an in-progress local
      // animation, say) to whatever item now lands at that same index,
      // exactly the bug this class's own doc comment warns against.
      // `findChildIndexCallback` is what makes the KeyedSubtree keys
      // above actually mean something across a rebuild.
      childrenDelegate: SliverChildBuilderDelegate(
        buildCell,
        childCount: totalCells,
        findChildIndexCallback: (key) {
          if (key is! ValueKey<(String, int)>) return null;
          final (kind, id) = key.value;
          if (kind == 'item') {
            final index = snapshot.slots.indexWhere((s) => s.slotId == id);
            return index == -1 ? null : index;
          }
          // Empty/locked cells are identified by their own index already
          // (there's no stable id for "the 3rd empty slot" beyond its
          // position), so no lookup is needed for those.
          return id;
        },
      ),
    );
  }
}

class _ItemCell extends StatelessWidget {
  const _ItemCell({
    required this.slot,
    required this.index,
    required this.crossAxisCount,
    required this.spacing,
    required this.animate,
    required this.animationDuration,
    required this.animationCurve,
    required this.isSelected,
    required this.itemBuilder,
    required this.onTap,
    required this.onLongPress,
    required this.onReorder,
  });

  final InventorySlot slot;
  final int index;
  final int crossAxisCount;
  final double spacing;
  final bool animate;
  final Duration animationDuration;
  final Curve animationCurve;
  final bool isSelected;
  final InventoryItemBuilder itemBuilder;
  final ValueChanged<InventorySlot>? onTap;
  final ValueChanged<InventorySlot>? onLongPress;
  final void Function(int fromSlotId, int toSlotId)? onReorder;

  @override
  Widget build(BuildContext context) {
    Widget baseContent = itemBuilder(context, slot, isSelected);
    if (onTap != null || onLongPress != null) {
      baseContent = GestureDetector(
        onTap: onTap == null ? null : () => onTap!(slot),
        onLongPress: onLongPress == null ? null : () => onLongPress!(slot),
        child: baseContent,
      );
    }

    Widget content = baseContent;
    final reorder = onReorder;
    if (reorder != null) {
      content = DragTarget<int>(
        onAcceptWithDetails: (details) => reorder(details.data, slot.slotId),
        builder: (context, candidateData, rejectedData) => Draggable<int>(
          data: slot.slotId,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(opacity: 0.85, child: baseContent),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: baseContent),
          child: baseContent,
        ),
      );
    }

    if (animate) {
      content = _AnimatedItemCellWrapper(
        index: index,
        crossAxisCount: crossAxisCount,
        spacing: spacing,
        duration: animationDuration,
        curve: animationCurve,
        child: content,
      );
    }

    return content;
  }
}

class _AnimatedItemCellWrapper extends StatefulWidget {
  const _AnimatedItemCellWrapper({
    required this.index,
    required this.crossAxisCount,
    required this.spacing,
    required this.duration,
    required this.curve,
    required this.child,
  });

  final int index;
  final int crossAxisCount;
  final double spacing;
  final Duration duration;
  final Curve curve;
  final Widget child;

  @override
  State<_AnimatedItemCellWrapper> createState() =>
      _AnimatedItemCellWrapperState();
}

class _AnimatedItemCellWrapperState extends State<_AnimatedItemCellWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curved;
  Offset _fromOffset = Offset.zero;
  bool _isFirstMount = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (NeonTheme.reducedMotion(context)) {
        _isFirstMount = false;
        return;
      }
      _controller.forward(from: 0.0).then((_) {
        if (mounted) setState(() => _isFirstMount = false);
      });
    });
  }

  @override
  void didUpdateWidget(covariant _AnimatedItemCellWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.curve != widget.curve) {
      _curved.curve = widget.curve;
    }
    if (oldWidget.index != widget.index) {
      if (NeonTheme.reducedMotion(context)) {
        _fromOffset = Offset.zero;
        return;
      }
      final box = context.findRenderObject() as RenderBox?;
      final cellSize = (box != null && box.hasSize && box.size.width > 0)
          ? box.size.width
          : 64.0;
      _fromOffset = inventoryGridCellDelta(
        oldIndex: oldWidget.index,
        newIndex: widget.index,
        crossAxisCount: widget.crossAxisCount,
        cellSize: cellSize,
        spacing: widget.spacing,
      );
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
    if (NeonTheme.reducedMotion(context)) return widget.child;

    return AnimatedBuilder(
      animation: _curved,
      builder: (context, child) {
        Widget transformed = child!;
        if (_isFirstMount) {
          final scale = 0.8 + 0.2 * _curved.value;
          transformed = Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: _curved.value.clamp(0.0, 1.0),
              child: transformed,
            ),
          );
        } else if (_fromOffset != Offset.zero) {
          final offset = Offset.lerp(_fromOffset, Offset.zero, _curved.value)!;
          transformed = Transform.translate(offset: offset, child: transformed);
        }
        return RepaintBoundary(child: transformed);
      },
      child: widget.child,
    );
  }
}

/// Animated variant of [InventoryGrid] with pop-in scale for newly added items
/// and smooth sliding transitions on slot reorders.
class AnimatedInventoryGrid extends StatelessWidget {
  const AnimatedInventoryGrid({
    super.key,
    required this.snapshot,
    required this.itemBuilder,
    this.unlockedCapacity,
    this.emptyBuilder,
    this.lockedBuilder,
    this.crossAxisCount = 4,
    this.spacing = NeonTheme.s8,
    this.selectedSlotId,
    this.onSlotTap,
    this.onSlotLongPress,
    this.onReorder,
    this.shrinkWrap = false,
    this.physics,
    this.animationDuration = NeonTheme.motionDefault,
    this.animationCurve = NeonTheme.curveSurface,
  });

  final InventorySnapshot snapshot;
  final InventoryItemBuilder itemBuilder;
  final int? unlockedCapacity;
  final InventoryPlaceholderBuilder? emptyBuilder;
  final InventoryPlaceholderBuilder? lockedBuilder;
  final int crossAxisCount;
  final double spacing;
  final int? selectedSlotId;
  final ValueChanged<InventorySlot>? onSlotTap;
  final ValueChanged<InventorySlot>? onSlotLongPress;
  final void Function(int fromSlotId, int toSlotId)? onReorder;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Duration animationDuration;
  final Curve animationCurve;

  @override
  Widget build(BuildContext context) {
    return InventoryGrid(
      snapshot: snapshot,
      itemBuilder: itemBuilder,
      unlockedCapacity: unlockedCapacity,
      emptyBuilder: emptyBuilder,
      lockedBuilder: lockedBuilder,
      crossAxisCount: crossAxisCount,
      spacing: spacing,
      selectedSlotId: selectedSlotId,
      onSlotTap: onSlotTap,
      onSlotLongPress: onSlotLongPress,
      onReorder: onReorder,
      shrinkWrap: shrinkWrap,
      physics: physics,
      animate: true,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
    );
  }
}

class _DefaultPlaceholder extends StatelessWidget {
  const _DefaultPlaceholder({this.icon});

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NeonTheme.cardAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: icon == null
          ? null
          : Center(child: Icon(icon, color: NeonTheme.inkSoft, size: 20)),
    );
  }
}
