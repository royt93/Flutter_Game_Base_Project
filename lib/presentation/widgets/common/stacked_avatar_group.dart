import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'avatar_frame.dart';

class StackedAvatarItem {
  const StackedAvatarItem.widget(this.child, {this.semanticLabel, this.onTap})
    : imageUrl = null,
      placeholder = null;

  const StackedAvatarItem.url(
    this.imageUrl, {
    this.placeholder,
    this.semanticLabel,
    this.onTap,
  }) : child = null;

  final Widget? child;
  final String? imageUrl;
  final Widget? placeholder;
  final String? semanticLabel;
  final VoidCallback? onTap;

  Widget build(BuildContext context) {
    if (child case final child?) return child;
    final fallback =
        placeholder ?? Icon(Icons.person, color: NeonTheme.inkSoft);
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

class StackedAvatarGroup extends StatelessWidget {
  StackedAvatarGroup({
    super.key,
    required this.items,
    this.maxAvatars = 4,
    this.size = 36,
    this.overlap = 10,
    this.ringColor,
    this.overflowColor,
    this.semanticLabel,
    this.onOverflowTap,
  }) {
    if (maxAvatars <= 0) {
      throw ArgumentError.value(maxAvatars, 'maxAvatars', 'must be positive');
    }
    if (!size.isFinite || size <= 0) {
      throw ArgumentError.value(size, 'size', 'must be positive and finite');
    }
    if (!overlap.isFinite || overlap < 0 || overlap >= size) {
      throw ArgumentError.value(
        overlap,
        'overlap',
        'must be finite, >= 0 and < size',
      );
    }
  }

  final List<StackedAvatarItem> items;
  final int maxAvatars;
  final double size;
  final double overlap;
  final Color? ringColor;
  final Color? overflowColor;
  final String? semanticLabel;
  final VoidCallback? onOverflowTap;

  int get visibleAvatarCount =>
      items.length < maxAvatars ? items.length : maxAvatars;

  int get overflowCount => items.length - visibleAvatarCount;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final visibleCount = visibleAvatarCount;
    final hasOverflow = overflowCount > 0;
    final slotCount = visibleCount + (hasOverflow ? 1 : 0);
    final step = size - overlap;
    final width = size + (slotCount - 1) * step;

    return Semantics(
      container: true,
      label: semanticLabel,
      child: SizedBox(
        width: width,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (hasOverflow) _buildOverflow(visibleCount * step),
            for (var index = visibleCount - 1; index >= 0; index--)
              PositionedDirectional(
                start: index * step,
                width: size,
                height: size,
                child: AvatarFrame(
                  size: size,
                  ringWidth: 2,
                  color: ringColor ?? NeonTheme.card,
                  semanticLabel:
                      items[index].semanticLabel ?? 'Avatar ${index + 1}',
                  onTap: items[index].onTap,
                  child: items[index].build(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverflow(double start) {
    final label = '+$overflowCount';
    final badge = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: overflowColor ?? NeonTheme.purple,
        shape: BoxShape.circle,
        border: Border.all(color: ringColor ?? NeonTheme.card, width: 2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.34,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
    return PositionedDirectional(
      start: start,
      width: size,
      height: size,
      child: Semantics(
        button: onOverflowTap != null,
        label: '$overflowCount more avatars',
        excludeSemantics: true,
        onTap: onOverflowTap,
        child: onOverflowTap == null
            ? ExcludeSemantics(child: badge)
            : GestureDetector(
                key: const ValueKey('stackedAvatarOverflow'),
                behavior: HitTestBehavior.opaque,
                onTap: onOverflowTap,
                child: badge,
              ),
      ),
    );
  }
}
