import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';

/// Dải tab pill 2-4 mục (vd chọn mode), 1 mục active được highlight bằng 1
/// pill nền trượt animated, các mục còn lại chỉ chữ thường.
class SegmentedTabBar extends StatelessWidget {
  const SegmentedTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  }) : assert(labels.length >= 2 && labels.length <= 4, 'SegmentedTabBar supports 2-4 segments');

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
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
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment(n == 1 ? 0 : -1 + 2 * selectedIndex / (n - 1), 0),
                child: Container(
                  width: segW,
                  height: 36,
                  decoration: BoxDecoration(
                    color: NeonTheme.cyan,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: NeonTheme.glow(
                      NeonTheme.cyan,
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
                      child: PressableScale(
                        onTap: () => onChanged(i),
                        child: SizedBox(
                          height: 36,
                          child: Center(
                            child: Text(
                              labels[i],
                              style: TextStyle(
                                fontFamily: NeonTheme.fontFamily,
                                fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                                color: active ? Colors.white : NeonTheme.inkSoft,
                                fontSize: 14,
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
