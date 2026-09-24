import 'dart:math' as math;

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

    group('IDEA-60: direction bias', () {
      test(
        'không truyền direction -> offsetAt giữ nguyên công thức cũ y hệt '
        '(dx=sin trên trục x, dy=cos trên trục y)',
        () {
          final c = ScreenShakeController();
          const decay = Duration(milliseconds: 400);
          c.shake(intensity: 12, frequency: 30, decay: decay);

          for (final ms in [0, 10, 50, 123, 250]) {
            final elapsed = Duration(milliseconds: ms);
            final off = c.offsetAt(elapsed);

            final t = elapsed.inMicroseconds / 1e6;
            final decaySeconds = decay.inMicroseconds / 1e6;
            final envelope = math.exp(-4 * t / decaySeconds);
            final expectedDx =
                12 * envelope * math.sin(2 * math.pi * 30 * t);
            final expectedDy =
                12 * envelope * math.cos(2 * math.pi * 30 * 1.3 * t);

            expect(off.dx, closeTo(expectedDx, 1e-9));
            expect(off.dy, closeTo(expectedDy, 1e-9));
          }
        },
      );

      test(
        'có direction -> biên độ rung chiếu lên direction lớn hơn hẳn '
        'chiếu lên trục vuông góc, trung bình trên nhiều mốc t',
        () {
          final c = ScreenShakeController();
          const decay = Duration(milliseconds: 400);
          const direction = Offset(1, 0); // hướng thẳng sang phải
          c.shake(intensity: 12, frequency: 30, decay: decay, direction: direction);

          var alongSum = 0.0;
          var perpSum = 0.0;
          for (var ms = 0; ms < 400; ms += 5) {
            final off = c.offsetAt(Duration(milliseconds: ms));
            // direction (1,0) đơn vị -> chiếu lên trục x là "along", trục
            // y là "perpendicular".
            alongSum += off.dx.abs();
            perpSum += off.dy.abs();
          }

          expect(alongSum, greaterThan(perpSum));
        },
      );

      test(
        'direction không phải unit vector vẫn hoạt động đúng (tự chuẩn hoá)',
        () {
          final c = ScreenShakeController();
          c.shake(
            intensity: 12,
            decay: const Duration(milliseconds: 400),
            direction: const Offset(0, 100), // hướng xuống, độ dài 100
          );

          final off = c.offsetAt(const Duration(milliseconds: 10));
          // Hướng (0,100) chuẩn hoá thành (0,1) -> "along" nằm hoàn toàn
          // trên trục y, "perpendicular" trên trục x.
          expect(off.dx.abs(), lessThan(off.dy.abs()));
        },
      );

      test('direction = Offset.zero coi như không có hướng (tránh chia 0)', () {
        final c = ScreenShakeController();
        const decay = Duration(milliseconds: 400);
        c.shake(intensity: 12, frequency: 30, decay: decay, direction: Offset.zero);

        final off = c.offsetAt(const Duration(milliseconds: 10));
        expect(off.dx.isFinite, isTrue);
        expect(off.dy.isFinite, isTrue);

        // Phải khớp đúng công thức KHÔNG direction (fallback an toàn).
        final t = 0.01;
        final decaySeconds = decay.inMicroseconds / 1e6;
        final envelope = math.exp(-4 * t / decaySeconds);
        final expectedDx = 12 * envelope * math.sin(2 * math.pi * 30 * t);
        expect(off.dx, closeTo(expectedDx, 1e-9));
      });

      test('shake() gọi lại KHÔNG direction xoá direction cũ (không dính lại)', () {
        final c = ScreenShakeController();
        const decay = Duration(milliseconds: 400);
        c.shake(intensity: 12, decay: decay, direction: const Offset(1, 0));
        c.shake(intensity: 12, decay: decay); // gọi lại, không truyền direction

        final off = c.offsetAt(const Duration(milliseconds: 10));
        final t = 0.01;
        final decaySeconds = decay.inMicroseconds / 1e6;
        final envelope = math.exp(-4 * t / decaySeconds);
        final expectedDx = 12 * envelope * math.sin(2 * math.pi * 30 * t);
        expect(off.dx, closeTo(expectedDx, 1e-9));
      });
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
