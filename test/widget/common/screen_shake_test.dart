import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/screen_shake.dart';

void main() {
  group('ScreenShakeController (pure offsetAt)', () {
    test('offsetAt(zero) right after shake() is non-zero', () {
      final c = ScreenShakeController();
      c.shake(intensity: 12);
      expect(c.offsetAt(Duration.zero), isNot(Offset.zero));
    });

    test('offsetAt(decay) or beyond is exactly Offset.zero', () {
      final c = ScreenShakeController();
      const decay = Duration(milliseconds: 400);
      c.shake(intensity: 12, decay: decay);
      expect(c.offsetAt(decay), Offset.zero);
      expect(c.offsetAt(decay * 2), Offset.zero);
    });

    test('before any shake() call, offsetAt is always zero', () {
      final c = ScreenShakeController();
      expect(c.offsetAt(Duration.zero), Offset.zero);
    });

    test('calling shake() again restarts params instead of adding on top', () {
      final c = ScreenShakeController();
      c.shake(intensity: 5, decay: const Duration(milliseconds: 500));
      c.shake(intensity: 50, decay: const Duration(milliseconds: 100));

      // New decay (100ms) fully elapsed → zero, proving the new shorter
      // decay took over rather than the old 500ms one still running.
      expect(c.offsetAt(const Duration(milliseconds: 100)), Offset.zero);
      // New (larger) intensity is what's reflected at t=0.
      final off = c.offsetAt(Duration.zero);
      expect(off.dy.abs(), closeTo(50, 0.01));
    });
  });

  group('ScreenShake widget', () {
    testWidgets(
      'applies a nonzero Transform.translate offset shortly after shake()',
      (tester) async {
        final controller = ScreenShakeController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: ScreenShake(
                controller: controller,
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        );

        controller.shake(
          intensity: 12,
          decay: const Duration(milliseconds: 400),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        final transform = tester.widget<Transform>(find.byType(Transform));
        expect(
          transform.transform.getTranslation().x != 0 ||
              transform.transform.getTranslation().y != 0,
          isTrue,
        );
      },
    );

    testWidgets('returns to no visible offset after decay elapses', (
      tester,
    ) async {
      final controller = ScreenShakeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: ScreenShake(
              controller: controller,
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );

      controller.shake(intensity: 12, decay: const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final transform = tester.widget<Transform>(find.byType(Transform));
      final t = transform.transform.getTranslation();
      expect(t.x, 0);
      expect(t.y, 0);
    });

    testWidgets('reduced motion ignores the controller entirely', (
      tester,
    ) async {
      final controller = ScreenShakeController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: ScreenShake(
                controller: controller,
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        ),
      );

      controller.shake(
        intensity: 999,
        decay: const Duration(milliseconds: 400),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.byType(Transform), findsNothing);
    });
  });
}
