// FEAT-69: Golden Matrix Runner — a reusable *test-only* harness (lives
// under test/, not lib/, because it depends on `flutter_test`, a
// dev_dependency the published package must not ship) that pumps one
// widget through a bounded, deterministic sweep of
// theme/locale/direction/text-scale/reduced-motion combinations and fails
// the test on overflow/render error or a broken tap-target accessibility
// guideline, optionally comparing each combo against its own named golden
// file.
//
// Deliberately NOT a full cartesian product across every dimension (that
// would make runtime/repo size unbounded as more dimensions or widgets are
// added) — [defaultGoldenMatrix] is a baseline case plus a 1-axis-at-a-time
// sweep (dark, locale, RTL, 2 text scales, reduced motion), so total cases
// per widget stay fixed at 7 regardless of how many widgets use it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';

/// One point in the matrix — [name] becomes part of the golden file name,
/// so keep it filesystem-safe (already true for every case
/// [defaultGoldenMatrix] produces).
class GoldenMatrixCase {
  const GoldenMatrixCase({
    required this.name,
    this.dark = false,
    this.locale = const Locale('en'),
    this.textScale = 1.0,
    this.rtl = false,
    this.reducedMotion = false,
  });

  final String name;
  final bool dark;
  final Locale locale;
  final double textScale;
  final bool rtl;
  final bool reducedMotion;

  @override
  String toString() =>
      'GoldenMatrixCase($name: dark=$dark, locale=$locale, '
      'textScale=$textScale, rtl=$rtl, reducedMotion=$reducedMotion)';
}

/// Baseline (light/en/LTR/scale 1.0/motion on) plus one variation per axis
/// — proves each dimension independently instead of every dimension's
/// combination with every other (bounded runtime, see file doc comment).
List<GoldenMatrixCase> defaultGoldenMatrix({
  List<double> textScales = const [1.3, 2.0],
}) {
  return [
    const GoldenMatrixCase(name: 'baseline'),
    const GoldenMatrixCase(name: 'dark', dark: true),
    const GoldenMatrixCase(name: 'locale-vi', locale: Locale('vi')),
    const GoldenMatrixCase(name: 'rtl', rtl: true),
    for (final scale in textScales)
      GoldenMatrixCase(
        name: 'textScale-${scale.toStringAsFixed(1)}',
        textScale: scale,
      ),
    const GoldenMatrixCase(name: 'reducedMotion', reducedMotion: true),
  ];
}

const _matrixTargetKey = Key('golden_matrix_target');

/// Pumps [builder] once per case in [matrix] (default:
/// [defaultGoldenMatrix]), wrapped in that case's
/// theme/locale/direction/text-scale/reduced-motion, and for each case:
/// 1. Fails via a normal [expect] if [WidgetTester.takeException] is
///    non-null (an overflow/render error the case's environment provoked).
/// 2. Fails via [meetsGuideline] for every guideline in [guidelines] —
///    defaults to Flutter's own [androidTapTargetGuideline] and
///    [labeledTapTargetGuideline] (reused, not reimplemented: this is
///    exactly "fail on a semantics regression" for tappable elements).
/// 3. When [goldenBaseName] is given, compares against
///    `<goldenBaseName>_<case.name>.png` via [matchesGoldenFile] — a
///    filename that is entirely determined by [matrix], so a diff always
///    tells you exactly which axis changed.
///
/// [NeonTheme.dark] is restored to whatever it was before this call, in a
/// `finally`, even if a case or guideline check throws.
Future<void> runGoldenMatrix(
  WidgetTester tester,
  Widget Function(BuildContext context) builder, {
  String? goldenBaseName,
  List<GoldenMatrixCase>? matrix,
  List<AccessibilityGuideline> guidelines = const [
    androidTapTargetGuideline,
    labeledTapTargetGuideline,
  ],
}) async {
  final cases = matrix ?? defaultGoldenMatrix();
  final originalDark = NeonTheme.dark;
  try {
    for (final c in cases) {
      NeonTheme.dark = c.dark;
      await tester.pumpWidget(
        MaterialApp(
          // Deliberately NOT `locale:`/`supportedLocales:` — MaterialApp's
          // own locale resolution warns loudly (a caught "exception") for
          // any locale its `DefaultMaterialLocalizations` doesn't ship
          // (only 'en', since this package doesn't depend on
          // `flutter_localizations`). The widget kit's own translations
          // (`AppTranslations`/GetX `.tr`) don't go through
          // `MaterialLocalizations` at all, so `Localizations.override`
          // below is enough to thread `c.locale` to `Localizations.of`
          // without triggering that unrelated warning.
          builder: (context, child) => Localizations.override(
            context: context,
            locale: c.locale,
            child: Directionality(
              textDirection: c.rtl ? TextDirection.rtl : TextDirection.ltr,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(c.textScale),
                  disableAnimations: c.reducedMotion,
                ),
                child: child!,
              ),
            ),
          ),
          home: Material(
            child: Center(
              child: KeyedSubtree(
                key: _matrixTargetKey,
                child: Builder(builder: builder),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'Case "${c.name}" threw during render — $c',
      );

      if (guidelines.isNotEmpty) {
        final handle = tester.ensureSemantics();
        try {
          for (final guideline in guidelines) {
            await expectLater(
              tester,
              meetsGuideline(guideline),
              reason: 'Case "${c.name}" failed ${guideline.description} — $c',
            );
          }
        } finally {
          handle.dispose();
        }
      }

      if (goldenBaseName != null) {
        await expectLater(
          find.byKey(_matrixTargetKey),
          matchesGoldenFile('goldens/${goldenBaseName}_${c.name}.png'),
        );
      }
    }
  } finally {
    NeonTheme.dark = originalDark;
  }
}
