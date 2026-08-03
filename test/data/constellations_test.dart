import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/constellations.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Constellations Logic & Idempotency', () {
    test('isConstellationLit trả về true khi totalStars >= starsRequired', () {
      final c = kConstellations.first; // starsRequired = 20
      expect(isConstellationLit(c, 0), isFalse);
      expect(isConstellationLit(c, 19), isFalse);
      expect(isConstellationLit(c, 20), isTrue);
      expect(isConstellationLit(c, 50), isTrue);
    });

    test('claimStarSeedForConstellation có tính idempotent (chỉ trao 1 lần duy nhất)', () {
      final storage = StorageService(null);
      Get.put(storage);
      final gameCtrl = GameController();
      Get.put(gameCtrl);

      expect(gameCtrl.starSeedCount.value, equals(0));
      expect(gameCtrl.isStarSeedClaimed(0), isFalse);

      // Lần 1 claim -> starSeedCount tăng lên 1
      gameCtrl.claimStarSeedForConstellation(0);
      expect(gameCtrl.starSeedCount.value, equals(1));
      expect(gameCtrl.isStarSeedClaimed(0), isTrue);

      // Lần 2 claim cùng index -> starSeedCount không đổi
      gameCtrl.claimStarSeedForConstellation(0);
      expect(gameCtrl.starSeedCount.value, equals(1));

      // Claim index 1 -> starSeedCount tăng lên 2
      gameCtrl.claimStarSeedForConstellation(1);
      expect(gameCtrl.starSeedCount.value, equals(2));
      expect(gameCtrl.isStarSeedClaimed(1), isTrue);

      Get.reset();
    });
  });
}
