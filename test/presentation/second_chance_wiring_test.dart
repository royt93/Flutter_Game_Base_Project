import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/logic/second_chance.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// I88 — phần nối dây. Điều kiện chào đã có test thuần; ở đây kiểm những thứ
/// hàm thuần không thấy: trừ đúng xu, **giữ nguyên điểm**, mở lại ván, và các
/// cờ loại trừ (thành tựu "dọn sạch bàn", replay).
late GameController ctrl;

Future<void> _boot({int coins = 1000}) async {
  SharedPreferences.setMockInitialValues({StorageKeys.coins: coins});
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);
  ctrl.startLevel(1);
}

/// Thua sát nút: đủ điều kiện chào mua.
void _loseNarrowly() {
  ctrl.score.value = (ctrl.currentLevel.targetScore * 0.8).round();
  ctrl.starsEarned.value = 0;
  ctrl.ended.value = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('điều kiện qua controller', () {
    test('thua sát nút + đủ xu -> chào mua', () async {
      await _boot();
      _loseNarrowly();
      expect(ctrl.canBuySecondChance, isTrue);
      expect(ctrl.secondChanceUnaffordable, isFalse);
    });

    test('thiếu xu -> không chào nhưng báo thiếu xu', () async {
      await _boot(coins: kSecondChanceCost - 1);
      _loseNarrowly();
      expect(ctrl.canBuySecondChance, isFalse);
      expect(ctrl.secondChanceUnaffordable, isTrue);
    });

    test('side-mode -> không bao giờ chào', () async {
      await _boot();
      ctrl.startSideMode(GameMode.timeAttack);
      ctrl.score.value = 99999;
      ctrl.starsEarned.value = 0;
      expect(ctrl.canBuySecondChance, isFalse);
      expect(ctrl.secondChanceUnaffordable, isFalse);
    });
  });

  group('mua', () {
    test('trừ đúng giá, persist, và GIỮ NGUYÊN điểm', () async {
      await _boot(coins: 1000);
      _loseNarrowly();
      final scoreBefore = ctrl.score.value;

      expect(ctrl.buySecondChance(), isTrue);

      expect(ctrl.coins.value, 1000 - kSecondChanceCost);
      expect(
        StorageService.to.getInt(StorageKeys.coins),
        1000 - kSecondChanceCost,
      );
      expect(
        ctrl.score.value,
        scoreBefore,
        reason: 'đây là cứu trợ, không phải chơi lại từ đầu',
      );
    });

    test('mở lại ván: ended/cleared hạ xuống', () async {
      await _boot();
      _loseNarrowly();
      ctrl.cleared.value = true;

      ctrl.buySecondChance();

      expect(ctrl.ended.value, isFalse);
      expect(ctrl.cleared.value, isFalse);
    });

    test('tối đa 1 lần mỗi màn', () async {
      await _boot(coins: 10000);
      _loseNarrowly();
      expect(ctrl.buySecondChance(), isTrue);

      _loseNarrowly();
      expect(ctrl.canBuySecondChance, isFalse);
      expect(ctrl.buySecondChance(), isFalse);
    });

    test('không đủ điều kiện -> không trừ xu', () async {
      await _boot(coins: 1000);
      ctrl.score.value = 0; // thua quá xa
      ctrl.starsEarned.value = 0;

      expect(ctrl.buySecondChance(), isFalse);
      expect(ctrl.coins.value, 1000);
    });

    test('màn mới reset lại quyền mua', () async {
      await _boot(coins: 10000);
      _loseNarrowly();
      ctrl.buySecondChance();

      ctrl.startLevel(2);
      _loseNarrowly();
      expect(
        ctrl.canBuySecondChance,
        isTrue,
        reason: 'giới hạn là mỗi màn, không phải mỗi phiên',
      );
    });
  });

  group('cờ loại trừ', () {
    test('bàn đã bồi -> KHÔNG tính vào thành tựu "dọn sạch bàn"', () async {
      await _boot(coins: 10000);
      final before = ctrl.boardsFullyCleared.value;
      _loseNarrowly();
      ctrl.buySecondChance();

      ctrl.checkEnd(true); // dọn sạch bàn đã được bồi

      expect(
        ctrl.boardsFullyCleared.value,
        before,
        reason: 'thành tựu đó phải nói về bàn gốc, không phải bàn mua thêm',
      );
    });

    test('ván bình thường vẫn tính "dọn sạch bàn"', () async {
      await _boot();
      final before = ctrl.boardsFullyCleared.value;
      ctrl.checkEnd(true);
      expect(ctrl.boardsFullyCleared.value, before + 1);
    });

    test('thắng sau khi mua vẫn được sao/xu/mở khoá bình thường', () async {
      await _boot(coins: 10000);
      _loseNarrowly();
      ctrl.buySecondChance();

      ctrl.score.value = ctrl.currentLevel.targetScore * 2;
      ctrl.checkEnd(false);

      expect(ctrl.starsEarned.value, greaterThan(0));
      expect(ctrl.unlockedLevel.value, greaterThan(1));
    });
  });
}
