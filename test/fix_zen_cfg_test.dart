import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fix 3: Zen mode dùng đúng LevelConfig riêng, không fallthrough sang
/// màn campaign cũ → HUD không còn hiện sai objective/target.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    g = Get.put(GameController());
  });

  tearDown(Get.reset);

  group('buildZenLevel (pure data)', () {
    test('index là kZenLevelIndex', () {
      expect(buildZenLevel().index, kZenLevelIndex);
    });

    test('objective là score (không phải order/collect)', () {
      expect(buildZenLevel().objective, ObjectiveType.score);
    });

    test('moves = 999 (vô hạn thực tế)', () {
      expect(buildZenLevel().moves, 999);
    });

    test('targetScore = max (người chơi không bao giờ đạt)', () {
      expect(buildZenLevel().targetScore, 1 << 28);
    });
  });

  group('startZen → level getter trả đúng cfg (Fix 3)', () {
    test('level.index == kZenLevelIndex sau startZen', () {
      g.startLevel(1); // đặt currentLevel = 1 trước
      g.startZen();
      expect(g.level.index, kZenLevelIndex);
    });

    test(
      'level.index KHÔNG phải kLevels[0].index (không dùng campaign cũ)',
      () {
        g.startLevel(5); // currentLevel = 5 trước
        g.startZen();
        expect(g.level.index, isNot(kLevels[4].index));
      },
    );

    test('level.objective là score — HUD không hiện order/collect goals', () {
      g.startLevel(1);
      g.startZen();
      expect(g.level.objective, ObjectiveType.score);
    });

    test('isZen = true sau startZen', () {
      g.startZen();
      expect(g.isZen.value, isTrue);
    });

    test('checkEnd luôn null trong zen (không tự kết thúc)', () {
      g.startZen();
      // Tích điểm bất kỳ
      g.addScore(999999, 10);
      expect(g.checkEnd(), isNull);
    });

    test(
      'khi startLevel sau zen, _zenCfg bị reset → level quay về campaign',
      () {
        g.startZen();
        expect(g.level.index, kZenLevelIndex);

        g.startLevel(3);
        expect(g.isZen.value, isFalse);
        expect(g.level.index, kLevels[2].index);
      },
    );
  });
}
