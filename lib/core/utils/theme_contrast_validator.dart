import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../neon_theme.dart';

/// What a [ContrastCheck]/[ContrastIssue] is checking — each kind has its
/// own natural threshold (WCAG normal text is stricter than a UI
/// component's border, which is stricter than "disabled state must at
/// least not be the exact same color as its background").
enum ContrastCheckKind { text, uiComponent, disabled, gemPalette }

/// One pair to check — pure data, no [NeonTheme] dependency, so a caller
/// (or a widget-fixture test, see this file's test) can validate arbitrary
/// colors, not just the live theme.
class ContrastCheck {
  const ContrastCheck({
    required this.token,
    required this.foreground,
    required this.background,
    required this.threshold,
    required this.kind,
  });

  final String token;
  final Color foreground;
  final Color background;
  final double threshold;
  final ContrastCheckKind kind;
}

/// A [ContrastCheck] that failed its [threshold] — [ratio] is either a
/// WCAG contrast ratio (text/uiComponent/disabled) or an RGB Euclidean
/// distance (gemPalette); both share the same "lower is worse" direction
/// so a single `< threshold` comparison produces every issue.
class ContrastIssue {
  const ContrastIssue({
    required this.token,
    required this.state,
    required this.ratio,
    required this.threshold,
    required this.kind,
  });

  final String token;
  final String state;
  final double ratio;
  final double threshold;
  final ContrastCheckKind kind;

  @override
  String toString() =>
      '$token ($state): ${ratio.toStringAsFixed(2)} < threshold '
      '${threshold.toStringAsFixed(2)} [$kind]';
}

/// Thresholds — defaults are WCAG 2.1 AA. Pass a stricter
/// [ThemeContrastConfig] (e.g. `normalTextThreshold: 7.0` for AAA) to
/// tighten the bar without touching validator code.
class ThemeContrastConfig {
  const ThemeContrastConfig({
    this.normalTextThreshold = 4.5,
    this.uiComponentThreshold = 3.0,
    this.disabledMinRatio = 1.2,
    this.gemPaletteMinDistance = 45,
  });

  /// WCAG AA normal text: 4.5:1 (AAA: 7.0).
  final double normalTextThreshold;

  /// WCAG AA large text / non-text UI component boundary: 3.0:1.
  final double uiComponentThreshold;

  /// Disabled controls are WCAG-exempt from contrast requirements — this
  /// only catches the degenerate "same color as its background, fully
  /// invisible" mistake, not a real AA/AAA bar.
  final double disabledMinRatio;

  /// Minimum acceptable Euclidean RGB distance between any 2 gem colors —
  /// a cheap, deterministic heuristic (not a real CVD simulation), same
  /// one already used ad hoc by `test/core/neon_theme_test.dart`.
  final double gemPaletteMinDistance;
}

/// WCAG relative luminance (https://www.w3.org/TR/WCAG21/#dfn-relative-luminance).
double relativeLuminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// WCAG contrast ratio between 2 colors, always >= 1.0 regardless of
/// argument order (https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio).
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a) + 0.05;
  final lb = relativeLuminance(b) + 0.05;
  return la > lb ? la / lb : lb / la;
}

double _rgbDistance(Color a, Color b) {
  final dr = (a.r - b.r) * 255;
  final dg = (a.g - b.g) * 255;
  final db = (a.b - b.b) * 255;
  return math.sqrt(dr * dr + dg * dg + db * db);
}

/// Runs a fixed list of [checks] (each already carrying its own colors and
/// threshold) and returns only the ones that failed, tagged with [state]
/// for the report. Pure — no [NeonTheme] dependency; this is what a
/// widget-fixture test or a caller with its own reskinned colors calls
/// directly instead of [validateNeonThemeContrast].
List<ContrastIssue> validateNeonThemeContrastPairs(
  List<ContrastCheck> checks, {
  String state = 'default',
}) {
  final issues = <ContrastIssue>[];
  for (final check in checks) {
    final ratio = contrastRatio(check.foreground, check.background);
    if (ratio < check.threshold) {
      issues.add(
        ContrastIssue(
          token: check.token,
          state: state,
          ratio: ratio,
          threshold: check.threshold,
          kind: check.kind,
        ),
      );
    }
  }
  return issues;
}

