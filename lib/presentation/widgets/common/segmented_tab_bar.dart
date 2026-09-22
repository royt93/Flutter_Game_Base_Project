import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';

/// A 2-4 item pill tab bar (e.g. mode selection) — the active item is
/// highlighted by an animated sliding background pill, the rest are plain
/// text.
class SegmentedTabBar extends StatelessWidget {
  const SegmentedTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.activeColor,
  }) : assert(
         labels.length >= 2 && labels.length <= 4,
         'SegmentedTabBar supports 2-4 segments',
       );

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Color of the sliding active-segment pill. Defaults to [NeonTheme.cyan]
  /// — nullable for the same reason as the rest of the kit's color params
  /// (a `NeonTheme` color field is no longer a compile-time constant, so it
  /// can't be a `const` constructor default value) (ENH-49).
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final activeColor = this.activeColor ?? NeonTheme.cyan;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: NeonTheme.cardAlt,
        borderRadius: BorderRadius.circular(20),
        boxShadow: NeonTheme.drop(y: 2, blur: 6),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segW = constraints.maxWidth / labels.length;
          final n = labels.length;
          return Stack(
            children: [
              AnimatedAlign(
                duration: NeonTheme.reducedMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                // ENH-38: AlignmentDirectional's x is "start" (physical
                // left in LTR, physical right in RTL) — resolved against
                // ambient Directionality automatically, so the sliding pill
                // follows the same reading direction as the Row of labels
                // below it instead of always sliding left-to-right.
                alignment: AlignmentDirectional(
                  n == 1 ? 0 : -1 + 2 * selectedIndex / (n - 1),
                  0,
                ),
                child: Container(
                  width: segW,
                  height: 36,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: NeonTheme.glow(
                      activeColor,
                      blur: 10,
                      spread: 0.5,
                      intensity: 0.5,
                    ),
                  ),
                ),
              ),
              Row(
                children: List.generate(n, (i) {
                  final active = i == selectedIndex;
                  return Expanded(
                    child: Semantics(
                      button: true,
                      selected: active,
                      label: labels[i],
                      // BUG-60: without this, a screen reader also reads
                      // the child Text's own implicit semantics node on
                      // top of this explicit `label`. `excludeSemantics`
                      // also discards the descendant GestureDetector's own
                      // tap-action semantics, so `onTap` is repeated here
                      // directly on this node.
                      excludeSemantics: true,
                      onTap: () => onChanged(i),
                      child: PressableScale(
                        onTap: () => onChanged(i),
                        child: SizedBox(
                          height: 36,
                          child: Center(
                            // ENH-40: at a large textScaleFactor or a very
                            // narrow segment, an unbounded Text here
                            // overflows past the fixed 36px-tall pill —
                            // FittedBox shrinks it to fit instead.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                labels[i],
                                style: TextStyle(
                                  fontFamily: NeonTheme.fontFamily,
                                  fontWeight: active
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                  color: active
                                      ? Colors.white
                                      : NeonTheme.inkSoft,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
