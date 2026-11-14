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

/// Audits rendered text spans over flat-color surfaces only.
///
/// Skips gradients, images, disabled text, and backgrounds it cannot resolve.
List<RenderedTextContrastIssue> auditRenderedTextContrast(
  WidgetTester tester,
  Finder scope, {
  double normalThreshold = 4.5,
  double largeThreshold = 3.0,
  Color? defaultBackground,
}) {
  final issues = <RenderedTextContrastIssue>[];
  final elements = tester.elementList(
    find.descendant(of: scope, matching: find.byType(RichText)),
  );

  for (final element in elements) {
    if (_isInsideIcon(element)) continue;
    final widget = element.widget as RichText;
    final baseStyle = DefaultTextStyle.of(element).style.merge(widget.text.style);
    final spans = <(String, TextStyle)>[];
    _collectTextSpans(widget.text, baseStyle, spans);
    final background = _flatBackground(element, defaultBackground);
    if (background == null) continue;

    for (final (text, style) in spans) {
      final foreground = style.color;
      if (text.trim().isEmpty || foreground == null) continue;
      if (style.fontSize != null && style.fontSize! <= 0.0) continue;

      final fontSize = style.fontSize ?? 14.0;
      final isBold =
          (style.fontWeight ?? FontWeight.normal).value >= FontWeight.w700.value;
      final isLarge = fontSize >= 24.0 || (fontSize >= 18.67 && isBold);
      final threshold = isLarge ? largeThreshold : normalThreshold;
      final ratio = contrastRatio(foreground, background);
      if (ratio < threshold) {
        issues.add(
          RenderedTextContrastIssue(
            text: text,
            foreground: foreground,
            background: background,
            ratio: ratio,
            threshold: threshold,
            isLargeText: isLarge,
          ),
        );
      }
    }
  }
  return issues;
}

void _collectTextSpans(
  InlineSpan span,
  TextStyle inherited,
  List<(String, TextStyle)> result,
) {
  final style = inherited.merge(span.style);
  if (span is TextSpan) {
    if (span.text != null && span.text!.isNotEmpty) {
      result.add((span.text!, style));
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      _collectTextSpans(child, style, result);
    }
  }
}

bool _isInsideIcon(Element element) {
  var insideIcon = false;
  element.visitAncestorElements((ancestor) {
    if (ancestor.widget is Icon) {
      insideIcon = true;
      return false;
    }
    return true;
  });
  return insideIcon;
}

Color? _flatBackground(Element element, Color? defaultBackground) {
  final layers = <Color>[];
  var hasNonFlatBackground = false;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    Color? color;
    if (widget is Material) {
      color = widget.color ?? Theme.of(ancestor).canvasColor;
    } else if (widget is ColoredBox) {
      color = widget.color;
    } else if (widget is DecoratedBox) {
      final decoration = widget.decoration;
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
      if (color.a >= 1.0) return false;
    }
    return true;
  });

  if (hasNonFlatBackground) return null;

  Color background;
  if (layers.isNotEmpty && layers.last.a >= 1.0) {
    background = layers.last;
    for (var i = layers.length - 2; i >= 0; i--) {
      background = Color.alphaBlend(layers[i], background);
    }
    return background;
  }
  if (defaultBackground == null || defaultBackground.a < 1.0) return null;
  background = defaultBackground;
  for (var i = layers.length - 1; i >= 0; i--) {
    background = Color.alphaBlend(layers[i], background);
  }
  return background;
}
