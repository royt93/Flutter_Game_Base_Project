import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 26.1 — HUD chủ đạo per-mode + nhạc per-mode.
/// Kiểm 2 getter thuần logic (không cần Flame/UI):
///  - [GameController.gravityMovesUntilFlip]: đếm ngược lượt tới lần lật bàn.
///  - [GameController.bgmTrack]: map mode → track nhạc nền (3 nhóm).
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

  group('W26.1 — gravityMovesUntilFlip', () {
    test(
      'khởi đầu = kGravityFlipEvery, giảm dần mỗi lượt, reset sau lần lật',
      () {
        g.startGravity();
        // count = 0 → còn đủ chu kỳ.
        expect(g.gravityMovesUntilFlip, kGravityFlipEvery);

        // Sau 1 lượt: còn kGravityFlipEvery - 1.
        g.consumeGravityFlip();
        expect(g.gravityMovesUntilFlip, kGravityFlipEvery - 1);

        // Đủ kGravityFlipEvery lượt → vừa lật xong → đếm ngược quay lại đầy chu kỳ.
        for (var i = 1; i < kGravityFlipEvery; i++) {
          g.consumeGravityFlip();
        }
        expect(g.gravityMovesUntilFlip, kGravityFlipEvery);
      },
    );

    test('lần lật xảy ra đúng mốc kGravityFlipEvery (đảo gravityDir)', () {
      g.startGravity();
      final dir0 = g.gravityDir.value;
      for (var i = 0; i < kGravityFlipEvery - 1; i++) {
        expect(g.consumeGravityFlip(), isFalse); // chưa tới mốc
      }
      expect(g.consumeGravityFlip(), isTrue); // đúng mốc → lật
      expect(g.gravityDir.value, isNot(dir0));
    });
  });

  group('W26.1 — bgmTrack map mode → track', () {
    test('campaign (mặc định) = track 0', () {
      g.startLevel(1);
      expect(g.bgmTrack, 0);
    });

    test('mode căng (Boss/Survival) = track 1', () {
      g.startBoss(1);
      expect(g.bgmTrack, 1);
      g.startSurvival();
      expect(g.bgmTrack, 1);
    });

    test('mode nhịp/vui (Rhythm/ColorRush/Soda/Daily) = track 2', () {
      g.startRhythm();
      expect(g.bgmTrack, 2);
      g.startColorRush();
      expect(g.bgmTrack, 2);
      g.startSoda();
      expect(g.bgmTrack, 2);
      g.startDaily();
      expect(g.bgmTrack, 2);
    });

    test('Gravity/Labyrinth = track 0 (không thuộc 2 nhóm trên)', () {
      g.startGravity();
      expect(g.bgmTrack, 0);
      g.startLabyrinth();
      expect(g.bgmTrack, 0);
    });
  });
}
