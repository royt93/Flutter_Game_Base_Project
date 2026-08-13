import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/pigments.dart';
import 'package:pop_star_blast/logic/craft_points.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F19 Pigment Fusion.
///
/// AC của task viết "tái dùng craft point" như thể đã có sẵn tiền tệ. Thực tế
/// `craft_points.dart` chỉ là **hàm thuần đo cell còn sót** — đo xong đổi ngay
/// thành booster nếu đủ ngưỡng, dưới ngưỡng thì mất trắng. Không có số dư nào
/// để tiêu. F19 phải dựng số dư đó, và nhóm "số dư craft point" bên dưới khoá
/// đúng chỗ ấy.
late GameController ctrl;

Future<void> _boot({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);
}

Pigment _p(String id) => kPigments.firstWhere((p) => p.id == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('bảng dữ liệu', () {
    test('mọi công thức trỏ tới pigment có thật', () {
      for (final result in kPigmentRecipes.values) {
        expect(
          kPigments.any((p) => p.id == result),
          isTrue,
          reason: 'công thức ra "$result" nhưng pigment đó không tồn tại',
        );
      }
    });

    test('mọi nguyên liệu trong công thức đều có thật', () {
      for (final key in kPigmentRecipes.keys) {
        for (final id in key.split('|')) {
          expect(kPigments.any((p) => p.id == id), isTrue, reason: id);
        }
      }
    });

    test('khoá công thức đã chuẩn hoá (đã sort)', () {
      for (final key in kPigmentRecipes.keys) {
        final parts = key.split('|');
        expect(
          key,
          recipeKey(parts[0], parts[1]),
          reason: 'khoá "$key" chưa chuẩn hoá — đổi chỗ nguyên liệu sẽ trượt',
        );
      }
    });

    test('pigment fusion KHÔNG mua được bằng xu hay achievement', () {
      // Nếu mua được thì công thức chỉ là đường vòng dài hơn.
      for (final p in kPigments.where((p) => p.fusionOnly)) {
        expect(p.coinPrice, isNull, reason: p.id);
        expect(p.unlockAchievementId, isNull, reason: p.id);
        expect(p.isFree, isFalse, reason: '${p.id} không được tính là miễn phí');
      }
    });

    test('mọi pigment fusion đều có ít nhất 1 công thức ra nó', () {
      for (final p in kPigments.where((p) => p.fusionOnly)) {
        expect(
          kPigmentRecipes.values.contains(p.id),
          isTrue,
          reason: '${p.id} không pha ra được bằng cách nào -> không lấy được',
        );
      }
    });

    test('không công thức nào ra pigment mua được', () {
      for (final result in kPigmentRecipes.values) {
        expect(_p(result).fusionOnly, isTrue, reason: result);
      }
    });
  });

  group('tra công thức', () {
    test('đổi chỗ nguyên liệu vẫn ra cùng kết quả', () {
      final key = kPigmentRecipes.keys.first;
      final parts = key.split('|');
      expect(
        fusionResultFor(parts[0], parts[1]),
        fusionResultFor(parts[1], parts[0]),
      );
    });

    test('pha một màu với chính nó -> null', () {
      expect(fusionResultFor('aqua', 'aqua'), isNull);
    });

    test('tổ hợp không có công thức -> null', () {
      expect(fusionResultFor('aqua', 'khong_ton_tai'), isNull);
    });
  });

  group('số dư craft point', () {
    test('mặc định 0', () async {
      await _boot();
      expect(ctrl.craftPoints.value, 0);
    });

    test('cộng và persist', () async {
      await _boot();
      ctrl.addCraftPoints(5);
      expect(ctrl.craftPoints.value, 5);
      expect(StorageService.to.getInt(StorageKeys.craftPoints), 5);
    });

    test('cộng số âm/0 -> không đổi', () async {
      await _boot(prefs: {StorageKeys.craftPoints: 7});
      ctrl.addCraftPoints(0);
      ctrl.addCraftPoints(-5);
      expect(ctrl.craftPoints.value, 7);
    });
  });

  group('pha', () {
    /// Mở khoá sẵn 2 nguyên liệu của công thức đầu + đủ craft point.
    Future<List<String>> bootWithFirstRecipe({int points = 99}) async {
      final key = kPigmentRecipes.keys.first;
      final parts = key.split('|');
      await _boot(prefs: {
        StorageKeys.craftPoints: points,
        StorageKeys.unlockedPigments: parts.join(','),
      });
      return parts;
    }

    test('đủ điều kiện -> ra pigment mới, trừ đúng craft point', () async {
      final parts = await bootWithFirstRecipe();
      final expected = kPigmentRecipes[recipeKey(parts[0], parts[1])];

      final got = ctrl.fusePigments(parts[0], parts[1]);

      expect(got, expected);
      expect(ctrl.unlockedPigmentIds, contains(expected));
      expect(ctrl.craftPoints.value, 99 - kFusionCraftCost);
    });

    test('nguyên liệu KHÔNG bị mất sau khi pha', () async {
      // Mất nguyên liệu thì không ai dám thử — mà mục đích là khuyến khích thử.
      final parts = await bootWithFirstRecipe();
      ctrl.fusePigments(parts[0], parts[1]);

      for (final id in parts) {
        expect(ctrl.isPigmentUnlocked(_p(id)), isTrue, reason: id);
      }
    });

    test('thiếu craft point -> không pha, KHÔNG trừ gì', () async {
      final parts = await bootWithFirstRecipe(points: kFusionCraftCost - 1);

      expect(ctrl.fusePigments(parts[0], parts[1]), isNull);
      expect(ctrl.craftPoints.value, kFusionCraftCost - 1);
      final expected = kPigmentRecipes[recipeKey(parts[0], parts[1])];
      expect(
        ctrl.unlockedPigmentIds,
        isNot(contains(expected)),
        reason: 'thiếu 1 craft point vẫn không được nhận pigment',
      );
    });

    test('chưa sở hữu nguyên liệu -> không pha, không trừ craft point', () async {
      await _boot(prefs: {StorageKeys.craftPoints: 99});
      final parts = kPigmentRecipes.keys.first.split('|');

      // 'aqua' free nên luôn có; nguyên liệu kia thì chưa.
      expect(ctrl.fusePigments(parts[0], parts[1]), isNull);
      expect(ctrl.craftPoints.value, 99);
    });

    test('tổ hợp không có công thức -> không trừ craft point', () async {
      await _boot(prefs: {
        StorageKeys.craftPoints: 99,
        StorageKeys.unlockedPigments: 'aqua,coral,mint',
      });

      expect(ctrl.fusePigments('aqua', 'khong_ton_tai'), isNull);
      expect(ctrl.craftPoints.value, 99);
    });

    test('pha lại công thức đã có -> không trừ craft point lần hai', () async {
      final parts = await bootWithFirstRecipe();
      ctrl.fusePigments(parts[0], parts[1]);
      final after = ctrl.craftPoints.value;

      expect(ctrl.fusePigments(parts[0], parts[1]), isNull);
      expect(ctrl.craftPoints.value, after);
    });

    test('pigment pha ra dùng gán màu được ngay', () async {
      final parts = await bootWithFirstRecipe();
      final got = ctrl.fusePigments(parts[0], parts[1])!;

      expect(ctrl.setGemColorOverride(0, got), isTrue);
      expect(ctrl.gemColorOverrides[0], got);
    });
  });

  group('sổ công thức', () {
    test('ghi lại công thức đã khám phá và persist', () async {
      final parts = kPigmentRecipes.keys.first.split('|');
      await _boot(prefs: {
        StorageKeys.craftPoints: 99,
        StorageKeys.unlockedPigments: parts.join(','),
      });

      ctrl.fusePigments(parts[0], parts[1]);

      expect(ctrl.discoveredRecipes, contains(recipeKey(parts[0], parts[1])));
      expect(
        StorageService.to.getString(StorageKeys.discoveredRecipes),
        contains(recipeKey(parts[0], parts[1])),
      );
    });

    test('công thức không còn trong bảng -> bị loại khi nạp', () async {
      await _boot(prefs: {
        StorageKeys.discoveredRecipes: 'cong_thuc_da_bi_go',
      });
      expect(ctrl.discoveredRecipes, isEmpty);
    });

    test('mặc định chưa khám phá gì', () async {
      await _boot();
      expect(ctrl.discoveredRecipes, isEmpty);
    });
  });

  group('mỗi ván đúng MỘT phần thưởng', () {
    const t = GameController.craftPointThreshold;

    test('đủ ngưỡng -> booster, KHÔNG gom điểm', () {
      expect(craftOutcomeFor(t, t), CraftOutcome.booster);
      expect(craftOutcomeFor(t + 99, t), CraftOutcome.booster);
    });

    test('dưới ngưỡng nhưng > 0 -> gom điểm', () {
      // Trước F19 phần này mất trắng.
      for (var p = 1; p < t; p++) {
        expect(craftOutcomeFor(p, t), CraftOutcome.bankPoints, reason: '$p');
      }
    });

    test('0 điểm -> không gì cả', () {
      expect(craftOutcomeFor(0, t), CraftOutcome.none);
      expect(craftOutcomeFor(-5, t), CraftOutcome.none);
    });
  });
}
