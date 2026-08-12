import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/clan.dart';
import 'package:pop_star_blast/data/weekly_goal.dart';
import 'package:pop_star_blast/logic/next_action.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// I84 — phần **nối dây**: `GameController.nextActions()` đọc state thật rồi
/// giao cho [rankNextActions].
///
/// Luật xếp hạng đã có test riêng (`test/logic/next_action_test.dart`). File
/// này chỉ kiểm đúng một thứ, nhưng là thứ hàm thuần không thể tự bảo vệ:
/// **có đọc đúng cờ từ state không**. Nối nhầm `weeklyGoalReady` vào cờ của
/// clan chẳng hạn — hàm thuần vẫn xếp hạng đúng, mà gợi ý thì sai.
late GameController ctrl;

Future<void> _boot([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);
}

List<NextActionKind> _kinds() => ctrl.nextActions().map((a) => a.kind).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('tài khoản mới: chỉ thưởng ngày + campaign', () async {
    await _boot();
    expect(_kinds(), [
      NextActionKind.dailyReward,
      NextActionKind.campaignLevel,
    ]);
  });

  test('campaign mang đúng số màn kế tiếp', () async {
    await _boot({StorageKeys.unlockedLevel: 37});
    // Dọn bớt việc gấp hơn để campaign chắc chắn còn chỗ trong 3 slot.
    // Riêng pool clan có thể tự đạt ngưỡng nhờ NPC bot (I66) mà người chơi
    // chưa đóng góp gì, nên nó vẫn có thể chiếm 1 slot — chấp nhận được.
    ctrl.claimDaily();
    ctrl.claimSpin();

    final campaign = ctrl.nextActions().firstWhere(
      (a) => a.kind == NextActionKind.campaignLevel,
      orElse: () => throw StateError(
        'campaign bị đẩy khỏi danh sách: ${ctrl.nextActions()}',
      ),
    );
    expect(campaign.value, 37);
  });

  test('đã nhận thưởng ngày -> không còn gợi ý nó', () async {
    await _boot();
    expect(ctrl.claimDaily(), isNotNull);
    expect(_kinds(), isNot(contains(NextActionKind.dailyReward)));
  });

  test('mục tiêu tuần đạt mà chưa nhận -> có gợi ý', () async {
    await _boot({StorageKeys.unlockedLevel: 50});
    ctrl.addWeeklyGoalProgress(weeklyGoalTarget);
    expect(_kinds(), contains(NextActionKind.weeklyGoal));
  });

  test('nhận thưởng tuần rồi -> hết gợi ý đó', () async {
    await _boot({StorageKeys.unlockedLevel: 50});
    ctrl.addWeeklyGoalProgress(weeklyGoalTarget);
    expect(ctrl.claimWeeklyGoalReward(), isTrue);
    expect(_kinds(), isNot(contains(NextActionKind.weeklyGoal)));
  });

  test('đủ sao mở rương Star Road -> có gợi ý, nhận xong thì hết', () async {
    await _boot({StorageKeys.unlockedLevel: 50});
    // 2 màn x 3 sao = 6 sao: chỉ đạt mốc đầu (5), chưa tới mốc kế (15).
    // Gieo nhiều hơn thì nhận rương 0 xong vẫn còn rương 1 claim được.
    for (var id = 1; id <= 2; id++) {
      await StorageService.to.setInt(StorageKeys.star(id), 3);
    }
    ctrl.onInit(); // nạp lại totalStars như khi quay về Home

    expect(_kinds(), contains(NextActionKind.starRoadChest));
    expect(ctrl.claimChest(0), isTrue);
    // Mốc kế tiếp chưa đạt -> không còn gợi ý rương nữa.
    expect(_kinds(), isNot(contains(NextActionKind.starRoadChest)));
  });

  test('người chơi mới vẫn bị ẩn hệ meta dù đủ điều kiện', () async {
    await _boot({StorageKeys.unlockedLevel: 1});
    ctrl.addWeeklyGoalProgress(weeklyGoalTarget);
    final kinds = _kinds();
    expect(kinds, isNot(contains(NextActionKind.weeklyGoal)));
    expect(kinds, contains(NextActionKind.campaignLevel));
  });

  test('không bao giờ vượt trần số gợi ý', () async {
    await _boot({StorageKeys.unlockedLevel: 50});
    ctrl.addWeeklyGoalProgress(weeklyGoalTarget);
    ctrl.addClanContribution(clanGoalTarget);
    expect(ctrl.nextActions().length, lessThanOrEqualTo(kMaxNextActions));
  });

  test('gọi nhiều lần không đổi kết quả (không có tác dụng phụ)', () async {
    await _boot({StorageKeys.unlockedLevel: 20});
    final first = ctrl.nextActions();
    final second = ctrl.nextActions();
    expect(second, first);
  });
}
