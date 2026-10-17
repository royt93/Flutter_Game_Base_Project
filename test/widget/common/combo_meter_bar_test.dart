import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/combo_meter_bar.dart';

Widget _wrap(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 300, child: child)),
    ),
  ),
);

double _popScale(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('comboMeterPopScale')))
    .transform
    .entry(0, 0);

void main() {
  group('comboTierColor', () {
    test('ladder is distinct for 1x..5x and clamps above 5', () {
      final colors = [for (var m = 1; m <= 5; m++) comboTierColor(m)];
      expect(colors.toSet().length, 5);
      expect(comboTierColor(1), NeonTheme.cyan);
      expect(comboTierColor(6), comboTierColor(5));
      expect(comboTierColor(99), NeonTheme.magenta);
      expect(comboTierColor(0), NeonTheme.cyan);
    });
  });

  group('ComboMeterBar validation', () {
    test('rejects multiplier < 1', () {
      expect(
        () => ComboMeterBar(multiplier: 0, progress: 0.5),
        throwsArgumentError,
      );
    });

    test('rejects progress outside 0..1 or non-finite', () {
      expect(
        () => ComboMeterBar(multiplier: 1, progress: -0.1),
        throwsArgumentError,
      );
      expect(
        () => ComboMeterBar(multiplier: 1, progress: 1.1),
        throwsArgumentError,
      );
      expect(
        () => ComboMeterBar(multiplier: 1, progress: double.nan),
        throwsArgumentError,
      );
    });

    test('rejects non-positive height or width', () {
      expect(
        () => ComboMeterBar(multiplier: 1, progress: 0.5, height: 0),
        throwsArgumentError,
      );
      expect(
        () => ComboMeterBar(multiplier: 1, progress: 0.5, width: -10),
        throwsArgumentError,
      );
    });
  });

  group('ComboMeterBar rendering', () {
    testWidgets('shows multiplier label and fills proportional to progress', (
      tester,
    ) async {
      Widget build(double p) =>
          _wrap(ComboMeterBar(multiplier: 3, progress: p));

      await tester.pumpWidget(build(0.5));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('x3'), findsOneWidget);

      final fill = find.descendant(
        of: find.byType(ClipRRect),
        matching: find.byType(AnimatedContainer),
      );
      final half = tester.getSize(fill).width;
      expect(half, greaterThan(0));

      await tester.pumpWidget(build(1.0));
      await tester.pump(const Duration(milliseconds: 400));
      final full = tester.getSize(fill).width;
      expect(full, greaterThan(half * 1.8));

      await tester.pumpWidget(build(0.0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getSize(fill).width, 0.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('showMultiplierBadge false hides the label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ComboMeterBar(
            multiplier: 2,
            progress: 0.4,
            showMultiplierBadge: false,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('comboMultiplierLabel')), findsNothing);
    });
  });

  group('ComboMeterBar tier-up pop', () {
    testWidgets('pops on multiplier increase then settles', (tester) async {
      Widget build(int m) => _wrap(ComboMeterBar(multiplier: m, progress: 0.5));

      await tester.pumpWidget(build(1));
      expect(_popScale(tester), 1.0);

      await tester.pumpWidget(build(2));
      await tester.pump(const Duration(milliseconds: 190));
      expect(_popScale(tester), greaterThan(1.05));

      await tester.pump(const Duration(milliseconds: 400));
      expect(_popScale(tester), closeTo(1.0, 0.001));
      expect(tester.takeException(), isNull);
    });

    testWidgets('no pop on mount, same tier, or multiplier decrease', (
      tester,
    ) async {
      Widget build(int m, double p) =>
          _wrap(ComboMeterBar(multiplier: m, progress: p));

      await tester.pumpWidget(build(4, 0.5));
      await tester.pump(const Duration(milliseconds: 190));
      expect(_popScale(tester), 1.0);

      await tester.pumpWidget(build(4, 0.9));
      await tester.pump(const Duration(milliseconds: 190));
      expect(_popScale(tester), 1.0);

      await tester.pumpWidget(build(2, 0.1));
      await tester.pump(const Duration(milliseconds: 190));
      expect(_popScale(tester), 1.0);
    });

    testWidgets('Reduced Motion skips the pop', (tester) async {
      Widget build(int m) =>
          _wrap(ComboMeterBar(multiplier: m, progress: 0.5), reduced: true);

      await tester.pumpWidget(build(1));
      await tester.pumpWidget(build(3));
      await tester.pump(const Duration(milliseconds: 190));
      expect(_popScale(tester), 1.0);
    });

    testWidgets('disposing mid-pop does not throw', (tester) async {
      await tester.pumpWidget(
        _wrap(ComboMeterBar(multiplier: 1, progress: 0.5)),
      );
      await tester.pumpWidget(
        _wrap(ComboMeterBar(multiplier: 2, progress: 0.5)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('semantics announce multiplier and percent, overridable', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(ComboMeterBar(multiplier: 3, progress: 0.42)),
    );
    var node = tester.getSemantics(find.byType(ComboMeterBar));
    expect(node.label, 'Combo x3, 42 percent');
    expect(node.value, '42%');

    await tester.pumpWidget(
      _wrap(
        ComboMeterBar(
          multiplier: 3,
          progress: 0.42,
          semanticLabel: 'Combo chain',
        ),
      ),
    );
    node = tester.getSemantics(find.byType(ComboMeterBar));
    expect(node.label, 'Combo chain');
    handle.dispose();
  });
}
