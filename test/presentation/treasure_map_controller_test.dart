import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/gauntlet_modifiers.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/treasure_map_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// T2 — `TreasureMapController` (I60) điều phối 1 chuyến 5 stage. Kết thúc màn
/// đến **bất đồng bộ** qua `ever(gameCtrl.ended, …)`, nên mọi test dưới đây
/// kích hoạt bằng `gameCtrl.checkEnd(...)` chứ không gọi thẳng `_onEnded`.
late GameController gameCtrl;
late TreasureMapController ctrl;

Future<void> _boot({int maps = 1}) async {
  SharedPreferences.setMockInitialValues({
    if (maps > 0) StorageKeys.treasureMapCount: maps,
  });
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
  gameCtrl = Get.put(GameController(), permanent: true);
  ctrl = Get.put(TreasureMapController(gameCtrl));
}

/// Thắng stage hiện tại: điểm phải ≥ `targetScore` của stage đó.
void _winStage() {
  gameCtrl.ended.value = false;
  gameCtrl.score.value = gameCtrl.currentLevel.targetScore;
  gameCtrl.checkEnd(false);
}

void _loseStage() {
  gameCtrl.ended.value = false;
  gameCtrl.score.value = 0;
  gameCtrl.checkEnd(false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('bắt đầu chuyến — tiêu bản đồ', () {
    test('có bản đồ → tiêu đúng 1, vào stage 1, mode treasureMap', () async {
      await _boot(maps: 2);
      expect(ctrl.startExpedition(), isTrue);

      expect(gameCtrl.treasureMapCount.value, 1);
      expect(ctrl.stageIndex.value, 1);
      expect(gameCtrl.mode.value, GameMode.treasureMap);
      expect(ctrl.failed.value, isFalse);
      expect(ctrl.completed.value, isFalse);
      expect(StorageService.to.getInt(StorageKeys.treasureMapCount), 1);
    });

    test('hết bản đồ → trả false, không đổi mode, không tiêu gì', () async {
      await _boot(maps: 0);
      final modeBefore = gameCtrl.mode.value;

      expect(ctrl.startExpedition(), isFalse);
      expect(gameCtrl.treasureMapCount.value, 0);
      expect(gameCtrl.mode.value, modeBefore);
    });

    test('chuyến mới dọn sạch cờ failed/completed của chuyến trước', () async {
      await _boot(maps: 2);
      ctrl.startExpedition();
      _loseStage();
      expect(ctrl.failed.value, isTrue);

      expect(ctrl.startExpedition(), isTrue);
      expect(ctrl.failed.value, isFalse);
      expect(ctrl.stageIndex.value, 1);
    });
  });

  group('tiến qua 5 stage', () {
    test('thắng stage < 5 → chờ stage kế, chưa hoàn thành', () async {
      await _boot();
      ctrl.startExpedition();
      _winStage();

      expect(ctrl.awaitingNextStage.value, isTrue);
      expect(ctrl.completed.value, isFalse);
      expect(ctrl.stageIndex.value, 1, reason: 'chỉ tăng khi gọi nextStage()');
    });

    test('nextStage() tăng stage và bơm bàn mới', () async {
      await _boot();
      ctrl.startExpedition();
      final level1 = gameCtrl.currentLevel;
      _winStage();
      ctrl.nextStage();

      expect(ctrl.stageIndex.value, 2);
      expect(ctrl.awaitingNextStage.value, isFalse);
      expect(gameCtrl.currentLevel, isNot(same(level1)));
    });

    test('nextStage() khi chưa thắng → không làm gì (guard)', () async {
      await _boot();
      ctrl.startExpedition();
      ctrl.nextStage();
      expect(ctrl.stageIndex.value, 1);
    });

    test('thắng đủ 5 stage → completed + mở khoá board frame', () async {
      await _boot();
      ctrl.startExpedition();
      expect(gameCtrl.treasureMapCompleted.value, isFalse);

      for (var stage = 1; stage <= 5; stage++) {
        expect(ctrl.stageIndex.value, stage);
        _winStage();
        if (stage < 5) ctrl.nextStage();
      }

      expect(ctrl.completed.value, isTrue);
      expect(ctrl.awaitingNextStage.value, isFalse);
      expect(gameCtrl.treasureMapCompleted.value, isTrue);
      expect(StorageService.to.getBool(StorageKeys.treasureMapCompleted), true);
    });
  });

  group('modifier từng stage', () {
    test('mỗi stage áp đúng phần tử của kTreasureMapModifiers', () async {
      await _boot();
      ctrl.startExpedition();

      for (var stage = 1; stage <= 5; stage++) {
        expect(
          gameCtrl.activeTreasureMapModifier,
          same(kTreasureMapModifiers[stage - 1]),
          reason: 'stage $stage phải dùng modifier thứ ${stage - 1}',
        );
        expect(
          gameCtrl.activeGameplayModifier,
          same(kTreasureMapModifiers[stage - 1]),
          reason: 'activeGameplayModifier phải trỏ đúng modifier của mode',
        );
        _winStage();
        if (stage < 5) ctrl.nextStage();
      }
    });

    test('bàn mỗi stage tất định theo ngày + stage', () async {
      await _boot(maps: 2);
      ctrl.startExpedition();
      final firstBoard = gameCtrl.puzzleLabGrid!
          .map((r) => List<int>.from(r))
          .toList();

      // Chuyến thứ hai cùng ngày phải cho ra đúng bàn stage 1 như trên.
      ctrl.startExpedition();
      expect(gameCtrl.puzzleLabGrid, equals(firstBoard));
    });
  });

  group('thua giữa chuyến', () {
    test(
      'điểm dưới target → failed, không completed, không mở frame',
      () async {
        await _boot();
        ctrl.startExpedition();
        _loseStage();

        expect(ctrl.failed.value, isTrue);
        expect(ctrl.completed.value, isFalse);
        expect(ctrl.awaitingNextStage.value, isFalse);
        expect(gameCtrl.treasureMapCompleted.value, isFalse);
      },
    );

    test('thua ở stage 4 → không tính là hoàn thành chuyến', () async {
      await _boot();
      ctrl.startExpedition();
      for (var stage = 1; stage <= 3; stage++) {
        _winStage();
        ctrl.nextStage();
      }
      expect(ctrl.stageIndex.value, 4);

      _loseStage();
      expect(ctrl.failed.value, isTrue);
      expect(gameCtrl.treasureMapCompleted.value, isFalse);
    });

    test('bản đồ đã tiêu KHÔNG được hoàn lại khi thua', () async {
      await _boot(maps: 1);
      ctrl.startExpedition();
      _loseStage();
      expect(
        gameCtrl.treasureMapCount.value,
        0,
        reason: 'thua vẫn mất bản đồ — nếu không thì retry vô hạn',
      );
    });
  });

  group('cô lập với mode khác', () {
    test('ended ở mode khác không đụng state chuyến', () async {
      await _boot();
      ctrl.startExpedition();

      gameCtrl.startSideMode(GameMode.zen);
      gameCtrl.checkEnd(true);

      expect(ctrl.failed.value, isFalse);
      expect(ctrl.completed.value, isFalse);
      expect(ctrl.awaitingNextStage.value, isFalse);
    });
  });
}
