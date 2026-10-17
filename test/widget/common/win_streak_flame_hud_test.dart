import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/win_streak_flame_hud.dart';

Widget _wrap(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

double _popScale(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('winStreakBadgePopScale')))
    .transform
    .entry(0, 0);

double _flameScale(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('winStreakFlameScale')))
    .transform
    .entry(0, 0);

void main() {
  group('winStreakFlameColor', () {
    test('maps streak counts to the 3 color tiers', () {
      expect(winStreakFlameColor(0), NeonTheme.muted);
      expect(winStreakFlameColor(1), NeonTheme.cyan);
      expect(winStreakFlameColor(2), NeonTheme.gold);
      expect(winStreakFlameColor(4), NeonTheme.gold);
      expect(winStreakFlameColor(5), NeonTheme.orange);
      expect(winStreakFlameColor(100), NeonTheme.orange);
    });
  });

  group('WinStreakFlameHud validation', () {
    test('rejects negative streakCount and invalid dimensions', () {
      expect(() => WinStreakFlameHud(streakCount: -1), throwsArgumentError);
      expect(
        () => WinStreakFlameHud(streakCount: 3, height: 0),
        throwsArgumentError,
      );
      expect(
        () => WinStreakFlameHud(streakCount: 3, width: double.infinity),
        throwsArgumentError,
      );
    });
  });

  group('WinStreakFlameHud rendering & animation', () {
    testWidgets(
      'renders streak count, flame icon, and caller multiplier label',
      (tester) async {
        await tester.pumpWidget(
          _wrap(WinStreakFlameHud(streakCount: 3, multiplierLabel: 'x1.5')),
        );

        expect(find.text('3 wins'), findsOneWidget);
        expect(find.text('x1.5'), findsOneWidget);
        expect(
          find.byIcon(Icons.local_fire_department_rounded),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('increasing streak plays pop animation then settles', (
      tester,
    ) async {
      Widget build(int count) => _wrap(WinStreakFlameHud(streakCount: count));

      await tester.pumpWidget(build(1));
      expect(_popScale(tester), 1.0);

      await tester.pumpWidget(build(2));
      await tester.pump(const Duration(milliseconds: 170));
      expect(_popScale(tester), greaterThan(1.05));

      await tester.pump(const Duration(milliseconds: 300));
      expect(_popScale(tester), closeTo(1.0, 0.001));
    });

    testWidgets('decreasing or resetting streak never plays celebration pop', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(WinStreakFlameHud(streakCount: 6)));
      await tester.pumpWidget(_wrap(WinStreakFlameHud(streakCount: 2)));
      await tester.pump(const Duration(milliseconds: 170));
      expect(_popScale(tester), 1.0);

      await tester.pumpWidget(_wrap(WinStreakFlameHud(streakCount: 0)));
      await tester.pump(const Duration(milliseconds: 170));
      expect(_popScale(tester), 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('zero streak is visually neutral and has no pulse', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(WinStreakFlameHud(streakCount: 0)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('0 wins'), findsOneWidget);
      final icon = tester.widget<Icon>(
        find.byKey(const ValueKey('winStreakFlameIcon')),
      );
      expect(icon.color, NeonTheme.muted);
      expect(_flameScale(tester), 1.0);
      expect(_popScale(tester), 1.0);
    });

    testWidgets('Reduced Motion keeps flame static on count increase', (
      tester,
    ) async {
      Widget build(int count) =>
          _wrap(WinStreakFlameHud(streakCount: count), reduced: true);

      await tester.pumpWidget(build(1));
      await tester.pumpWidget(build(3));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_popScale(tester), 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('onInfoTap called when HUD is tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(WinStreakFlameHud(streakCount: 4, onInfoTap: () => taps++)),
      );

      await tester.tap(find.byKey(const ValueKey('winStreakFlameTapTarget')));
      expect(taps, 1);
    });

    testWidgets('app interruption preserves streak state and ticker safely', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(WinStreakFlameHud(streakCount: 3)));
      await tester.pump(const Duration(milliseconds: 250));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('3 wins'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantics announce streak and multiplier', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(WinStreakFlameHud(streakCount: 5, multiplierLabel: 'x3')),
      );

      final node = tester.getSemantics(
        find.byKey(const ValueKey('winStreakFlameTapTarget')),
      );
      expect(node.label, 'Win streak 5, reward multiplier x3');
      expect(node.value, 'x3');
      handle.dispose();
    });
  });
}
