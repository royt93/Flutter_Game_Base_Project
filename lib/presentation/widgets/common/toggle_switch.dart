import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';

/// A candy-styled on/off switch: pill track + a round thumb that slides
/// left/right, replacing Material's default `Switch`/`SwitchListTile` when
/// visual style needs to match the candy widget kit.
class CandyToggleSwitch extends StatelessWidget {
  const CandyToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Track color when on. Default: lime.
  final Color? activeColor;

  /// Describes what this switch controls (e.g. "Haptics", "Dark mode") —
  /// paired with the [Semantics.toggled] state so a screen reader announces
  /// e.g. "Haptics, on" instead of just "on".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final onC = enabled ? (activeColor ?? NeonTheme.lime) : NeonTheme.muted;
    final trackColor = value ? onC : NeonTheme.cardAlt;
    final borderColor = value
        ? Color.lerp(onC, Colors.black, 0.22)!
        : NeonTheme.muted;
    return Semantics(
      button: true,
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: PressableScale(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: NeonTheme.reducedMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
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
            duration: NeonTheme.reducedMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            // Chỉ thumb (vị trí) nảy — track (màu) giữ easeOut phẳng ở trên,
            // vì đổi màu không có khái niệm "overshoot" hợp lý.
            curve: Curves.easeOutBack,
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
