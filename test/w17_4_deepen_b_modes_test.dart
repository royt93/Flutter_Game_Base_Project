import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    c = Get.put(GameController());
  });
  tearDown(Get.reset);

  // ---------------------------------------------------------------------------
  // W17.4a: ColorRush Multiplier
  // ---------------------------------------------------------------------------
  group('W17.4a — ColorRush streak multiplier', () {
    setUp(() => c.startColorRush());

    test('streak starts at 0', () {
      expect(c.colorRushStreak.value, 0);
    });

    test('colorRushBonus(5) with streak=0: score += 5*15*1 = 75', () {
      final before = c.score.value;
      c.colorRushBonus(5);
      expect(c.score.value, before + 75);
    });

    test('tickColorRush after hot color cleared: streak → 1', () {
      c.colorRushBonus(3); // set _colorRushHotClearedThisMove = true
      c.tickColorRush();
      expect(c.colorRushStreak.value, 1);
    });

    test('colorRushBonus(5) with streak=1: score += 5*15*2 = 150', () {
      c.colorRushBonus(1); // trigger flag
      c.tickColorRush(); // streak → 1
      final before = c.score.value;
      c.colorRushBonus(5); // mult = (1+1) = 2
      expect(c.score.value, before + 150);
    });

    test('streak resets to 0 after miss (tickColorRush without prior colorRushBonus)', () {
      // Build up a streak
      c.colorRushBonus(1);
      c.tickColorRush(); // streak = 1
      // Miss: tick without bonus
      c.tickColorRush(); // streak → 0
      expect(c.colorRushStreak.value, 0);
    });

    test('streak resets on hot color change (every kColorRushChangeEvery moves)', () {
      // Build streak to 2
      c.colorRushBonus(1);
      c.tickColorRush(); // move 1: streak = 1
      c.colorRushBonus(1);
      c.tickColorRush(); // move 2: streak = 2
      c.colorRushBonus(1);
      c.tickColorRush(); // move 3: streak = 3
      c.colorRushBonus(1);
      // move 4 triggers color change (kColorRushChangeEvery == 4)
      c.tickColorRush(); // streak first → 4 but clamped, then reset to 0 on color change
      expect(c.colorRushStreak.value, 0);
    });

    test('streak capped at kColorRushMaxStreak (3)', () {
      // tick 4 times with hot color cleared each time
      for (int i = 0; i < 3; i++) {
        c.colorRushBonus(1);
        c.tickColorRush();
      }
      expect(c.colorRushStreak.value, kColorRushMaxStreak);
      // one more: should stay at cap (if no color change)
      // Note: at move 4, color changes → streak resets. Let's test cap before reset.
      // At streak=3 (cap), bonus mult should be clamped to 3 as well.
      final before = c.score.value;
      c.colorRushBonus(5); // mult = clamp(3+1,1,3) = 3 → 5*15*3 = 225
      expect(c.score.value, before + 225);
    });
  });

  // ---------------------------------------------------------------------------
  // W17.4b: Endless Stage Events
  // ---------------------------------------------------------------------------
  group('W17.4b — Endless stage events', () {
    setUp(() => c.startEndless());

    test('stage 4 → no event fired', () {
      // Stage = 1 + score ~/ kEndlessStageScore, so stage 4 at score = 3*1500 = 4500
      c.score.value = 0;
      c.addScore(0, 1); // stage stays 1
      c.score.value = kEndlessStageScore; // score=1500 → stage=2
      c.addScore(0, 1);
      c.score.value = kEndlessStageScore * 2; // score=3000 → stage=3
      c.addScore(0, 1);
      c.score.value = kEndlessStageScore * 3; // score=4500 → stage=4
      c.addScore(0, 1);
      expect(c.endlessEvent.value, '');
    });

    test('event 1 (stage 5): endlessEvent = moves, movesLeft += kEndlessEventMovesBonus', () {
      final movesBefore = c.movesLeft.value;
      c.score.value = kEndlessStageScore * 4; // stage=5 threshold
      c.addScore(0, 1);
      expect(c.endlessEvent.value, 'moves');
      expect(c.movesLeft.value, movesBefore + kEndlessEventMovesBonus);
    });

    test('event 2 (stage 10): endlessEvent = scoreX2', () {
      // Jump straight to stage 10
      c.endlessStage.value = 9; // trick: set stage below threshold
      c.score.value = kEndlessStageScore * 9; // will compute stage=10
      c.addScore(0, 1);
      expect(c.endlessEvent.value, 'scoreX2');
    });

    test('event 3 (stage 15): endlessEvent = gems, consumeEndlessGemRain returns true then false', () {
      c.endlessStage.value = 14;
      c.score.value = kEndlessStageScore * 14; // stage=15
      c.addScore(0, 1);
      expect(c.endlessEvent.value, 'gems');
      expect(c.consumeEndlessGemRain(), isTrue);
      expect(c.consumeEndlessGemRain(), isFalse);
    });

    test('event 4 (stage 20): cycles back to moves', () {
      c.endlessStage.value = 19;
      c.score.value = kEndlessStageScore * 19;
      c.addScore(0, 1);
      expect(c.endlessEvent.value, 'moves');
    });

    test('scoreX2 event: addScore doubles gained for kEndlessEventScoreBoostMoves calls then stops', () {
      // Trigger scoreX2 event at stage 10
      c.endlessStage.value = 9;
      c.score.value = kEndlessStageScore * 9;
      c.addScore(0, 1); // triggers event → _endlessScoreX2Remaining = kEndlessEventScoreBoostMoves
      expect(c.endlessEvent.value, 'scoreX2');

      // Each addScore call should double gained
      // gained for 4 gems, combo 1 = 4*10*1 = 40; ×2 = 80
      for (int i = 0; i < kEndlessEventScoreBoostMoves; i++) {
        final before = c.score.value;
        c.addScore(4, 1);
        final gained = c.score.value - before;
        // gained should be doubled (80 instead of 40), minus any refund from _endlessTick
        // Note: _endlessTick may also add refund moves, but score delta is from addScore
        expect(gained, greaterThanOrEqualTo(80));
      }
      // After kEndlessEventScoreBoostMoves calls, event clears
      expect(c.endlessEvent.value, '');
    });

    test('startEndless() resets event state (event clears, no spurious event on re-start)', () {
      // Trigger an event first
      c.endlessStage.value = 4;
      c.score.value = kEndlessStageScore * 4;
      c.addScore(0, 1);
      expect(c.endlessEvent.value, 'moves'); // event 1 fired
      // Restart
      c.startEndless();
      expect(c.endlessEvent.value, '');
      // After restart, stage 5 should fire event again (counter reset)
      c.endlessStage.value = 4;
      c.score.value = kEndlessStageScore * 4;
      c.addScore(0, 1);
      expect(c.endlessEvent.value, 'moves'); // fires again after reset
    });
  });

  // ---------------------------------------------------------------------------
  // W17.4c: Soda Nozzle
  // ---------------------------------------------------------------------------
  group('W17.4c — Soda nozzle', () {
    setUp(() => c.startSoda());

    test('tickSoda 4 times: no burst yet', () {
      final fillBefore = c.sodaFill.value;
      final pulseBefore = c.sodaNozzlePulse.value;
      for (int i = 0; i < 4; i++) {
        c.tickSoda();
      }
      expect(c.sodaFill.value, fillBefore);
      expect(c.sodaNozzlePulse.value, pulseBefore);
    });

    test('tickSoda 5th time: sodaFill += kSodaNozzleBurst, sodaNozzlePulse = 1', () {
      final fillBefore = c.sodaFill.value;
      for (int i = 0; i < 5; i++) {
        c.tickSoda();
      }
      expect(c.sodaFill.value, fillBefore + kSodaNozzleBurst);
      expect(c.sodaNozzlePulse.value, 1);
    });

    test('tickSoda 10th time: second burst, sodaNozzlePulse = 2', () {
      for (int i = 0; i < 10; i++) {
        c.tickSoda();
      }
      expect(c.sodaFill.value, kSodaNozzleBurst * 2);
      expect(c.sodaNozzlePulse.value, 2);
    });

    test('startSoda() resets _sodaMoveCount to 0', () {
      for (int i = 0; i < 4; i++) {
        c.tickSoda();
      }
      c.startSoda(); // reset
      // After reset, next 4 ticks should still produce no burst
      for (int i = 0; i < 4; i++) {
        c.tickSoda();
      }
      expect(c.sodaNozzlePulse.value, 0);
      expect(c.sodaFill.value, 0);
    });
  });
}
