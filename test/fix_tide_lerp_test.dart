import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/game/effects.dart';

/// Fix 1: TideLayer lerp mượt khi floodTop đổi đột ngột.
void main() {
  group('TideLayer.displayTop lerp (Fix 1)', () {
    TideLayer make(double Function() topFn) => TideLayer(
      floodTop: topFn,
      rows: 8,
      cols: 8,
      cellSize: 40,
      origin: Vector2.zero(),
    );

    test('khởi tạo: displayTop = floodTop sau update đầu tiên', () {
      final t = make(() => 6.0);
      t.update(0.016);
      expect(t.displayTopForTesting, closeTo(6.0, 0.01));
    });

    test('khi nước dâng (top giảm), displayTop lerp dần — không nhảy ngay', () {
      var target = 6.0;
      final t = make(() => target);
      t.update(0.016); // khởi tạo tại 6

      target = 4.0; // nước dâng thêm 2 hàng
      t.update(0.016); // 1 frame (~16ms)

      // Sau 1 frame ngắn, displayTop phải giảm nhưng CHƯA đạt target
      expect(t.displayTopForTesting, lessThan(6.0));
      expect(t.displayTopForTesting, greaterThan(4.0));
    });

    test('sau nhiều frame, displayTop hội tụ về target', () {
      var target = 8.0;
      final t = make(() => target);
      t.update(0.016);

      target = 2.0; // nước dâng mạnh
      // simulate ~3 giây = 180 frame
      for (int i = 0; i < 180; i++) {
        t.update(0.016);
      }

      expect(t.displayTopForTesting, closeTo(2.0, 0.1));
    });

    test('khi nước không đổi, displayTop giữ nguyên sau khởi tạo', () {
      final t = make(() => 5.0);
      t.update(0.016);
      t.update(0.5);
      t.update(1.0);
      expect(t.displayTopForTesting, closeTo(5.0, 0.01));
    });

    test(
      'khi nước rút (pushback), displayTop LERP lên — không snap (Fix: bidirectional)',
      () {
        var target = 3.0;
        final t = make(() => target);
        t.update(0.016); // init tại 3

        target = 7.0; // pushback: nước bị đẩy lùi 4 hàng
        t.update(0.016); // 1 frame: receedSpeed=3.0 → +3*0.016=0.048
        // Phải TĂNG (đang lerp) nhưng chưa tới target
        expect(t.displayTopForTesting, greaterThan(3.0));
        expect(t.displayTopForTesting, lessThan(7.0));
        // Sau nhiều frame (~1.5 giây): hội tụ về 7.0
        for (int i = 0; i < 100; i++) {
          t.update(0.016);
        }
        expect(t.displayTopForTesting, closeTo(7.0, 0.1));
      },
    );
  });
}
