import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/data/side_mode_records.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/side_mode_record_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 28.1 — Gravity/ColorRush hard variant: bật Thử Thách (sau Gold) làm
/// bàn lật/đổi màu nóng DÀY HƠN (không chỉ giảm lượt như W25.1 đã có sẵn).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameController g;
  late SideModeRecordController rec;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    g = Get.put(GameController());
    rec = Get.put(SideModeRecordController(g));
  });
  tearDown(Get.reset);

  group('W28.1 — Gravity flip nhanh hơn khi bật Thử Thách', () {
    test('tắt Thử Thách → lật mỗi kGravityFlipEvery lượt (mặc định)', () {
      g.startGravity();
      for (int i = 0; i < kGravityFlipEvery - 1; i++) {
        expect(g.consumeGravityFlip(), isFalse);
      }
      expect(g.consumeGravityFlip(), isTrue);
    });

    test('bật Thử Thách → lật mỗi (kGravityFlipEvery - 2) lượt', () {
      rec.claimedTier[SideModeKind.gravity] = RecordTier.gold.index;
      rec.toggleHardVariant(SideModeKind.gravity);
      g.startGravity();
      final flipEvery = kGravityFlipEvery - 2;
      for (int i = 0; i < flipEvery - 1; i++) {
        expect(g.consumeGravityFlip(), isFalse);
      }
      expect(g.consumeGravityFlip(), isTrue);
    });

    test('gravityMovesUntilFlip đồng bộ với flipEvery đang dùng', () {
      rec.claimedTier[SideModeKind.gravity] = RecordTier.gold.index;
      rec.toggleHardVariant(SideModeKind.gravity);
      g.startGravity();
      expect(g.gravityMovesUntilFlip, kGravityFlipEvery - 2);
      g.consumeGravityFlip();
      expect(g.gravityMovesUntilFlip, kGravityFlipEvery - 3);
    });
  });

  group('W28.1 — ColorRush đổi màu nóng nhanh hơn khi bật Thử Thách', () {
    test('tắt Thử Thách → đổi màu mỗi kColorRushChangeEvery lượt', () {
      g.startColorRush();
      final startHot = g.colorRushHot.value;
      for (int i = 0; i < kColorRushChangeEvery - 1; i++) {
        g.tickColorRush();
      }
      expect(g.colorRushHot.value, startHot);
      g.tickColorRush();
      expect(g.colorRushHot.value, isNot(startHot));
    });

    test('bật Thử Thách → đổi màu mỗi (kColorRushChangeEvery - 1) lượt', () {
      rec.claimedTier[SideModeKind.colorRush] = RecordTier.gold.index;
      rec.toggleHardVariant(SideModeKind.colorRush);
      g.startColorRush();
      final startHot = g.colorRushHot.value;
      final changeEvery = kColorRushChangeEvery - 1;
      for (int i = 0; i < changeEvery - 1; i++) {
        g.tickColorRush();
      }
      expect(g.colorRushHot.value, startHot);
      g.tickColorRush();
      expect(g.colorRushHot.value, isNot(startHot));
    });
  });
}
