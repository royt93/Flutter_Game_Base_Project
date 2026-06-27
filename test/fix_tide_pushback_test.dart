import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/game/effects.dart';

/// Fix 1 — Chứng minh root cause: kTidePushback nhảy đột ngột đã được smooth.
///
/// Root cause thật: khi người chơi xóa gem dưới nước, _floodTop nhảy lên đột ngột
/// (kTidePushback * N gems). Trước fix, code snap _displayTop = target ngay lập tức.
/// Sau fix: lerp cả 2 chiều — pushback/receed đi lên mượt ở receedSpeed = 3.0 rows/s.
void main() {
  group('TideLayer — pushback bidirectional lerp (Fix 1 root cause)', () {
    TideLayer make(double Function() topFn) => TideLayer(
      floodTop: topFn,
      rows: 8,
      cols: 8,
      cellSize: 50,
      origin: Vector2.zero(),
    );

    // Mô phỏng kTidePushback thực tế: 0.13 hàng/gem × 8 gem = 1.04 hàng nhảy
    test(
      'pushback 1 gem: displayTop KHÔNG snap ngay (receedSpeed = 3.0 rows/s)',
      () {
        var target = 4.0;
        final t = make(() => target);
        t.update(0.016); // init

        // 1 gem underwater cleared → floodTop += kTidePushback = 0.13
        target = 4.0 + kTidePushback;
        t.update(0.016); // 1 frame

        // receedSpeed * dt = 3.0 * 0.016 = 0.048 rows — CHƯA đến target (0.13)
        expect(
          t.displayTopForTesting,
          greaterThan(4.0),
          reason: 'displayTop phải bắt đầu lerp lên',
        );
        expect(
          t.displayTopForTesting,
          lessThan(4.0 + kTidePushback),
          reason: 'nhưng chưa tới target sau 1 frame — không snap',
        );
      },
    );

    test('pushback 8 gem hàng đầy (max): lerp mượt trong ~0.35 giây', () {
      var target = 3.0;
      final t = make(() => target);
      t.update(0.016);

      // 8 gem cleared → floodTop tăng 8 × 0.13 = 1.04 hàng
      const pushback = kTidePushback * 8; // = 1.04
      target = 3.0 + pushback;

      // Sau 1 frame: chưa tới target
      t.update(0.016);
      expect(
        t.displayTopForTesting,
        lessThan(target - 0.05),
        reason: '1 frame chưa đủ để lerp 1.04 rows',
      );

      // Sau ~10 frame (0.16s): tiến được ~ 0.48 rows (còn cách target ~0.56)
      for (int i = 0; i < 9; i++) {
        t.update(0.016);
      }
      expect(
        t.displayTopForTesting,
        greaterThan(3.0 + 0.3),
        reason: 'lerp đang tiến về target',
      );
      expect(
        t.displayTopForTesting,
        lessThan(target),
        reason: 'chưa tới target sau 10 frame',
      );

      // Sau ~25 frame (0.4s): đã hội tụ
      for (int i = 0; i < 15; i++) {
        t.update(0.016);
      }
      expect(
        t.displayTopForTesting,
        closeTo(target, 0.05),
        reason: 'hội tụ về target sau ~0.4 giây — animation mượt',
      );
    });

    test('nước dâng tự nhiên (0.06 rows/s) vẫn bám sát — không lag do lerp', () {
      const naturalRate = kTideBaseRate; // 0.06 rows/giây
      var target = 8.0;
      final t = make(() => target);
      t.update(0.016);

      // Mô phỏng tide rise tự nhiên trong 5 giây
      for (int i = 0; i < 300; i++) {
        target = (8.0 - naturalRate * (i + 1) * 0.016).clamp(0, 8);
        t.update(0.016);
      }
      // displayTop phải bám sát _floodTop trong vòng riseSpeed * 1frame = 0.08 rows
      expect(
        t.displayTopForTesting,
        closeTo(target, 0.1),
        reason: 'lerp theo kịp tide rate tự nhiên — không tạo visual lag',
      );
    });

    test('pushback rồi tiếp tục dâng: 2 chiều không lẫn lộn', () {
      var target = 5.0;
      final t = make(() => target);
      t.update(0.016);

      // Phase 1: pushback 2 hàng → cần ≥42 frame (2.0/0.048) để hội tụ
      target = 7.0;
      for (int i = 0; i < 55; i++) {
        t.update(0.016);
      }
      expect(
        t.displayTopForTesting,
        closeTo(7.0, 0.05),
        reason: '55 frame đủ lerp 2 hàng ở 3.0 rows/s',
      );

      // Phase 2: nước tiếp tục dâng → riseSpeed 5.0, (7-5)/0.08=25 frame
      target = 5.0;
      for (int i = 0; i < 35; i++) {
        t.update(0.016);
      }
      expect(
        t.displayTopForTesting,
        closeTo(5.0, 0.05),
        reason: 'sau pushback, nước dâng tiếp vẫn lerp đúng chiều',
      );
    });
  });
}
