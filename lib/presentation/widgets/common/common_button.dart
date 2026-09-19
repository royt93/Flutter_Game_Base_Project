import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';
import '../stroke_text.dart';

/// Button style: 3 labeled pill variants + 1 icon-only round variant.
enum CommonButtonVariant { primary, secondary, danger, icon }

/// Shared button widget, with more variants than [NeonButton] (NeonButton
/// stays as-is, this doesn't replace it). `primary`/`secondary`/`danger` are
/// rounded pills with a label (secondary = outline/light background instead
/// of a solid gradient, danger = red tone); `icon` is a round icon-only
/// button (settings/close/...).
class CommonButton extends StatelessWidget {
  const CommonButton({
    super.key,
    this.label,
    this.icon,
    this.variant = CommonButtonVariant.primary,
    required this.onTap,
    this.color,
    this.width,
    this.semanticLabel,
    this.loading = false,
  }) : assert(
         variant == CommonButtonVariant.icon ? icon != null : label != null,
         'label required for text variants, icon required for icon variant',
       );

  final String? label;
  final IconData? icon;
  final CommonButtonVariant variant;
  final VoidCallback? onTap;

  /// Accent color. Default: cyan (primary/secondary), red (danger).
  final Color? color;

  /// Pill width (ignored for the icon variant, which uses [width] as its
  /// diameter instead, if given).
  final double? width;
  final String? semanticLabel;

  /// IDEA-53: shows a spinner in place of the label/icon and blocks taps
  /// (even though [onTap] is non-null) while an async action this button
  /// triggered — a purchase, a save, a cloud sync — is still in flight.
  /// Deliberately keeps the button's accent color/shadow (see [_enabled]
  /// vs [_tappable] below): visually this is "busy", not "unavailable",
  /// so it shouldn't look the same as a genuinely disabled button.
  final bool loading;

  /// Drives color/shadow — a loading button keeps its normal accent color,
  /// only a truly disabled one (`onTap == null`) goes muted.
  bool get _enabled => onTap != null;

  /// Drives Semantics/actual tap handling — `false` while [loading], even
  /// though [_enabled] (and thus the button's color) stays true.
  bool get _tappable => onTap != null && !loading;

  Color get _baseColor {
    if (color != null) return color!;
    return variant == CommonButtonVariant.danger
        ? NeonTheme.red
        : NeonTheme.cyan;
  }

  @override
  Widget build(BuildContext context) {
    final c = _enabled ? _baseColor : NeonTheme.muted;
    final baseLabel = semanticLabel ?? label ?? icon?.toString();
    return Semantics(
      button: true,
      enabled: _tappable,
      label: loading && baseLabel != null ? '$baseLabel, loading' : baseLabel,
      child: PressableScale(
        onTap: _tappable ? onTap : null,
        child: variant == CommonButtonVariant.icon
            ? _buildIcon(c)
            : _buildPill(c),
      ),
    );
  }

  Widget _buildPill(Color c) {
    final darker = Color.lerp(c, Colors.black, 0.22)!;
    final outlined = variant == CommonButtonVariant.secondary;
    return Container(
      width: width ?? 240,
      padding: const EdgeInsets.symmetric(
        vertical: NeonTheme.s8,
        horizontal: NeonTheme.s16,
      ),
      decoration: BoxDecoration(
        gradient: outlined
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(c, Colors.white, 0.18)!, c],
              ),
        color: outlined ? NeonTheme.cardAlt : null,
        borderRadius: BorderRadius.circular(22),
        border: outlined
            ? Border.all(color: c, width: 2.5)
            : Border(bottom: BorderSide(color: darker, width: 4)),
        boxShadow: _enabled ? NeonTheme.drop(y: 5, blur: 12) : null,
      ),
      // IDEA-53: the normal content stays laid out (just invisible) while
      // loading, rather than being swapped out — that's what keeps the
      // button's width/height exactly stable instead of shrinking to fit
      // a lone spinner.
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: loading ? 0 : 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: outlined ? c : Colors.white, size: 22),
                  const SizedBox(width: NeonTheme.s8),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: outlined
                        ? Text(
                            label!,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: c,
                            ),
                          )
                        : StrokeText(
                            label!,
                            fontSize: 19,
                            color: Colors.white,
                            stroke: darker,
                            strokeWidth: 3.5,
                            weight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (loading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(outlined ? c : Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIcon(Color c) {
    final darker = Color.lerp(c, Colors.black, 0.22)!;
    final d = width ?? 48.0;
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(c, Colors.white, 0.18)!, c],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: darker, width: 3),
        boxShadow: _enabled ? NeonTheme.drop(y: 4, blur: 10) : null,
      ),
      child: loading
          ? SizedBox(
              width: d * 0.46,
              height: d * 0.46,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Icon(icon, color: Colors.white, size: d * 0.46),
    );
  }
}
