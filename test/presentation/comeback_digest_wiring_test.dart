import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/weekly_goal.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// I86 — phần nối dây. Luật "nói gì" đã có test thuần; ở đây kiểm thứ hàm
/// thuần không thấy: controller có tra đúng mốc rương kế tiếp, và số ngày vắng
/// có lấy từ đồng hồ đã kẹp không.
late GameController ctrl;

Future<void> _boot([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);
}

List<String> _keys(int daysAway) =>
    ctrl.comebackDigest(daysAway).map((l) => l.key).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('vắng nhiều ngày -> dòng đầu là số ngày', () async {
    await _boot();
    expect(_keys(9).first, 'digest_days_away');
  });

  test('mốc rương kế tiếp tra đúng theo tổng sao', () async {
    await _boot();
    for (var id = 1; id <= 3; id++) {
      await StorageService.to.setInt(StorageKeys.star(id), 2);
    }
    ctrl.onInit(); // nạp lại totalStars = 6

    final line = ctrl
        .comebackDigest(3)
        .firstWhere((l) => l.key == 'digest_stars_to_chest');
    // Mốc kế sau 6 sao là 15 -> còn 9.
    expect(line.params['n'], '9');
  });

  test('đã qua hết mốc rương -> không nhắc rương', () async {
    await _boot();
    for (var id = 1; id <= 30; id++) {
      await StorageService.to.setInt(StorageKeys.star(id), 3);
    }
    ctrl.onInit(); // 90 sao, vượt mốc cao nhất

    expect(_keys(3), isNot(contains('digest_stars_to_chest')));
  });

  test('mục tiêu tuần dở dang -> nhắc phần còn lại', () async {
    await _boot();
    ctrl.addWeeklyGoalProgress(100);
    final line = ctrl
        .comebackDigest(2)
        .firstWhere((l) => l.key == 'digest_weekly_left');
    expect(line.params['n'], '${weeklyGoalTarget - 100}');
  });

  test('chưa đóng góp tuần này -> không nhắc', () async {
    await _boot();
    expect(_keys(2), isNot(contains('digest_weekly_left')));
  });

  test('không quá 3 dòng dù nhiều thứ dở dang', () async {
    await _boot();
    ctrl.addWeeklyGoalProgress(50);
    for (var id = 1; id <= 3; id++) {
      await StorageService.to.setInt(StorageKeys.star(id), 2);
    }
    ctrl.onInit();
    expect(ctrl.comebackDigest(7).length, lessThanOrEqualTo(3));
  });

  test('lastComebackDaysAway lấy từ đồng hồ đã kẹp, không âm', () async {
    // Gieo lastOpenDay ở TƯƠNG LAI xa: đồng hồ kẹp không lùi được nên hiệu số
    // phải là 0, không phải số âm — số âm sẽ in ra "vắng -5 ngày".
    await _boot({StorageKeys.lastOpenDay: 99999});
    ctrl.checkComebackBonus();
    expect(ctrl.lastComebackDaysAway, lessThanOrEqualTo(0));
    expect(
      _keys(ctrl.lastComebackDaysAway),
      isNot(contains('digest_days_away')),
    );
  });

  test('lần chạy đầu (chưa có lastOpenDay) -> 0 ngày vắng', () async {
    await _boot();
    ctrl.checkComebackBonus();
    expect(ctrl.lastComebackDaysAway, 0);
  });
}
