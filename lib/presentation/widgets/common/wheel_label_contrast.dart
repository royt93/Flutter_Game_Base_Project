import 'package:flutter/material.dart';

import '../../../core/utils/theme_contrast_validator.dart';

Color wheelPaintedSectorColor(Color color, {double opacity = 1.0}) =>
    opacity == 1.0 ? color : color.withValues(alpha: opacity);

Color wheelLabelEffectiveBackground(Color sectorColor, Color backgroundColor) =>
    Color.alphaBlend(sectorColor, backgroundColor);

Color wheelLabelForeground({
  required Color sectorColor,
  required Color backgroundColor,
}) {
  final background = wheelLabelEffectiveBackground(
    sectorColor,
    backgroundColor,
  );
  final whiteRatio = contrastRatio(Colors.white, background);
  final blackRatio = contrastRatio(Colors.black, background);
  return whiteRatio >= blackRatio ? Colors.white : Colors.black;
}

double wheelLabelContrastRatio({
  Color foreground = Colors.white,
  required Color sectorColor,
  required Color backgroundColor,
}) => contrastRatio(
  foreground,
  wheelLabelEffectiveBackground(sectorColor, backgroundColor),
);
