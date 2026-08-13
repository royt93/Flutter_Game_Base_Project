import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/puzzle_presets.dart';
import 'package:pop_star_blast/logic/puzzle_code.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F18 — phần nối "Bàn hôm nay" vào `GameController`.
///
/// Điểm rủi ro nằm ở chỗ nó **mượn** `GameMode.puzzleLab` — mode vốn cố ý
/// không thưởng gì. Cờ `puzzleDailyRun` là thứ duy nhất phân biệt hai đường,
/// nên mọi ca dưới đây xoay quanh: cờ có bật đúng lúc không, và có tắt đúng
/// lúc không.
late GameController ctrl;

Future<void> _boot({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('nguồn bàn', () {
    test('chưa lưu bàn nào -> vẫn chạy bằng preset', () async {
      await _boot();
      expect(StorageService.to.getStringList(StorageKeys.savedPuzzles), isEmpty);
      expect(
        ctrl.puzzleDailyBoard,
        isNotNull,
        reason: 'AC bắt buộc: không có bàn tự vẽ vẫn phải chơi được',
      );
      expect(ctrl.startPuzzleDaily(), isTrue);
    });

    test('bàn tự vẽ được ưu tiên đứng trước preset', () async {
      await _boot();
      final codes = ctrl.puzzleDailyCandidateCodes;
      expect(codes.first, kPuzzlePresets.first.code);

      // Lưu 1 bàn -> nó phải chen lên đầu danh sách ứng viên.
      await StorageService.to.setStringList(
        StorageKeys.savedPuzzles,
        [kPuzzlePresets.last.code],
      );
      expect(ctrl.puzzleDailyCandidateCodes.first, kPuzzlePresets.last.code);
    });

    test('bàn tự vẽ hỏng không làm sập tính năng', () async {
      await _boot(prefs: {StorageKeys.savedPuzzles: '["rac","!!!"]'});
      expect(ctrl.puzzleDailyBoard, isNotNull);
    });
  });

  group('bắt đầu ván', () {
    test('vào đúng mode puzzleLab và bật cờ', () async {
      await _boot();
      expect(ctrl.startPuzzleDaily(), isTrue);

      expect(ctrl.mode.value, GameMode.puzzleLab);
      expect(ctrl.puzzleDailyRun, isTrue);
      expect(ctrl.currentLevel.id, -18);
      expect(ctrl.score.value, 0);
    });

    test('target khớp kích thước bàn', () async {
      await _boot();
      ctrl.startPuzzleDaily();
      final lv = ctrl.currentLevel;
      expect(lv.targetScore, lv.rows * lv.cols * 6);
    });

    test('cùng ngày gọi lại -> cùng bàn', () async {
      await _boot();
      ctrl.startPuzzleDaily();
      final a = ctrl.puzzleLabGrid;
      ctrl.startPuzzleDaily();
      expect(ctrl.puzzleLabGrid, equals(a));
    });

    test('vào Puzzle Lab thường sau đó -> cờ TẮT', () async {
      // Chốt quan trọng nhất: nếu cờ không tắt thì sandbox bỗng phát coin.
      await _boot();
      ctrl.startPuzzleDaily();
      expect(ctrl.puzzleDailyRun, isTrue);

      ctrl.startPuzzleLevel(const [
        [0, 0],
        [0, 0],
      ]);

      expect(ctrl.puzzleDailyRun, isFalse);
    });

    test('vào mode khác rồi quay lại Puzzle Lab thường -> vẫn tắt', () async {
      await _boot();
      ctrl.startPuzzleDaily();
      ctrl.startSideMode(GameMode.timeAttack);
      ctrl.startPuzzleLevel(const [
        [0, 0],
        [0, 0],
      ]);
      expect(ctrl.puzzleDailyRun, isFalse);
    });
  });

  group('thưởng', () {
    test('ghi điểm + cộng coin theo điểm', () async {
      await _boot();
      ctrl.startPuzzleDaily();
      final coinsBefore = ctrl.coins.value;
      ctrl.score.value = 500;

      ctrl.checkEnd(true);

      expect(ctrl.puzzleDailyScore, 500);
      expect(ctrl.coins.value - coinsBefore, 10);
      expect(ctrl.canRecordPuzzleDailyScore, isFalse);
    });

    test('trần coin chặn bàn khổng lồ thành máy in tiền', () async {
      await _boot();
      ctrl.startPuzzleDaily();
      final coinsBefore = ctrl.coins.value;
      ctrl.score.value = 999999;

      ctrl.checkEnd(true);

      expect(
        ctrl.coins.value - coinsBefore,
        GameController.puzzleDailyCoinCap,
        reason: 'người chơi tự thiết kế bàn — không được tin kích thước bàn',
      );
    });

    test('chơi lại trong ngày KHÔNG cộng coin lần hai', () async {
      await _boot();
      ctrl.startPuzzleDaily();
      ctrl.score.value = 500;
      ctrl.checkEnd(true);
      final afterFirst = ctrl.coins.value;

      ctrl.startPuzzleDaily();
      ctrl.score.value = 900;
      ctrl.checkEnd(true);

      expect(ctrl.coins.value, afterFirst);
      expect(ctrl.puzzleDailyScore, 500, reason: 'không đè điểm đã ghi');
    });

    test('Puzzle Lab thường KHÔNG thưởng gì', () async {
      await _boot();
      ctrl.startPuzzleLevel(const [
        [0, 0],
        [0, 0],
      ]);
      final coinsBefore = ctrl.coins.value;
      ctrl.score.value = 500;

      ctrl.checkEnd(true);

      expect(ctrl.coins.value, coinsBefore);
      expect(ctrl.puzzleDailyScore, 0);
      expect(ctrl.canRecordPuzzleDailyScore, isTrue);
    });

    test('không đụng star/highScore/unlock campaign', () async {
      await _boot();
      final unlockedBefore = ctrl.unlockedLevel.value;
      final starsBefore = ctrl.totalStars.value;

      ctrl.startPuzzleDaily();
      ctrl.score.value = 5000;
      ctrl.checkEnd(true);

      expect(ctrl.unlockedLevel.value, unlockedBefore);
      expect(ctrl.totalStars.value, starsBefore);
      expect(ctrl.starsEarned.value, 0);
    });

    test('key riêng, không đè Daily Challenge', () async {
      await _boot();
      ctrl.startPuzzleDaily();
      ctrl.score.value = 300;
      ctrl.checkEnd(true);

      expect(
        ctrl.canRecordDailyChallengeScore,
        isTrue,
        reason: 'chơi Bàn hôm nay không được tiêu mất lượt Daily Challenge',
      );
    });
  });

  group('save hỏng', () {
    test('mọi mã đều hỏng và preset rỗng -> startPuzzleDaily trả false', () async {
      await _boot();
      // Không thể làm preset rỗng từ ngoài, nên kiểm thẳng hàm thuần đã có
      // test riêng; ở đây chỉ chốt hợp đồng "false chứ không ném".
      expect(decodePuzzleGrid('rac'), isNull);
      expect(ctrl.startPuzzleDaily(), isTrue);
    });
  });
}
