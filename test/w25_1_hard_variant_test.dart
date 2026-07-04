import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/data/side_mode_records.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/side_mode_record_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 25.1 Phase 1C — "Thử Thách" (hard variant, tự chọn sau Gold): đổi lượt
/// lấy thưởng cao hơn. KHÔNG đụng win-streak/level-unlock/lives.
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

  group('W25.1 — toggleHardVariant chỉ mở sau Gold', () {
    test('chưa đạt Gold → toggle không có tác dụng (vẫn false)', () {
      expect(rec.tierOf(SideModeKind.colorRush), isNot(RecordTier.gold));
      expect(rec.toggleHardVariant(SideModeKind.colorRush), isFalse);
      expect(rec.hardVariantEnabled(SideModeKind.colorRush), isFalse);
    });

    test('đạt Gold → toggle bật/tắt được, persist qua storage', () {
      rec.claimedTier[SideModeKind.colorRush] = RecordTier.gold.index;
      expect(rec.toggleHardVariant(SideModeKind.colorRush), isTrue);
      expect(rec.hardVariantEnabled(SideModeKind.colorRush), isTrue);

      final rec2 = SideModeRecordController(g)..onInit();
      expect(rec2.hardVariantEnabled(SideModeKind.colorRush), isTrue);

      expect(rec.toggleHardVariant(SideModeKind.colorRush), isFalse); // tắt lại
      expect(rec.hardVariantEnabled(SideModeKind.colorRush), isFalse);
    });
  });

  group(
    'W25.1 — ảnh hưởng lượt (_resetRunState) + thưởng (discountSideModeReward)',
    () {
      test('bật Thử Thách ColorRush → khởi động với ít lượt hơn', () {
        rec.claimedTier[SideModeKind.colorRush] = RecordTier.gold.index;
        rec.toggleHardVariant(SideModeKind.colorRush);
        g.startColorRush();
        expect(g.movesLeft.value, (kColorRushMoves * 0.85).ceil());
        expect(g.movesLeft.value, lessThan(kColorRushMoves));
      });

      test('tắt Thử Thách → lượt bình thường (không đổi hành vi cũ)', () {
        g.startColorRush();
        expect(g.movesLeft.value, kColorRushMoves);
      });

      test('bật Thử Thách → thưởng xu ×1.5 so với tắt (cùng base)', () {
        const base = 40;
        g.startColorRush();
        final normal = g.discountSideModeReward(base);

        rec.claimedTier[SideModeKind.colorRush] = RecordTier.gold.index;
        rec.toggleHardVariant(SideModeKind.colorRush);
        g.startColorRush();
        final withHv = g.discountSideModeReward(base);

        expect(withHv, (normal * 1.5).round());
      });

      test(
        'màn campaign KHÔNG bị ảnh hưởng dù có hardVariant rác trong storage',
        () {
          rec.claimedTier[SideModeKind.colorRush] = RecordTier.gold.index;
          rec.toggleHardVariant(SideModeKind.colorRush); // bật cho ColorRush
          g.startLevel(1); // campaign — activeKind null → không áp dụng
          expect(g.movesLeft.value, kLevels[0].moves);
          expect(g.isSideMode, isFalse);
        },
      );
    },
  );

  group('W25.1 — resetProgress dọn sạch hardVariant', () {
    test('resetProgress xoá cờ hardVariant về false', () async {
      rec.claimedTier[SideModeKind.colorRush] = RecordTier.gold.index;
      rec.toggleHardVariant(SideModeKind.colorRush);
      expect(rec.hardVariantEnabled(SideModeKind.colorRush), isTrue);

      await g.resetProgress();
      expect(rec.hardVariantEnabled(SideModeKind.colorRush), isFalse);
    });
  });
}
