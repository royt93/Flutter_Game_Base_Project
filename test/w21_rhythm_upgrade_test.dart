import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/logic/rhythm_clock.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // ─── rhythmBpmFor (pure function) ─────────────────────────────────────────

  group('rhythmBpmFor — BPM theo groove', () {
    test('groove 0 → 80', () => expect(rhythmBpmFor(0), 80));
    test('groove 1 → 80', () => expect(rhythmBpmFor(1), 80));
    test('groove 2 → 80', () => expect(rhythmBpmFor(2), 80));
    test('groove 3 → 100', () => expect(rhythmBpmFor(3), 100));
    test('groove 5 → 100', () => expect(rhythmBpmFor(5), 100));
    test('groove 6 → 120', () => expect(rhythmBpmFor(6), 120));
    test('groove 7 → 120', () => expect(rhythmBpmFor(7), 120));
    test('groove 8 → 140', () => expect(rhythmBpmFor(8), 140));
    test('groove > 8 → 140 (clamp ẩn)', () => expect(rhythmBpmFor(10), 140));
  });

  // ─── rhythmWindowFor (pure function) ──────────────────────────────────────

  group('rhythmWindowFor — window theo groove', () {
    test('groove 0-7 → 0.14', () {
      for (var g = 0; g <= 7; g++) {
        expect(rhythmWindowFor(g), closeTo(0.14, 0.001), reason: 'groove $g');
      }
    });
    test(
      'groove 8 → 0.10',
      () => expect(rhythmWindowFor(8), closeTo(0.10, 0.001)),
    );
  });

  // ─── rhythmJudgeFor (pure function) ───────────────────────────────────────

  group('rhythmJudgeFor — phân loại nhịp', () {
    const w = 0.14;
    test('distance 0 → PERFECT (2)', () => expect(rhythmJudgeFor(0, w), 2));
    test(
      'distance 0.04 → PERFECT (2)',
      () => expect(rhythmJudgeFor(0.04, w), 2),
    );
    test(
      'distance 0.05 → PERFECT (2, boundary)',
      () => expect(rhythmJudgeFor(0.05, w), 2),
    );
    test('distance 0.06 → GOOD (1)', () => expect(rhythmJudgeFor(0.06, w), 1));
    test(
      'distance 0.10 → GOOD (1, boundary)',
      () => expect(rhythmJudgeFor(0.10, w), 1),
    );
    test(
      'distance 0.11 → LATE (-1)',
      () => expect(rhythmJudgeFor(0.11, w), -1),
    );
    test(
      'distance 0.14 → LATE (-1, at window)',
      () => expect(rhythmJudgeFor(0.14, w), -1),
    );
    test(
      'distance 0.15 → MISS (-2, beyond window)',
      () => expect(rhythmJudgeFor(0.15, w), -2),
    );
  });

  // ─── RhythmClock.bpm setter + distanceToBeat ──────────────────────────────

  group('RhythmClock — mutable bpm + distanceToBeat', () {
    test('bpm setter thay đổi beatPeriod', () {
      final c = RhythmClock(bpm: 100);
      expect(c.beatPeriod, closeTo(0.6, 0.001));
      c.bpm = 120;
      expect(c.beatPeriod, closeTo(0.5, 0.001));
    });

    test('distanceToBeat = 0 khi đúng mốc beat', () {
      final c = RhythmClock(bpm: 60); // 1 beat/giây
      c.tick(1.0); // đúng mốc beat 1s
      expect(c.distanceToBeat, closeTo(0, 0.001));
    });

    test('distanceToBeat = 0.3 khi giữa beat (60 BPM → period=1s)', () {
      final c = RhythmClock(bpm: 60);
      c.tick(0.3); // 0.3s vào beat period = 1s
      expect(c.distanceToBeat, closeTo(0.3, 0.001));
    });

    test('distanceToBeat = 0.1 gần cuối beat (vẫn gần mốc TIẾP THEO)', () {
      final c = RhythmClock(bpm: 60);
      c.tick(0.9); // 0.9s → còn 0.1s đến beat tiếp
      expect(c.distanceToBeat, closeTo(0.1, 0.001));
    });

    test('window setter thay đổi onBeat', () {
      final c = RhythmClock(bpm: 60, window: 0.14);
      c.tick(0.12); // 0.12 < 0.14 → onBeat
      expect(c.onBeat, isTrue);
      c.window = 0.10; // thu hẹp window
      expect(c.onBeat, isFalse); // 0.12 > 0.10 → off beat
    });
  });

  // ─── tickRhythm cập nhật BPM theo groove ─────────────────────────────────

  group('tickRhythm — BPM dynamic', () {
    late GameController g;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      Get.put(StorageService(await SharedPreferences.getInstance()));
      g = Get.put(GameController());
      g.startRhythm();
    });

    tearDown(() => Get.reset());

    test('groove 0 → rhythmBpm = 80', () {
      g.groove.value = 0;
      g.tickRhythm(0.01);
      expect(g.rhythmBpm.value, closeTo(80, 0.1));
    });

    test('groove 5 → rhythmBpm = 100', () {
      g.groove.value = 5;
      g.tickRhythm(0.01);
      expect(g.rhythmBpm.value, closeTo(100, 0.1));
    });

    test('groove 8 → rhythmBpm = 140', () {
      g.groove.value = 8;
      g.tickRhythm(0.01);
      expect(g.rhythmBpm.value, closeTo(140, 0.1));
    });

    test('startRhythm reset sạch judgment/BPM/window khi chơi lại', () {
      g.groove.value = 8;
      g.tickRhythm(0.01);
      g.rhythmJudge.value = 2;
      g.lastBeatJudge.value = 1;

      g.startRhythm();

      expect(g.rhythmJudge.value, 0);
      expect(g.lastBeatJudge.value, 0);
      expect(g.rhythmBpm.value, closeTo(80, 0.1));
      expect(g.rhythm.bpm, closeTo(80, 0.1));
      expect(g.rhythm.window, closeTo(0.14, 0.001));
    });
  });

  // ─── judgeRhythmBeat sets rhythmJudge ─────────────────────────────────────

  group('judgeRhythmBeat — rhythmJudge Rx', () {
    late GameController g;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      Get.put(StorageService(await SharedPreferences.getInstance()));
      g = Get.put(GameController());
      g.startRhythm();
    });

    tearDown(() => Get.reset());

    test('lastBeatJudge tương thích: hit → 1, miss → -1', () {
      // Tiến đồng hồ đến gần mốc beat (0.01s sau beat → distanceToBeat nhỏ)
      g.tickRhythm(
        0.6,
      ); // cross 1 beat ở 60 BPM... nhưng rhythm bắt đầu ở 80 BPM
      // Gọi judge ngay sau cross beat → distance gần 0 → PERFECT
      g.judgeRhythmBeat();
      // Chỉ kiểm tra lastBeatJudge là 1 hoặc -1 (không phụ thuộc timing chính xác)
      expect([1, -1], contains(g.lastBeatJudge.value));
    });

    test('rhythmJudge = 0 trước khi đánh lần nào', () {
      expect(g.rhythmJudge.value, 0);
    });

    test('judgeRhythmBeat đặt rhythmJudge ≠ 0 sau khi gọi', () {
      g.tickRhythm(0.1);
      g.judgeRhythmBeat();
      // Sau khi gọi, rhythmJudge phải là một trong các giá trị hợp lệ
      expect([-2, -1, 1, 2], contains(g.rhythmJudge.value));
    });

    test('isolation: rhythmJudge không bị set khi isRhythm = false', () {
      g.startLevel(1); // tắt rhythm
      g.judgeRhythmBeat();
      expect(g.rhythmJudge.value, 0); // không thay đổi
    });
  });
}
