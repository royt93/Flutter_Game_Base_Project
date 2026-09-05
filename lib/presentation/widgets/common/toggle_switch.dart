import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';

/// Switch bật/tắt kiểu kẹo: track pill + thumb tròn trượt trái/phải, thay
/// cho `Switch`/`SwitchListTile` mặc định của Material khi cần đồng bộ style
/// với bộ widget candy.
class CandyToggleSwitch extends StatelessWidget {
  const CandyToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Màu track khi bật. Mặc định: lime.
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final onC = enabled ? (activeColor ?? NeonTheme.lime) : NeonTheme.muted;
    final trackColor = value ? onC : NeonTheme.cardAlt;
    final borderColor = value ? Color.lerp(onC, Colors.black, 0.22)! : NeonTheme.muted;
    return Semantics(
      button: true,
      toggled: value,
      enabled: enabled,
      child: PressableScale(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 52,
          height: 30,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: enabled ? NeonTheme.drop(y: 2, blur: 4) : null,
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: NeonTheme.drop(y: 1, blur: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
