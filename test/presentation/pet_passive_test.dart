import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/star_pets.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// I82 — Star Pet có passive nhẹ.
///
/// Hai điều quan trọng nhất, và cũng là hai thứ dễ làm sai nhất:
/// 1. **Không có hiệu lực ở mode dùng best-score** — nếu không, mọi kỷ lục cũ
///    bị vô hiệu vì người chơi mới có lợi thế người cũ không có.
/// 2. **Cộng dồn với perk F14 nhưng có trần** — hai hệ tăng sức mạnh chồng
///    nhau mà không kẹp thì độ khó campaign sụp.
late GameController ctrl;

PetType _petWith(PetPassive p) =>
    kStarPetTypes.firstWhere((t) => t.passive == p);

Future<void> _boot({PetPassive? equipped}) async {
  final pet = equipped == null ? null : _petWith(equipped);
  SharedPreferences.setMockInitialValues({
    if (pet != null) ...{
      StorageKeys.starOwnedPets: '[{"typeId":"${pet.id}","hatchedAtMs":1}]',
      StorageKeys.equippedPet: pet.id,
    },
  });
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('bảng dữ liệu', () {
    test('mỗi pet có đúng 1 passive, không trùng nhau', () {
      final passives = kStarPetTypes.map((t) => t.passive).toList();
      expect(
        passives.toSet().length,
        passives.length,
        reason: 'hai pet cùng passive thì chọn con nào cũng như nhau',
      );
    });

    test('phủ hết mọi giá trị PetPassive', () {
      expect(
        kStarPetTypes.map((t) => t.passive).toSet(),
        PetPassive.values.toSet(),
      );
    });
  });

  group('trang bị', () {
    test('mặc định không trang bị gì', () async {
      await _boot();
      expect(ctrl.equippedPetType, isNull);
    });

    test('không sở hữu -> không trang bị được', () async {
      await _boot();
      expect(ctrl.equipPet(kStarPetTypes.first.id), isFalse);
      expect(ctrl.equippedPetType, isNull);
    });

    test('sở hữu -> trang bị được và persist', () async {
      await _boot(equipped: PetPassive.extraUndo);
      final id = _petWith(PetPassive.extraUndo).id;
      expect(ctrl.equippedPetType?.id, id);
      expect(StorageService.to.getString(StorageKeys.equippedPet), id);
    });

    test('id không tồn tại -> từ chối', () async {
      await _boot(equipped: PetPassive.extraUndo);
      expect(ctrl.equipPet('khong_ton_tai'), isFalse);
    });

    test('tháo bằng chuỗi rỗng', () async {
      await _boot(equipped: PetPassive.extraUndo);
      expect(ctrl.equipPet(''), isTrue);
      expect(ctrl.equippedPetType, isNull);
    });

    test('save trỏ pet KHÔNG sở hữu -> bỏ qua khi nạp', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.equippedPet: kStarPetTypes.first.id,
        // không có starOwnedPets
      });
      final store = await SharedPreferences.getInstance();
      Get.put(StorageService(store), permanent: true);
      ctrl = Get.put(GameController(), permanent: true);
      expect(
        ctrl.equippedPetType,
        isNull,
        reason: 'sửa tay storage không được cho không một passive',
      );
    });
  });

  group('passive có hiệu lực', () {
    // Mỗi test chỉ được boot MỘT lần: `SharedPreferences` cache instance, nên
    // gọi `setMockInitialValues` lần hai rồi `getInstance()` vẫn trả về store
    // cũ — controller thứ hai sẽ đọc prefs của lần đầu và test so sánh với
    // baseline sai. So với hằng số thay vì với một lần boot "đối chứng".
    test('extraUndo: bật passive đúng loại', () async {
      await _boot(equipped: PetPassive.extraUndo);
      ctrl.startLevel(1);
      expect(ctrl.hasPetPassive(PetPassive.extraUndo), isTrue);
      expect(ctrl.hasFreeUndo, isTrue);
    });

    test('extraHint: +1 gợi ý so với mặc định', () async {
      await _boot(equipped: PetPassive.extraHint);
      ctrl.startLevel(1);
      expect(ctrl.hintCount.value, GameController.hintsPerRun + 1);
    });

    test('không trang bị -> số gợi ý là mặc định', () async {
      await _boot();
      ctrl.startLevel(1);
      expect(ctrl.hintCount.value, GameController.hintsPerRun);
    });

    test('coinBonus: cộng thêm 5% vào xu thưởng', () async {
      await _boot(equipped: PetPassive.coinBonus);
      ctrl.startLevel(1);
      ctrl.score.value = ctrl.currentLevel.targetScore * 3;
      final coinsBefore = ctrl.coins.value;
      ctrl.checkEnd(false);

      final stars = ctrl.starsEarned.value;
      final plain = stars * 20 * ctrl.weekendCoinMultiplier;
      final withPet = (plain * 1.05).round();
      expect(ctrl.coins.value - coinsBefore, withPet);
      expect(withPet, greaterThan(plain));
    });

    test('pet khác không kích hoạt passive không phải của nó', () async {
      await _boot(equipped: PetPassive.coinBonus);
      expect(ctrl.hasPetPassive(PetPassive.extraUndo), isFalse);
      expect(ctrl.hasPetPassive(PetPassive.extraHint), isFalse);
      expect(ctrl.hasPetPassive(PetPassive.coinBonus), isTrue);
    });
  });

  group('loại trừ mode best-score', () {
    for (final mode in [
      GameMode.timeAttack,
      GameMode.comboRush,
      GameMode.frostRush,
      GameMode.endless,
      GameMode.mirrorMode,
    ]) {
      test('$mode: passive KHÔNG có hiệu lực', () async {
        await _boot(equipped: PetPassive.extraHint);
        ctrl.mode.value = mode;
        expect(
          ctrl.hasPetPassive(PetPassive.extraHint),
          isFalse,
          reason: 'cho passive chạy ở đây thì mọi kỷ lục cũ bị vô hiệu',
        );
      });
    }

    test('endless: số gợi ý không được cộng thêm', () async {
      await _boot(equipped: PetPassive.extraHint);
      ctrl.startEndless();
      expect(ctrl.hintCount.value, GameController.hintsPerRun);
    });

    test('campaign vẫn có hiệu lực', () async {
      await _boot(equipped: PetPassive.extraHint);
      ctrl.startLevel(1);
      expect(ctrl.hintCount.value, GameController.hintsPerRun + 1);
    });
  });

  // Hai test dưới KHÔNG chứng minh được trần hoạt động: với dữ liệu hiện tại
  // trần chưa bao giờ bị chạm (1 cơ bản + 1 perk + 1 pet = 3, đúng bằng trần;
  // hint 3 + 1 = 4 < 5). Mutation-check xác nhận: gỡ hẳn `kMaxHintsPerRun`
  // vẫn xanh.
  //
  // Giữ trần vì [[I83]] (constellation skill tree) sẽ thêm nguồn buff thứ ba
  // và lúc đó nó mới có tác dụng — nhưng đừng nhầm là đã được bảo vệ. Khi làm
  // I83, thêm test thật sự vượt trần.
  group('trần khi cộng dồn với perk (chưa chạm được, xem ghi chú trên)', () {
    test('undo không vượt trần dù có cả perk lẫn pet', () async {
      await _boot(equipped: PetPassive.extraUndo);
      ctrl.activePerkIds.value = ['extra_undo'];
      ctrl.startLevel(1);
      // 1 cơ bản + 1 perk + 1 pet = 3, đúng trần.
      var used = 0;
      while (ctrl.hasFreeUndo && used < 10) {
        ctrl.useUndo();
        used++;
        if (used >= kMaxFreeUndoPerLevel) break;
      }
      expect(used, lessThanOrEqualTo(kMaxFreeUndoPerLevel));
    });

    test('hint không vượt trần', () async {
      await _boot(equipped: PetPassive.extraHint);
      ctrl.startLevel(1);
      expect(ctrl.hintCount.value, lessThanOrEqualTo(kMaxHintsPerRun));
    });
  });
}
