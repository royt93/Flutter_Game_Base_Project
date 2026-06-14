import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/logic/rhythm_clock.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RhythmClock (thuần)', () {
    test('beatPeriod theo BPM', () {
      final c = RhythmClock(bpm: 120);
      expect(c.beatPeriod, closeTo(0.5, 1e-9));
    });

    test('tick cross beat trả true đúng mốc', () {
      final c = RhythmClock(bpm: 100); // beat 0.6s
      expect(c.tick(0.3), isFalse); // chưa qua mốc 1
      expect(c.beatCount, 0);
      expect(c.tick(0.4), isTrue); // t=0.7 → qua mốc beat 1
      expect(c.beatCount, 1);
    });

    test('onBeat đúng quanh mốc, sai ở giữa', () {
      final c = RhythmClock(bpm: 100, window: 0.14); // beat 0.6
      c.tick(0.05); // t=0.05, gần mốc 0 → đúng nhịp
      expect(c.onBeat, isTrue);
      c.reset();
      c.tick(0.3); // t=0.3, giữa beat → lệch nhịp
      expect(c.onBeat, isFalse);
      c.reset();
      c.tick(0.58); // t=0.58, gần mốc 0.6 (cách 0.02) → đúng nhịp
      expect(c.onBeat, isTrue);
    });

    test('reset đưa về 0', () {
      final c = RhythmClock();
      c.tick(5.0);
      c.reset();
      expect(c.time, 0);
      expect(c.beatCount, 0);
    });

    test('tick dt<=0 không tiến', () {
      final c = RhythmClock();
      expect(c.tick(0), isFalse);
      expect(c.tick(-1), isFalse);
      expect(c.time, 0);
    });
  });

  group('GameController — Rhythm mode', () {
    late GameController c;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      Get.reset();
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs));
      c = Get.put(GameController());
    });
    tearDown(Get.reset);

    test('startRhythm đặt cờ + mục tiêu điểm', () {
      c.startRhythm();
      expect(c.isRhythm.value, isTrue);
      expect(c.isBoss.value, isFalse);
      expect(c.level.objective, ObjectiveType.score);
      expect(c.movesLeft.value, kRhythmMoves);
      expect(c.targetScore.value, kRhythmTarget);
      expect(c.groove.value, 0);
    });

    test('đúng nhịp → groove++ và thưởng điểm; lệch nhịp → groove--', () {
      c.startRhythm();
      // đưa đồng hồ tới gần mốc beat → đúng nhịp
      c.rhythm.reset();
      c.tickRhythm(0.02); // gần mốc 0
      c.judgeRhythmBeat();
      expect(c.groove.value, 1);
      expect(c.lastBeatJudge.value, 1);
      // điểm có bonus (×1.5..2.5) so với base 3*10=30
      final s0 = c.score.value;
      c.addScore(3, 1); // base 30 → ×(1.5 + 1/8) = ×1.625 = 49 (làm tròn)
      expect(c.score.value - s0, greaterThan(30));

      // lệch nhịp → groove giảm, không bonus
      c.rhythm.reset();
      c.tickRhythm(0.3); // giữa beat
      c.judgeRhythmBeat();
      expect(c.groove.value, 0);
      expect(c.lastBeatJudge.value, -1);
      final s1 = c.score.value;
      c.addScore(3, 1); // base 30, không nhân
      expect(c.score.value - s1, 30);
    });

    test('đạt điểm mục tiêu → win, thưởng xu/shard, KHÔNG đụng win-streak', () {
      c.startRhythm();
      c.winStreak.value = 3;
      final coins0 = c.coins.value;
      c.score.value = kRhythmTarget;
      final r = c.checkEnd();
      expect(r, 'win');
      expect(c.winStreak.value, 3); // không đổi
      expect(c.coins.value, greaterThan(coins0));
      expect(c.lastShardReward, greaterThan(0));
    });

    test('hết lượt mà chưa đạt điểm → lose, không thưởng', () {
      c.startRhythm();
      c.score.value = 100;
      c.movesLeft.value = 0;
      expect(c.checkEnd(), 'lose');
      expect(c.lastCoinReward, 0);
    });

    test('chuyển sang mode khác tắt cờ rhythm', () {
      c.startRhythm();
      expect(c.isRhythm.value, isTrue);
      expect(c.level.index, kRhythmLevelIndex);
      c.startLevel(1);
      expect(c.isRhythm.value, isFalse);
      expect(c.level.index, 1); // về cấu hình màn thật, không còn _rhythmCfg
    });
  });
}
