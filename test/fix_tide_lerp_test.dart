import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/data/levels.dart';

/// Fix 1 — smoothTideTop: làm mượt mặt nước hiển thị bằng dt THẬT (engine-side).
///
/// Root cause cũ: lerp nằm trong TideLayer.update() nhận dt đã nhân _timeScale
/// (slow-mo) → lệch nhịp với _floodTop (dùng dt thật) → giật. Fix: tách hàm pure,
/// engine gọi với dt thật mỗi frame.
void main() {
  group('smoothTideTop — nước dâng (target <= current) (Fix 1)', () {
    test(
      'nước dâng: bám sát target ngay (floodTop tự nó đã mượt từng frame)',
      () {
        // target nhỏ hơn current = nước dâng lên (top giảm)
        expect(
          smoothTideTop(6.0, 5.94, 0.016),
          5.94,
          reason: 'dâng tự nhiên → trả target ngay, không trễ',
        );
      },
    );

    test('nước dâng mạnh: vẫn bám target (không giới hạn chiều dâng)', () {
      expect(smoothTideTop(8.0, 2.0, 0.016), 2.0);
    });

    test('target == current: giữ nguyên', () {
      expect(smoothTideTop(5.0, 5.0, 0.016), 5.0);
    });
  });

  group('smoothTideTop — pushback (target > current) (Fix 1)', () {
    test('pushback: lerp lên ở kTideVisualReceedSpeed, KHÔNG snap', () {
      // current=3, target=5 (nước bị đẩy lùi 2 hàng)
      final next = smoothTideTop(3.0, 5.0, 0.016);
      expect(next, greaterThan(3.0), reason: 'phải tiến lên');
      expect(next, lessThan(5.0), reason: 'nhưng chưa tới target — không snap');
      expect(
        next,
        closeTo(3.0 + kTideVisualReceedSpeed * 0.016, 1e-9),
        reason: 'đúng công thức current + speed*dt',
      );
    });

    test('pushback nhỏ hơn 1 bước: clamp không vượt target', () {
      // dt lớn để speed*dt > khoảng cách → phải clamp về target
      final next = smoothTideTop(4.9, 5.0, 1.0); // 4.9 + 3.0 = 7.9 > 5.0
      expect(next, 5.0, reason: 'không được vượt quá target');
    });

    test('pushback hội tụ về target sau nhiều frame (~0.67s cho 2 hàng)', () {
      double cur = 3.0;
      const target = 5.0;
      for (int i = 0; i < 60; i++) {
        cur = smoothTideTop(cur, target, 0.016);
      }
      expect(
        cur,
        closeTo(5.0, 0.05),
        reason: '60 frame (0.96s) đủ lerp 2 hàng ở 3.0 hàng/s',
      );
    });
  });

  group('smoothTideTop — kịch bản 2 chiều liên tiếp (Fix 1)', () {
    test('pushback rồi tiếp tục dâng: không lẫn lộn chiều', () {
      double cur = 5.0;
      // Phase 1: pushback lên 7.0
      for (int i = 0; i < 60; i++) {
        cur = smoothTideTop(cur, 7.0, 0.016);
      }
      expect(cur, closeTo(7.0, 0.05));
      // Phase 2: nước dâng lại xuống 5.0 → bám ngay
      cur = smoothTideTop(cur, 5.0, 0.016);
      expect(cur, 5.0, reason: 'chuyển sang dâng → bám target tức thì');
    });
  });
}
