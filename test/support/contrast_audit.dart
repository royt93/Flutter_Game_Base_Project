import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/theme_contrast_validator.dart';

class RenderedTextContrastIssue {
  const RenderedTextContrastIssue({
    required this.text,
    required this.foreground,
    required this.background,
    required this.ratio,
    required this.threshold,
    required this.isLargeText,
  });

  final String text;
  final Color foreground;
  final Color background;
  final double ratio;
  final double threshold;
  final bool isLargeText;

  @override
  String toString() =>
      '"$text" (large=$isLargeText): ${ratio.toStringAsFixed(2)}:1 < ${threshold.toStringAsFixed(1)}:1 '
      '($foreground on $background)';
}

/// Audits contrast of rendered [Text] widgets within [scope].
///
/// Skips text sitting on gradients, images, or non-solid surfaces where flat
/// alpha-blending does not apply.
List<RenderedTextContrastIssue> auditRenderedTextContrast(
  WidgetTester tester,
  Finder scope, {
  double normalThreshold = 4.5,
  double largeThreshold = 3.0,
  Color? defaultBackground,
}) {
  final issues = <RenderedTextContrastIssue>[];
  final elements = tester.elementList(
    find.descendant(of: scope, matching: find.byType(Text)),
  );

  for (final element in elements) {
    final widget = element.widget as Text;
    final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
    final style = widget.style ?? DefaultTextStyle.of(element).style;
    final foreground = style.color;
    if (text.isEmpty || foreground == null) continue;

    var hasNonFlatBackground = false;
    final layers = <Color>[];
    element.visitAncestorElements((ancestor) {
      final ancestorWidget = ancestor.widget;
      Color? color;
      if (ancestorWidget is Material) {
        color = ancestorWidget.color;
      } else if (ancestorWidget is ColoredBox) {
        color = ancestorWidget.color;
      } else if (ancestorWidget is DecoratedBox) {
        final decoration = ancestorWidget.decoration;
        if (decoration is BoxDecoration) {
          if (decoration.gradient != null || decoration.image != null) {
            hasNonFlatBackground = true;
            return false;
          }
          color = decoration.color;
        } else if (decoration is ShapeDecoration) {
          if (decoration.gradient != null || decoration.image != null) {
            hasNonFlatBackground = true;
            return false;
          }
          color = decoration.color;
        }
      }
      if (color != null && color.a > 0.0) {
        layers.add(color);
        if (color.a >= 1.0) {
          return false;
        }
      }
      return true;
    });

    if (hasNonFlatBackground) continue;

    Color background;
    if (layers.isNotEmpty && layers.last.a >= 1.0) {
      background = layers.last;
      for (var i = layers.length - 2; i >= 0; i--) {
        background = Color.alphaBlend(layers[i], background);
      }
    } else if (defaultBackground != null && defaultBackground.a >= 1.0) {
      background = defaultBackground;
      for (var i = layers.length - 1; i >= 0; i--) {
        background = Color.alphaBlend(layers[i], background);
      }
    } else {
      continue;
    }

    final fontSize = style.fontSize ?? 14.0;
    final isBold =
        (style.fontWeight ?? FontWeight.normal).value >=
        FontWeight.w700.value;
    final isLarge = fontSize >= 18.0 || (fontSize >= 14.0 && isBold);
    final requiredThreshold = isLarge ? largeThreshold : normalThreshold;

    final ratio = contrastRatio(foreground, background);
    if (ratio < requiredThreshold) {
      issues.add(
        RenderedTextContrastIssue(
          text: text,
          foreground: foreground,
          background: background,
          ratio: ratio,
          threshold: requiredThreshold,
          isLargeText: isLarge,
        ),
      );
    }
  }
  return issues;
}
