import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/data/levels.dart';

/// Fix 1 (root cause) — chứng minh smoothTideTop dập được "giật" do pushback.
///
/// kTidePushback = 0.13 hàng/gem. Clear 8 gem dưới nước → _floodTop nhảy +1.04
/// hàng trong 1 frame. Trước fix: TideLayer snap ngay (và lerp dùng dt scaled khi
/// slow-mo → lệch nhịp). Sau fix: smoothTideTop lerp bằng dt thật ở engine.
void main() {
  group('smoothTideTop dập pushback đột ngột (Fix 1 root cause)', () {
    test('pushback 1 gem (+0.13): không nhảy ngay, lerp dần', () {
      const base = 4.0;
      final target = base + kTidePushback; // 4.13
      final next = smoothTideTop(base, target, 0.016);
      // 1 frame: 4.0 + 3.0*0.016 = 4.048 < 4.13 → chưa tới
      expect(next, greaterThan(base));
      expect(
        next,
        lessThan(target),
        reason: 'pushback nhỏ vẫn lerp, không snap trong 1 frame',
      );
    });

    test('pushback 8 gem (+1.04): hội tụ mượt sau ~0.35s', () {
      const base = 3.0;
      const target = 3.0 + kTidePushback * 8; // 4.04
      double cur = base;
      // 1 frame: chưa tới
      cur = smoothTideTop(cur, target, 0.016);
      expect(
        cur,
        lessThan(target - 0.5),
        reason: '1 frame không thể lerp hết 1.04 hàng',
      );
      // ~0.4s = 25 frame: hội tụ (1.04/3.0 = 0.347s)
      for (int i = 0; i < 25; i++) {
        cur = smoothTideTop(cur, target, 0.016);
      }
      expect(
        cur,
        closeTo(target, 0.05),
        reason: 'hội tụ về target sau ~0.4s — mượt, không giật',
      );
    });

    test('nước dâng tự nhiên (0.06 hàng/s): bám sát tuyệt đối — không lag', () {
      double cur = 8.0;
      double flood = 8.0;
      const rate = kTideBaseRate; // 0.06 hàng/s
      for (int i = 0; i < 300; i++) {
        flood -= rate * 0.016; // _floodTop dâng tự nhiên
        cur = smoothTideTop(cur, flood, 0.016);
      }
      expect(
        cur,
        equals(flood),
        reason: 'dâng tự nhiên → smoothTideTop trả target ngay → 0 độ trễ',
      );
    });

    test(
      'dt thật không dính slow-mo: cùng dt cho cùng kết quả (deterministic)',
      () {
        // Chứng minh hàm pure: không phụ thuộc state ngoài → engine gọi dt thật an toàn
        final a = smoothTideTop(3.0, 5.0, 0.016);
        final b = smoothTideTop(3.0, 5.0, 0.016);
        expect(a, equals(b));
      },
    );
  });
}