/// Validates the live [NeonTheme] across every state a consumer app can
/// actually put it in — light/dark (`NeonTheme.dark`) crossed with the
/// color-vision-deficiency-safe gem palette (`NeonTheme.colorBlindSafe`,
/// see `IDEA-38`) — without leaving it mutated: both flags are restored to
/// whatever they were before this call, in a `finally`, even if a caller
/// passes a [config] that throws (it can't, but the guarantee holds either
/// way).
///
/// Checks (all against the live theme's own tokens, see
/// `lib/core/neon_theme.dart`):
/// - `text`: `ink`/`inkSoft` on `card`/`cardAlt`, for light and dark.
/// - `disabled`: `muted` on `card`/`cardAlt`, for light and dark (WCAG
///   exempts disabled controls from a real contrast bar — see
///   [ThemeContrastConfig.disabledMinRatio]'s doc).
/// - `uiComponent`: `lockedBorder` on `lockedFill` — checked once, not
///   per-theme, because neither token has a separate dark variant (a
///   finding in itself, see this file's test).
/// - `gemPalette`: every pair in `NeonTheme.gemColors`, for the default
///   and the `colorBlindSafe` set.
List<ContrastIssue> validateNeonThemeContrast({
  ThemeContrastConfig config = const ThemeContrastConfig(),
}) {
  final issues = <ContrastIssue>[];
  final originalDark = NeonTheme.dark;
  final originalCvd = NeonTheme.colorBlindSafe;
  try {
    for (final isDark in [false, true]) {
      NeonTheme.dark = isDark;
      final state = isDark ? 'dark' : 'light';
      issues.addAll(
        validateNeonThemeContrastPairs([
          ContrastCheck(
            token: 'ink on card',
            foreground: NeonTheme.ink,
            background: NeonTheme.card,
            threshold: config.normalTextThreshold,
            kind: ContrastCheckKind.text,
          ),
          ContrastCheck(
            token: 'ink on cardAlt',
            foreground: NeonTheme.ink,
            background: NeonTheme.cardAlt,
            threshold: config.normalTextThreshold,
            kind: ContrastCheckKind.text,
          ),
          ContrastCheck(
            token: 'inkSoft on card',
            foreground: NeonTheme.inkSoft,
            background: NeonTheme.card,
            threshold: config.normalTextThreshold,
            kind: ContrastCheckKind.text,
          ),
          ContrastCheck(
            token: 'inkSoft on cardAlt',
            foreground: NeonTheme.inkSoft,
            background: NeonTheme.cardAlt,
            threshold: config.normalTextThreshold,
            kind: ContrastCheckKind.text,
          ),
          ContrastCheck(
            token: 'muted on card',
            foreground: NeonTheme.muted,
            background: NeonTheme.card,
            threshold: config.disabledMinRatio,
            kind: ContrastCheckKind.disabled,
          ),
          ContrastCheck(
            token: 'muted on cardAlt',
            foreground: NeonTheme.muted,
            background: NeonTheme.cardAlt,
            threshold: config.disabledMinRatio,
            kind: ContrastCheckKind.disabled,
          ),
        ], state: state),
      );
    }

    issues.addAll(
      validateNeonThemeContrastPairs([
        ContrastCheck(
          token: 'lockedBorder on lockedFill',
          foreground: NeonTheme.lockedBorder,
          background: NeonTheme.lockedFill,
          threshold: config.uiComponentThreshold,
          kind: ContrastCheckKind.uiComponent,
        ),
      ], state: 'constant'),
    );

    for (final cvdOn in [false, true]) {
      NeonTheme.colorBlindSafe = cvdOn;
      final state = cvdOn ? 'colorBlindSafe' : 'default';
      final colors = NeonTheme.gemColors;
      for (var i = 0; i < colors.length; i++) {
        for (var j = i + 1; j < colors.length; j++) {
          final distance = _rgbDistance(colors[i], colors[j]);
          if (distance < config.gemPaletteMinDistance) {
            issues.add(
              ContrastIssue(
                token: 'gemColors[$i] vs gemColors[$j]',
                state: state,
                ratio: distance,
                threshold: config.gemPaletteMinDistance,
                kind: ContrastCheckKind.gemPalette,
              ),
            );
          }
        }
      }
    }
  } finally {
    NeonTheme.dark = originalDark;
    NeonTheme.colorBlindSafe = originalCvd;
  }
  return issues;
}
