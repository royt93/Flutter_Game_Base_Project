import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/logic/gem_data.dart';
import 'package:neon_jewels/presentation/controllers/achievement_controller.dart';
import 'package:neon_jewels/presentation/controllers/battle_pass_controller.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/season_controller.dart';
import 'package:neon_jewels/presentation/controllers/temple_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    c = Get.put(GameController());
  });
  tearDown(Get.reset);

  group('Wave 8.2 — Boss điểm yếu màu (đã wire vào sát thương)', () {
    test('đánh TRÚNG màu điểm yếu → gấp đôi sát thương', () {
      c.startBoss(1);
      expect(c.bossWeakColor.value, 0); // stage 1 → cyan (index 0)
      final hp0 = c.bossHp.value;
      c.registerClear(GemColor.cyan, false); // trúng màu yếu
      c.addScore(3, 1); // base 3*12 + 1*8 = 44 → ×2 = 88 (combo 1 < ngưỡng)
      expect(c.bossHp.value, hp0 - 88);
    });

    test('đánh SAI màu điểm yếu → KHÔNG gấp đôi', () {
      c.startBoss(1); // yếu = cyan
      final hp0 = c.bossHp.value;
      c.registerClear(GemColor.magenta, false); // sai màu
      c.addScore(3, 1); // 44, không nhân
      expect(c.bossHp.value, hp0 - 44);
    });

    test('trúng màu yếu + combo lớn → ×4', () {
      c.startBoss(1);
      final hp0 = c.bossHp.value;
      c.registerClear(GemColor.cyan, false);
      // base (3*12 + 4*8)=68 → ×2 (yếu) ×2 (combo) = 272
      c.addScore(3, GameController.bossWeakCombo);
      expect(c.bossHp.value, (hp0 - 272).clamp(0, c.bossMaxHp.value));
    });

    test('cờ điểm yếu tiêu thụ sau 1 nhịp (không cộng dồn)', () {
      c.startBoss(1);
      c.registerClear(GemColor.cyan, false);
      c.addScore(3, 1); // tiêu thụ cờ
      final hp1 = c.bossHp.value;
      c.addScore(3, 1); // nhịp kế: không trúng yếu nữa → chỉ 44
      expect(c.bossHp.value, hp1 - 44);
    });
  });

  group('Wave 8.2 — resetProgress xoá sạch (đĩa + RAM)', () {
    test('reset đưa xu/booster/mạng về mặc định cài đầu', () async {
      c.addCoins(500);
      c.grantHammer(5);
      c.lives.value = 1;
      c.totalWins.value = 10;
      c.unlockedLevel.value = 7;
      await c.resetProgress();
      expect(c.coins.value, 50, reason: 'về 50 xu tặng mặc định');
      expect(c.boosterHammer.value, 2, reason: 'booster về mặc định');
      expect(c.lives.value, GameController.maxLives);
      expect(c.totalWins.value, 0);
      expect(c.unlockedLevel.value, 1);
    });

    test('reset xoá state in-memory của controller permanent (chống nhận lại)',
        () async {
      final bp = Get.put(BattlePassController(c), permanent: true);
      bp.xp.value = 500;
      bp.claimed.add(0);
      final sc = Get.put(SeasonController(c), permanent: true);
      sc.points.value = 200;
      sc.claimed.add('${sc.idx}_0');
      final ac = Get.put(AchievementController(c), permanent: true);
      ac.claimed.add('first_win');
      final tc = Get.put(TempleController(c), permanent: true);
      tc.builtTier['core'] = 3;

      await c.resetProgress();

      expect(bp.xp.value, 0);
      expect(bp.claimed, isEmpty);
      expect(sc.points.value, 0);
      expect(sc.claimed, isEmpty);
      expect(ac.claimed, isEmpty);
      expect(tc.builtTier.values.every((t) => t == 0), isTrue);
    });

    test('reset ghi đĩa trống → đọc lại không khôi phục giá trị cũ', () async {
      c.addCoins(999);
      await c.resetProgress();
      final store = StorageService.to;
      // coins key đã bị xoá → getInt trả default truyền vào (chứng tỏ không còn 999)
      expect(store.getInt(StorageKeys.coins, def: -1), -1);
      expect(store.getInt(StorageKeys.bHammer, def: -1), -1);
      expect(store.getInt(StorageKeys.lives, def: -1), -1);
    });
  });
}
