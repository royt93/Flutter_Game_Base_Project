import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/game/neon_jewel_game.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 17.1 — Sinh tồn "Triều dâng": nước dâng theo thời gian (tăng tốc), clear
/// dưới nước đẩy lùi, chạm đỉnh = thua. Thay cơ chế reskin TimeAttack cũ.
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

  group('Wave 17.1 — tideRiseRate (pure)', () {
    test('bắt đầu = kTideBaseRate, TĂNG dần theo thời gian sống', () {
      expect(tideRiseRate(0), kTideBaseRate);
      expect(tideRiseRate(10), greaterThan(tideRiseRate(0)));
      expect(tideRiseRate(60), greaterThan(tideRiseRate(10)));
      // tuyến tính: rate(t) = base + accel*t
      expect(tideRiseRate(100), closeTo(kTideBaseRate + kTideAccel * 100, 1e-9));
    });
  });

  group('Wave 17.1 — engine mount (triều dâng thật)', () {
    NeonJewelGame mk() => NeonJewelGame(
          controller: g,
          rows: 8,
          cols: 8,
          colorCount: 6,
          onGameEnd: (_) {},
          muteSfx: true,
          boardSeed: 7,
        );

    test('mở màn: chưa có nước (tideLevel 0) + có nước đi', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        g.startSurvival();
        final game = mk();
        game.onGameResize(Vector2(560, 800));
        await game.onLoad();
        expect(g.tideLevel.value, 0.0);
        expect(game.hasPossibleMove, isTrue);
      });
    });

    test('để yên (không clear) → nước DÂNG → tideLevel tăng', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        g.startSurvival();
        final game = mk();
        game.onGameResize(Vector2(560, 800));
        await game.onLoad();
        // tua ~30 giây không thao tác
        for (int i = 0; i < 300; i++) {
          game.update(0.1);
        }
        expect(g.tideLevel.value, greaterThan(0.0),
            reason: 'nước phải dâng theo thời gian');
      });
    });

    test('không đẩy lùi → cuối cùng NGẬP (tideOverflow=true)', () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        g.startSurvival();
        final game = mk();
        game.onGameResize(Vector2(560, 800));
        await game.onLoad();
        // tua đủ lâu để nước chạm đỉnh (rate tăng tốc → hội tụ)
        for (int i = 0; i < 4000 && !g.tideOverflow.value; i++) {
          game.update(0.1);
        }
        expect(g.tideOverflow.value, isTrue,
            reason: 'để yên thì nước phải dâng tới đỉnh = thua');
      });
    });
  });
}
