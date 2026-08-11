import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// X24 — `registerPop()` chạy MỖI lần người chơi tap một nhóm hợp lệ, tức là
/// hot path lõi của cả game. Mỗi lần nó gọi `StorageService.setX` là một lần
/// platform channel + ghi đĩa thật (xem `storage_service.dart`), xen giữa
/// animation nổ.
///
/// Đo baseline trước khi sửa: **6 lần ghi cho 1 cú tap**
/// (`totalGemsPopped`, `weeklyGoalProgress`, `clanContribWeek`,
/// `clanContribTotal`, và 2 `setString` của `_persistDailyQuests`).
///
/// Test này là **phép đo**, không phải test hành vi — nó thay cho việc profile
/// tay trên device: đếm được tất định, lặp lại được, và đỏ ngay nếu round sau
/// ai đó nối thêm hệ mới vào hot path.
/// Instance `SharedPreferences` thật đang dùng — giữ lại để test đọc thẳng
/// xuống đĩa, bỏ qua mọi buffer trong bộ nhớ của [StorageService].
late SharedPreferences _prefs;

Future<GameController> _boot() async {
  SharedPreferences.setMockInitialValues({});
  _prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(_prefs), permanent: true);
  final ctrl = Get.put(GameController(), permanent: true);
  ctrl.startLevel(1);
  return ctrl;
}

void main() {
  setUp(Get.reset);

  test('registerPop: 1 cú tap ghi tối đa 1 lần xuống storage', () async {
    final ctrl = await _boot();
    final store = StorageService.to;

    final before = store.platformWrites;
    ctrl.registerPop(100, groupSize: 5);
    final writes = store.platformWrites - before;

    expect(
      writes,
      lessThanOrEqualTo(1),
      reason:
          'Mỗi cú tap ghi $writes lần xuống SharedPreferences. Trước X24 là 6. '
          'Đây là hot path — mọi lần ghi đều là platform channel xen giữa '
          'animation nổ.',
    );
  });

  test('chuỗi combo dài: ghi không tăng tuyến tính theo số tap', () async {
    final ctrl = await _boot();
    final store = StorageService.to;

    // Lượt 1 còn ghi thật vì combo tăng dần mở khoá cosmetic (burst style /
    // combo-text style theo `maxComboEver`) và chạm mốc Sticker Album — đó là
    // sự kiện có thật, không phải counter spam, nên KHÔNG đệm.
    for (var i = 0; i < 20; i++) {
      ctrl.registerPop(100, groupSize: 3);
    }

    // Lượt 2: `resetCombo()` mỗi nhịp (tap ngoài combo window — trường hợp
    // phổ biến nhất khi chơi thật) nên `maxComboEver` không tăng nữa, không
    // mở khoá thêm cosmetic. Giờ chỉ còn counter thuần: đây là trạng thái ổn
    // định mà X24 nhắm tới.
    final before = store.platformWrites;
    for (var i = 0; i < 20; i++) {
      ctrl.resetCombo();
      ctrl.registerPop(100, groupSize: 3);
    }
    final writes = store.platformWrites - before;

    expect(
      writes,
      lessThanOrEqualTo(1),
      reason:
          '20 cú tap ở trạng thái ổn định ghi $writes lần. Trước X24 là ~154 '
          '(7 lần/tap) — combo càng dài càng giật.',
    );
  });

  test('flush ở checkEnd: state đã cộng trong ván phải xuống đĩa', () async {
    final ctrl = await _boot();
    final store = StorageService.to;

    ctrl.registerPop(100, groupSize: 7);
    final gemsInMemory = ctrl.totalGemsPopped.value;
    expect(gemsInMemory, 7);

    ctrl.checkEnd(true);
    // `flush()` là async và `checkEnd` cố ý KHÔNG await (nó được gọi từ engine
    // Flame, đổi sang async sẽ lan ra toàn bộ call chain). Nhường 1 nhịp để
    // ghi hoàn tất — đúng như ở app thật.
    await Future<void>.delayed(Duration.zero);

    // Đọc thẳng SharedPreferences, bỏ qua mọi buffer trong bộ nhớ — đây là
    // thứ còn lại nếu app bị kill ngay sau đó.
    final persisted = _prefs.getInt(StorageKeys.totalGemsPopped);
    expect(
      persisted,
      gemsInMemory,
      reason: 'checkEnd phải flush; nếu không, app bị kill là mất tiến độ ván',
    );
    expect(store.platformWrites, greaterThan(0));
  });

  test('mua booster vẫn ghi ngay, không đi qua buffer', () async {
    final ctrl = await _boot();
    final store = StorageService.to;
    ctrl.coins.value = 1000;

    final before = store.platformWrites;
    expect(ctrl.buyBomb(), isTrue);

    expect(
      store.platformWrites - before,
      greaterThanOrEqualTo(2),
      reason:
          'Mua bán KHÔNG nằm trên hot path và là giao dịch thật — phải xuống '
          'đĩa ngay, không được gom buffer',
    );
  });
}
