import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/combo_milestones.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F17 Combo Bank — tiền tệ thứ ba, nối 14 side-mode đang là silo.
///
/// Ba thứ đáng khoá nhất:
/// 1. **Cộng ở MỌI mode** — kể cả Zen và Puzzle Lab. Loại trừ bất kỳ mode nào
///    là phá đúng mục đích tồn tại của nó.
/// 2. **Giới hạn số lần/ngày** — nếu token mua được mọi thứ không giới hạn thì
///    nhịp hằng ngày/hằng tuần sụp (rủi ro số 2 trong task).
/// 3. **Lùi theo Undo** — cùng lý do với [[X17]]: vòng "nổ tới mốc combo →
///    undo → nổ lại" là máy in token.
late GameController ctrl;

int get _today =>
    DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;

Future<void> _boot({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('kiếm token', () {
    test('chạm mốc combo -> cộng token', () async {
      await _boot();
      expect(ctrl.comboTokens.value, 0);

      ctrl.triggerComboMilestone(kComboMilestones.first);

      expect(ctrl.comboTokens.value, GameController.tokensPerComboMilestone);
    });

    test('cộng ở MỌI mode, không loại trừ mode nào', () async {
      await _boot();
      var expected = 0;
      for (final mode in GameMode.values) {
        ctrl.mode.value = mode;
        ctrl.triggerComboMilestone(kComboMilestones.first);
        expected += GameController.tokensPerComboMilestone;
        expect(
          ctrl.comboTokens.value,
          expected,
          reason: 'mode $mode không cộng token — phá đúng mục đích của F17',
        );
      }
    });

    test('nhiều mốc liên tiếp -> cộng dồn', () async {
      await _boot();
      for (final m in kComboMilestones) {
        ctrl.triggerComboMilestone(m);
      }
      expect(
        ctrl.comboTokens.value,
        kComboMilestones.length * GameController.tokensPerComboMilestone,
      );
    });

    test('nạp lại từ save', () async {
      await _boot(prefs: {StorageKeys.comboTokens: 42});
      expect(ctrl.comboTokens.value, 42);
    });

    test('save sai kiểu -> về 0, không ném ([[X28]])', () async {
      await _boot(prefs: {StorageKeys.comboTokens: 'rac'});
      expect(ctrl.comboTokens.value, 0);
    });
  });

  group('Undo lùi token ([[X17]])', () {
    test('token về đúng mốc trước nước đi, cả trong bộ nhớ lẫn trên đĩa', () async {
      await _boot();
      ctrl.saveUndoCounters();
      final before = ctrl.comboTokens.value;

      ctrl.triggerComboMilestone(kComboMilestones.first);
      expect(ctrl.comboTokens.value, greaterThan(before));

      ctrl.restoreUndoCounters();
      await StorageService.to.flush();

      expect(ctrl.comboTokens.value, before);
      expect(
        StorageService.to.getInt(StorageKeys.comboTokens),
        before,
        reason: 'kill app ngay sau undo vẫn không được giữ token đã farm',
      );
    });

    test('vòng nổ-undo lặp lại không bơm được token', () async {
      await _boot();
      for (var i = 0; i < 5; i++) {
        ctrl.saveUndoCounters();
        ctrl.triggerComboMilestone(kComboMilestones.first);
        ctrl.restoreUndoCounters();
      }
      expect(ctrl.comboTokens.value, 0);
    });
  });

  group('đổi nhiệm vụ hằng ngày', () {
    test('không đủ token -> không đổi được', () async {
      await _boot(prefs: {StorageKeys.comboTokens: 0});
      expect(ctrl.canRerollDailyQuests, isFalse);
      expect(ctrl.rerollDailyQuests(), isFalse);
    });

    test('đủ token -> đổi được, trừ đúng giá, quest đổi khác', () async {
      await _boot(prefs: {StorageKeys.comboTokens: 100});
      final before = ctrl.dailyQuests.map((q) => q.nameKey).toList();

      expect(ctrl.rerollDailyQuests(), isTrue);

      expect(
        ctrl.comboTokens.value,
        100 - GameController.tokenCostRerollQuest,
      );
      expect(ctrl.dailyQuests.map((q) => q.nameKey).toList(), isNot(before));
    });

    test('đổi xong tiến độ reset — không giữ tiến độ của bộ cũ', () async {
      await _boot(prefs: {StorageKeys.comboTokens: 100});
      ctrl.dailyQuestProgress.assignAll(const [5, 5, 5]);

      ctrl.rerollDailyQuests();

      expect(ctrl.dailyQuestProgress, [0, 0, 0]);
      expect(ctrl.dailyQuestClaimed, isEmpty);
    });

    test('1 lần/ngày: lần thứ hai không ăn', () async {
      await _boot(prefs: {StorageKeys.comboTokens: 100});
      expect(ctrl.rerollDailyQuests(), isTrue);
      final after = ctrl.comboTokens.value;

      expect(ctrl.canRerollDailyQuests, isFalse);
      expect(ctrl.rerollDailyQuests(), isFalse);
      expect(ctrl.comboTokens.value, after);
    });

    test('mốc ngày cũ -> hôm nay đổi lại được', () async {
      await _boot(prefs: {
        StorageKeys.comboTokens: 100,
        StorageKeys.tokenRerollQuestDay: _today - 1,
      });
      expect(ctrl.canRerollDailyQuests, isTrue);
    });
  });

  group('mua lượt Raid Boss', () {
    test('không đủ token -> không mua được', () async {
      await _boot(prefs: {StorageKeys.comboTokens: 0});
      expect(ctrl.canBuyRaidAttempt, isFalse);
      expect(ctrl.buyRaidAttempt(), isFalse);
    });

    test('mua được -> trừ token, đánh dấu ngày', () async {
      await _boot(prefs: {StorageKeys.comboTokens: 100});
      expect(ctrl.buyRaidAttempt(), isTrue);
      expect(
        ctrl.comboTokens.value,
        100 - GameController.tokenCostRaidAttempt,
      );
      expect(ctrl.bonusRaidAttemptsToday, 1);
    });

    test('1 lần/ngày', () async {
      await _boot(prefs: {StorageKeys.comboTokens: 100});
      ctrl.buyRaidAttempt();
      final after = ctrl.comboTokens.value;

      expect(ctrl.buyRaidAttempt(), isFalse);
      expect(ctrl.comboTokens.value, after);
    });

    test('sang ngày mới -> lượt mua hết hiệu lực', () async {
      await _boot(prefs: {
        StorageKeys.comboTokens: 100,
        StorageKeys.tokenRaidDay: _today - 1,
      });
      expect(ctrl.bonusRaidAttemptsToday, 0);
      expect(ctrl.canBuyRaidAttempt, isTrue);
    });
  });

  group('mua bản đồ Treasure Map', () {
    test('mua được -> +1 bản đồ, trừ token', () async {
      await _boot(prefs: {StorageKeys.comboTokens: 100});
      final before = ctrl.treasureMapCount.value;

      expect(ctrl.buyTreasureMap(), isTrue);

      expect(ctrl.treasureMapCount.value, before + 1);
      expect(
        ctrl.comboTokens.value,
        100 - GameController.tokenCostTreasureMap,
      );
    });

    test('1 lần/ngày', () async {
      await _boot(prefs: {StorageKeys.comboTokens: 100});
      ctrl.buyTreasureMap();
      final after = ctrl.treasureMapCount.value;

      expect(ctrl.buyTreasureMap(), isFalse);
      expect(ctrl.treasureMapCount.value, after);
    });

    test('không đủ token -> không mua, không cộng bản đồ', () async {
      await _boot(prefs: {StorageKeys.comboTokens: 1});
      final before = ctrl.treasureMapCount.value;
      expect(ctrl.buyTreasureMap(), isFalse);
      expect(ctrl.treasureMapCount.value, before);
    });
  });

  group('an toàn kinh tế', () {
    test('token không bao giờ âm sau khi tiêu', () async {
      await _boot(prefs: {StorageKeys.comboTokens: 100});
      ctrl.rerollDailyQuests();
      ctrl.buyRaidAttempt();
      ctrl.buyTreasureMap();
      expect(ctrl.comboTokens.value, greaterThanOrEqualTo(0));
    });

    test('mọi đường tiêu đều persist ngay, không đợi flush', () async {
      await _boot(prefs: {StorageKeys.comboTokens: 100});
      ctrl.buyTreasureMap();
      expect(
        StorageService.to.getInt(StorageKeys.comboTokens),
        ctrl.comboTokens.value,
      );
    });

    test('reset tiến độ XOÁ token ([[X19]])', () async {
      await _boot(prefs: {StorageKeys.comboTokens: 500});
      expect(
        GameController.keepOnReset.contains(StorageKeys.comboTokens),
        isFalse,
        reason: 'token là tiến độ, không phải cài đặt — phải bị xoá khi reset',
      );

      await ctrl.resetProgress();

      expect(ctrl.comboTokens.value, 0);
      expect(StorageService.to.getInt(StorageKeys.comboTokens), 0);
    });
  });
}
