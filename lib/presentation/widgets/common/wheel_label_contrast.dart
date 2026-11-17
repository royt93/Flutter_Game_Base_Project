import 'package:flutter/material.dart';

import '../../../core/utils/theme_contrast_validator.dart';

Color wheelPaintedSectorColor(Color color, {double opacity = 1.0}) =>
    opacity == 1.0 ? color : color.withValues(alpha: opacity);

Color wheelLabelEffectiveBackground(Color sectorColor, Color backgroundColor) =>
    Color.alphaBlend(sectorColor, backgroundColor);

double wheelLabelContrastRatio({
  Color foreground = Colors.white,
  required Color sectorColor,
  required Color backgroundColor,
}) => contrastRatio(
  foreground,
  wheelLabelEffectiveBackground(sectorColor, backgroundColor),
);
