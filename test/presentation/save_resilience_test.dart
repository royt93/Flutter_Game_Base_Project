import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// X18 + X19 — cả hai đều là bug **bảo trì**, không phải bug logic:
/// - X18: `_load()` hydrate ~25 hệ từ storage; 24 chỗ có guard, 1 chỗ quên →
///   save hỏng làm `onInit` ném và app không boot được.
/// - X19: `resetProgress()` từng là danh sách tay ~55 key và đã trôi lại phía
///   sau qua 5 round.
///
/// Sửa từng bug lẻ không giải quyết gì — 2 test dưới đây MỚI là phần sửa thật:
/// chúng đỏ khi người sau quên guard hoặc quên phân loại key mới.
Future<GameController> _boot(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  return Get.put(GameController(), permanent: true);
}

void main() {
  setUp(Get.reset);

  group('X18 save hỏng không được chặn boot', () {
    // Mỗi giá trị dưới đây từng (hoặc có thể) làm `jsonDecode`/cast trong
    // `_load()` ném. Đường vào có thật: import backup từ nguồn không tin cậy,
    // app bị kill giữa `setString`, hoặc hạ version sau khi format đổi.
    const garbage = <String, String>{
      'chuỗi không phải JSON': 'không-phải-json',
      'JSON object thay vì list': '{"a":1}',
      'list sai kiểu phần tử': '[1, 2, "x"]',
      'list rỗng hợp lệ': '[]',
      'JSON cụt': '[{"typeId":"ember",',
      'null literal': 'null',
    };

    garbage.forEach((label, raw) {
      test('star_owned_pets = $label -> vẫn boot, bỏ pet hỏng', () async {
        final ctrl = await _boot({
          StorageKeys.starOwnedPets: raw,
          StorageKeys.coins: 777,
          StorageKeys.unlockedLevel: 42,
        });
        expect(ctrl.starOwnedPets, isEmpty);
        // State khác phải nguyên vẹn — không được "mất trắng vì 1 key hỏng".
        expect(ctrl.coins.value, 777);
        expect(ctrl.unlockedLevel.value, 42);
      });
    });

    test('list nửa hợp lệ -> giữ phần tử đúng, bỏ phần tử hỏng', () async {
      final ctrl = await _boot({
        StorageKeys.starOwnedPets:
            '[{"typeId":"ember","hatchedAtMs":1}, 5, {"typeId":"ember"}, '
            '{"typeId":"khong_ton_tai","hatchedAtMs":2}]',
      });
      // 1 hợp lệ; `5` sai kiểu; thiếu `hatchedAtMs`; typeId không có trong
      // `kStarPetTypes` (đã bị gỡ khỏi bảng const ở bản mới).
      expect(ctrl.starOwnedPets.length, 1);
      expect(ctrl.starOwnedPets.single.typeId, 'ember');
    });

    test('ghi lại bản đã lọc, lần boot sau không phải parse lại rác', () async {
      await _boot({
        StorageKeys.starOwnedPets: '[{"typeId":"ember","hatchedAtMs":1}, 5]',
      });
      final persisted = StorageService.to.getString(StorageKeys.starOwnedPets);
      expect(persisted, isNotNull);
      expect(persisted, isNot(contains(', 5')));
    });
  });

  group('X19 reset progress phải xoá sạch', () {
    // Tính chất kiểm được **tổng quát**: sau reset, storage phải không phân
    // biệt được với một bản cài mới. Không assert "key phải biến mất" — cuối
    // `resetProgress()` có `_load()` + `_checkLoginStreak()` +
    // `checkDailyQuestRollover()`, chúng ghi lại một loạt key với giá trị khởi
    // tạo (mốc tuần/mùa/ngày hiện tại). Đó là đúng, thứ sai duy nhất là key
    // còn giữ **giá trị cũ**.
    //
    // Đây là phần khoá lại X19: hệ meta mới thêm ở round sau, nếu quên phân
    // loại, sẽ tự động làm test này đỏ mà không ai phải nhớ cập nhật gì.
    test('reset xong storage không phân biệt được với cài mới', () async {
      await _boot({});
      final fresh = StorageService.to.exportAll();
      Get.reset();

      final ctrl = await _boot({
        StorageKeys.coins: 999,
        StorageKeys.unlockedLevel: 50,
        StorageKeys.starDustCount: 40,
        StorageKeys.starOwnedPets: '[{"typeId":"ember","hatchedAtMs":1}]',
        StorageKeys.lastPetCollectTimestampMs: 123456,
        StorageKeys.starSeedCount: 3,
        StorageKeys.claimedStarSeedMask: 7,
        StorageKeys.activeSkyAura: 'nebula',
        StorageKeys.streakFreezeCount: 2,
        StorageKeys.bossRushBestStreak: 9,
        StorageKeys.savedPuzzles: '["abc"]',
        StorageKeys.raidBossTotalDamage: 5000,
        StorageKeys.remixBest(7): 1234,
        StorageKeys.highScore(3): 999,
        StorageKeys.star(3): 3,
      });
      await ctrl.resetProgress();

      final after = StorageService.to.exportAll();
      final leaked = {
        for (final entry in after.entries)
          if (!GameController.keepOnReset.contains(entry.key) &&
              fresh[entry.key] != entry.value)
            entry.key: entry.value,
      };
      expect(
        leaked,
        isEmpty,
        reason:
            'Các key sau vẫn khác bản cài mới sau Reset Progress: $leaked. '
            'Nếu key đó thật sự KHÔNG phải tiến độ, thêm vào whitelist '
            '`GameController.keepOnReset` kèm lý do; ngược lại đây là bug X19 '
            'tái diễn.',
      );
    });

    test('các key bản cũ bỏ sót đều về mặc định', () async {
      // Gieo đúng những key mà bản cũ BỎ SÓT, cộng vài key đại diện.
      final ctrl = await _boot({
        StorageKeys.coins: 999,
        StorageKeys.unlockedLevel: 50,
        StorageKeys.starDustCount: 40,
        StorageKeys.starOwnedPets: '[{"typeId":"ember","hatchedAtMs":1}]',
        StorageKeys.lastPetCollectTimestampMs: 123456,
        StorageKeys.starSeedCount: 3,
        StorageKeys.claimedStarSeedMask: 7,
        StorageKeys.activeSkyAura: 'nebula',
        StorageKeys.streakFreezeCount: 2,
        StorageKeys.bossRushBestStreak: 9,
        StorageKeys.savedPuzzles: '["abc"]',
        StorageKeys.raidBossTotalDamage: 5000,
        StorageKeys.remixBest(7): 1234,
        StorageKeys.highScore(3): 999,
        StorageKeys.star(3): 3,
      });

      await ctrl.resetProgress();
      final store = StorageService.to;

      // Danh sách này chính là bảng "bỏ sót" trong X19 — giữ tường minh để
      // diff của lần sửa sau đọc được ngay nó bảo vệ cái gì.
      expect(store.getInt(StorageKeys.coins), 0);
      expect(store.getInt(StorageKeys.unlockedLevel, def: 1), 1);
      expect(store.getInt(StorageKeys.starDustCount), 0);
      expect(store.getString(StorageKeys.starOwnedPets), isNull);
      expect(store.getInt(StorageKeys.lastPetCollectTimestampMs), 0);
      expect(store.getInt(StorageKeys.starSeedCount), 0);
      expect(store.getInt(StorageKeys.claimedStarSeedMask), 0);
      expect(store.getString(StorageKeys.activeSkyAura), isNull);
      expect(store.getInt(StorageKeys.streakFreezeCount), 0);
      expect(store.getInt(StorageKeys.bossRushBestStreak), 0);
      expect(store.getString(StorageKeys.savedPuzzles), isNull);
      expect(store.getInt(StorageKeys.raidBossTotalDamage), 0);
      expect(store.getInt(StorageKeys.remixBest(7)), 0);
      expect(store.getInt(StorageKeys.highScore(3)), 0);
      expect(store.getInt(StorageKeys.star(3)), 0);
    });

    test('state trong bộ nhớ cũng về mặc định, không chỉ trên đĩa', () async {
      final ctrl = await _boot({
        StorageKeys.coins: 999,
        StorageKeys.starDustCount: 40,
        StorageKeys.starOwnedPets: '[{"typeId":"ember","hatchedAtMs":1}]',
        StorageKeys.starSeedCount: 3,
        StorageKeys.streakFreezeCount: 2,
      });
      expect(ctrl.starOwnedPets, isNotEmpty);

      await ctrl.resetProgress();

      expect(ctrl.coins.value, 0);
      expect(ctrl.starDust.value, 0);
      expect(ctrl.starSeedCount.value, 0);
      expect(ctrl.streakFreezeCount.value, 0);
      expect(
        ctrl.starOwnedPets,
        isEmpty,
        reason:
            'pet cũ còn trong bộ nhớ sẽ tiếp tục sinh coin idle sau khi người '
            'chơi đã bấm "xoá sạch"',
      );
    });

    test('cài đặt và trạng thái đã-xem-rồi được giữ lại', () async {
      final ctrl = await _boot({
        StorageKeys.coins: 999,
        StorageKeys.localeCode: 'vi',
        StorageKeys.bgmVolume: 0.3,
        StorageKeys.hapticsEnabled: false,
        StorageKeys.hasSeenFtue: true,
        StorageKeys.hasShownReviewPrompt: true,
        StorageKeys.playerName: 'roy',
      });

      await ctrl.resetProgress();
      final store = StorageService.to;

      expect(store.getString(StorageKeys.localeCode), 'vi');
      expect(store.getDouble(StorageKeys.bgmVolume), 0.3);
      expect(store.getBool(StorageKeys.hapticsEnabled, def: true), isFalse);
      expect(store.getBool(StorageKeys.hasSeenFtue), isTrue);
      expect(store.getBool(StorageKeys.hasShownReviewPrompt), isTrue);
      expect(store.getString(StorageKeys.playerName), 'roy');
      expect(ctrl.coins.value, 0);
    });
  });
}
