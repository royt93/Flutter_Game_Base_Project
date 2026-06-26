import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/screens/world_map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 22.5 — World Map rương báu: vị trí, thưởng tất định, mở khoá, anti-exploit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    g = Get.put(GameController());
  });
  tearDown(Get.reset);

  group('chestLevelOf — xử lý cả thế giới không đều', () {
    test('TG1=10, TG8=145, TG10=185', () {
      expect(chestLevelOf(kWorlds[0]), 10); // 1..20
      expect(chestLevelOf(kWorlds[7]), 145); // 141..150
      expect(chestLevelOf(kWorlds[9]), 185); // 171..200
    });
    test('kChestLevels = 1 rương / thế giới', () {
      expect(kChestLevels.length, kWorlds.length);
    });
  });

  group('chestCoinReward — tất định + dải hợp lý', () {
    test('cùng world → cùng thưởng (no Random), ~50..250', () {
      for (final w in kWorlds) {
        final r = chestCoinReward(w.index);
        expect(r, chestCoinReward(w.index));
        expect(r, greaterThanOrEqualTo(50));
        expect(r, lessThanOrEqualTo(250));
      }
    });
  });

  group('chestRewardOf — tất định, loại hợp lệ', () {
    test('cùng world → cùng reward; mọi world có loại hợp lệ', () {
      for (final w in kWorlds) {
        final r = chestRewardOf(w.index);
        expect(r.kind, chestRewardOf(w.index).kind);
        expect(r.amount, chestRewardOf(w.index).amount);
        expect(r.amount, greaterThan(0));
        if (r.kind == ChestRewardKind.coins) {
          expect(r.amount, chestCoinReward(w.index));
        } else {
          expect(r.amount, 1); // booster 1 cái
        }
      }
    });
  });

  group('mở khoá + nhận (anti-exploit)', () {
    test('chưa hoàn thành 80% → khoá, claim trả null', () {
      final w = kWorlds[0]; // 1..20
      expect(g.isChestUnlocked(w), isFalse);
      expect(g.claimWorldChest(w), isNull);
      expect(g.isChestClaimed(w.index), isFalse);
    });

    test(
      'đạt 80% → mở; claim trao ĐÚNG loại thưởng, lần 2 null (idempotent)',
      () {
        final w = kWorlds[0]; // size 20 → cần 16 màn xong (unlockedLevel>16)
        g.unlockedLevel.value = 17; // màn 1..16 đã xong
        expect(g.isChestUnlocked(w), isTrue);

        final expected = chestRewardOf(w.index);
        final coinsBefore = g.coins.value;
        final hammerBefore = g.boosterHammer.value;
        final movesBefore = g.boosterMoves.value;

        final got = g.claimWorldChest(w);
        expect(got, isNotNull);
        expect(got!.kind, expected.kind);
        expect(got.amount, expected.amount);
        switch (expected.kind) {
          case ChestRewardKind.coins:
            expect(g.coins.value, coinsBefore + expected.amount);
          case ChestRewardKind.hammer:
            expect(g.boosterHammer.value, hammerBefore + expected.amount);
          case ChestRewardKind.moves:
            expect(g.boosterMoves.value, movesBefore + expected.amount);
        }
        expect(g.isChestClaimed(w.index), isTrue);

        // claim lại → null, không trao thêm (chống farm reload)
        final coins2 = g.coins.value;
        final hammer2 = g.boosterHammer.value;
        expect(g.claimWorldChest(w), isNull);
        expect(g.coins.value, coins2);
        expect(g.boosterHammer.value, hammer2);
      },
    );
  });

  group('mini-boss (W22.5)', () {
    test('kMiniBossWorlds = thế giới chẵn [2,4,6,8,10]', () {
      expect(kMiniBossWorlds, [2, 4, 6, 8, 10]);
    });

    test('startBoss hpScale<1 → HP thấp hơn boss thường cùng stage', () {
      g.startBoss(1);
      final full = g.bossMaxHp.value;
      g.startBoss(1, hpScale: 0.5);
      expect(g.bossMaxHp.value, lessThan(full));
      expect(g.bossMaxHp.value, (full * 0.5).round());
    });

    test('mini-boss là side-mode → không trừ mạng', () {
      final lives = g.lives.value;
      g.startBoss(1, hpScale: 0.5);
      expect(g.isSideMode, isTrue);
      expect(g.lives.value, lives);
    });
  });

  group('WorldMapScreen widget', () {
    testWidgets('mount → render chest + mini-boss + avatar không crash', (
      tester,
    ) async {
      g.unlockedLevel.value = 45; // tới world 3 → world 2 mini-boss reachable
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('vi', 'VN'),
          fallbackLocale: const Locale('en', 'US'),
          home: const WorldMapScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(WorldMapScreen), findsOneWidget);
      expect(
        find.byIcon(Icons.card_giftcard_rounded, skipOffstage: false),
        findsWidgets,
      );
      expect(
        find.byIcon(Icons.coronavirus_rounded, skipOffstage: false),
        findsWidgets,
      );
      expect(
        find.byIcon(Icons.person_rounded, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets(
      'W23.3 — avatar walking: render giữa & sau animation, không crash',
      (tester) async {
        g.unlockedLevel.value = 8; // current=8 → đi từ node 7 → 8
        await tester.pumpWidget(
          GetMaterialApp(
            translations: AppTranslations(),
            locale: const Locale('vi', 'VN'),
            fallbackLocale: const Locale('en', 'US'),
            home: const WorldMapScreen(),
          ),
        );
        // giữa animation (750ms): avatar đang "đi"
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byIcon(Icons.person_rounded, skipOffstage: false),
          findsOneWidget,
        );
        // sau khi settle: vẫn render, không lỗi animation
        await tester.pump(const Duration(milliseconds: 800));
        expect(
          find.byIcon(Icons.person_rounded, skipOffstage: false),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  test(
    'resetProgress xoá chest claimed → nhận lại được sau khi đủ điều kiện',
    () async {
      final w = kWorlds[0];
      g.unlockedLevel.value = 20;
      g.claimWorldChest(w);
      expect(g.isChestClaimed(w.index), isTrue);

      await g.resetProgress();
      expect(g.isChestClaimed(w.index), isFalse);
    },
  );
}
