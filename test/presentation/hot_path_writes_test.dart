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

  /// X29 — buffer của X24 từng **nuốt** mọi lần ghi thẳng sau đó.
  ///
  /// Phát hiện qua `integration_test/undo_test.dart` trên máy thật: sau khi
  /// undo, `totalGemsPopped` trong bộ nhớ về 0 đúng như X17 mong đợi, nhưng
  /// đĩa vẫn 3 — vì `restoreUndoCounters()` gọi `setInt` trong khi
  /// `_buffer[key]` vẫn giữ giá trị đã nổ, nên `_raw` đọc ra bản đệm cũ và cú
  /// `flush()` kế tiếp ghi đè luôn xuống đĩa.
  ///
  /// Hệ quả rộng hơn X17: mọi key từng đi qua hot path rồi được ghi thẳng —
  /// hoàn tác, reset, mua bán, import — đều mất tác dụng theo cách y hệt.
  group('X29: ghi thẳng huỷ bản đang đệm', () {
    const key = StorageKeys.totalGemsPopped;

    test('setInt sau setIntBuffered: đọc ra giá trị mới', () async {
      await _boot();
      final store = StorageService.to;

      await store.setIntBuffered(key, 99);
      await store.setInt(key, 7);

      expect(
        store.getInt(key),
        7,
        reason: 'bản đệm cũ không được che giá trị vừa ghi thẳng',
      );
    });

    test('flush sau đó KHÔNG hồi sinh giá trị đã đệm', () async {
      await _boot();
      final store = StorageService.to;

      await store.setIntBuffered(key, 99);
      await store.setInt(key, 7);
      await store.flush();

      expect(store.getInt(key), 7);
      expect(
        _prefs.getInt(key),
        7,
        reason: 'đĩa phải là 7; 99 nghĩa là flush đã ghi đè bản ghi thẳng',
      );
    });

    test('setString cũng vậy', () async {
      await _boot();
      final store = StorageService.to;
      const skey = StorageKeys.dailyQuestProgress;

      await store.setStringBuffered(skey, 'cu');
      await store.setString(skey, 'moi');
      await store.flush();

      expect(store.getString(skey), 'moi');
      expect(_prefs.getString(skey), 'moi');
    });

    test('undo: counter đời lùi cả trong bộ nhớ lẫn trên đĩa', () async {
      // Bản thu nhỏ của ca integration đã bắt được lỗi.
      final ctrl = await _boot();
      final store = StorageService.to;

      final before = ctrl.totalGemsPopped.value;
      ctrl.saveUndoCounters();
      ctrl.registerPop(100, groupSize: 5);
      expect(ctrl.totalGemsPopped.value, greaterThan(before));

      ctrl.restoreUndoCounters();
      await store.flush();

      expect(ctrl.totalGemsPopped.value, before);
      expect(
        store.getInt(key),
        before,
        reason: 'kill app ngay sau undo vẫn không được giữ lại số đã farm',
      );
      expect(_prefs.getInt(key) ?? 0, before);
    });
  });
}
