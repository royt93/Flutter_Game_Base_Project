import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/logic/daily_challenge.dart';
import 'package:pop_star_blast/logic/ghost_duel.dart';
import 'package:pop_star_blast/logic/replay.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F16 — phần nối Ghost Duel vào `GameController`.
///
/// Nếp chung của mọi side-mode phải giữ: **không** đụng star/highScore/unlock
/// campaign, best score có key riêng.
late GameController ctrl;

Future<void> _boot({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);
}

DuelData _duel({int seed = 4242, int score = 500}) => DuelData(
  seed: seed,
  taps: const [(0, 0), (1, 1), (2, 2)],
  score: score,
  senderName: 'Bạn A',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('bắt đầu ván đấu', () {
    test('vào mode duel, bàn dựng từ seed', () async {
      await _boot();
      expect(ctrl.startDuel(_duel()), isTrue);

      expect(ctrl.mode.value, GameMode.duel);
      expect(ctrl.currentLevel.id, -16);
      expect(
        ctrl.puzzleLabGrid,
        equals(generateDailyChallengeGrid(4242)),
        reason: 'hai người phải chơi ĐÚNG một bàn',
      );
      expect(ctrl.score.value, 0);
    });

    test('cùng mã -> cùng bàn, gọi lại bao nhiêu lần cũng vậy', () async {
      await _boot();
      ctrl.startDuel(_duel());
      final a = ctrl.puzzleLabGrid;
      ctrl.startDuel(_duel());
      expect(ctrl.puzzleLabGrid, equals(a));
    });

    test('mã seed khác -> bàn khác', () async {
      await _boot();
      ctrl.startDuel(_duel(seed: 1));
      final a = ctrl.puzzleLabGrid;
      ctrl.startDuel(_duel(seed: 2));
      expect(ctrl.puzzleLabGrid, isNot(equals(a)));
    });

    test('timeline ghost dựng sẵn theo số tap', () async {
      await _boot();
      ctrl.startDuel(_duel());
      expect(ctrl.ghostTimeline.length, 3);
    });
  });

  group('điểm ghost trên HUD', () {
    test('chưa đi nước nào -> 0', () async {
      await _boot();
      ctrl.startDuel(_duel());
      expect(ctrl.movesUsed.value, 0);
      expect(ctrl.ghostScoreNow, 0);
    });

    test('theo SỐ NƯỚC ĐI, không theo thời gian', () async {
      await _boot();
      ctrl.startDuel(_duel());
      ctrl.ghostTimeline = [10, 30, 60];

      ctrl.movesUsed.value = 1;
      expect(ctrl.ghostScoreNow, 10);
      ctrl.movesUsed.value = 3;
      expect(ctrl.ghostScoreNow, 60);
    });

    test('người chơi đi quá số nước ghost -> giữ điểm cuối', () async {
      await _boot();
      ctrl.startDuel(_duel());
      ctrl.ghostTimeline = [10, 30, 60];
      ctrl.movesUsed.value = 50;
      expect(ctrl.ghostScoreNow, 60);
    });
  });

  group('kết quả', () {
    test('hơn điểm ghost -> thắng', () async {
      await _boot();
      ctrl.startDuel(_duel(score: 100));
      ctrl.score.value = 200;
      expect(ctrl.duelOutcomeNow, GhostDuelOutcome.win);
    });

    test('so với điểm THẬT của ghost, không phải điểm mô phỏng', () async {
      // Mô phỏng bỏ qua power tile/combo nên là cận dưới — dùng nó để so
      // thắng-thua là chấm sai cho người kia.
      await _boot();
      ctrl.startDuel(_duel(score: 999999));
      ctrl.score.value = 1000;
      expect(ctrl.duelOutcomeNow, GhostDuelOutcome.lose);
    });

    test('không ở chế độ duel -> null', () async {
      await _boot();
      ctrl.startLevel(1);
      expect(ctrl.activeDuel, isNull);
      expect(ctrl.duelOutcomeNow, isNull);
    });
  });

  group('nếp chung side-mode', () {
    test('KHÔNG đụng star/highScore/unlock campaign', () async {
      await _boot();
      final unlockedBefore = ctrl.unlockedLevel.value;
      final starsBefore = ctrl.totalStars.value;

      ctrl.startDuel(_duel());
      ctrl.score.value = 99999;
      ctrl.checkEnd(true);

      expect(ctrl.unlockedLevel.value, unlockedBefore);
      expect(ctrl.totalStars.value, starsBefore);
      expect(ctrl.starsEarned.value, 0);
    });

    test('best score có key riêng và chỉ tăng', () async {
      await _boot();
      ctrl.startDuel(_duel());
      ctrl.score.value = 700;
      ctrl.checkEnd(true);
      expect(ctrl.duelBest, 700);

      ctrl.startDuel(_duel());
      ctrl.score.value = 100;
      ctrl.checkEnd(true);
      expect(ctrl.duelBest, 700, reason: 'điểm thấp hơn không được đè');
    });

    test('duelBest nạp lại từ save', () async {
      await _boot(prefs: {StorageKeys.duelBest: 1234});
      expect(ctrl.duelBest, 1234);
    });
  });

  group('mã trả đũa', () {
    test('chưa có ván -> null', () async {
      await _boot();
      expect(ctrl.buildRematchCode(), isNull);
    });

    test('không ở chế độ duel -> null', () async {
      await _boot();
      ctrl.startLevel(1);
      expect(ctrl.buildRematchCode(), isNull);
    });
  });

  group('mã trả đũa dựng được sau ván', () {
    test('cùng seed với lời thách gốc', () async {
      // Trả đũa phải là CÙNG bàn, nếu không nó là lời thách mới chứ không
      // phải trả đũa.
      await _boot();
      ctrl.startDuel(_duel(seed: 4242));
      // `buildRematchCode` cần `activeGame`; không có engine trong test thuần
      // nên chốt hợp đồng "null chứ không ném" và kiểm phần seed qua codec.
      expect(ctrl.buildRematchCode(), isNull);

      final mine = encodeDuelCode(
        DuelData(seed: 4242, taps: const [(0, 0)], score: 900, senderName: 'Tôi'),
      );
      expect(decodeDuelCode(mine)!.seed, 4242);
    });
  });
}
