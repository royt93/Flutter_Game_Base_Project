import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/battle_pass.dart';
import 'package:neon_jewels/presentation/controllers/battle_pass_controller.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/screens/battle_pass_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 23 — Daily Quest mở rộng: pool đa dạng hơn + thưởng hoàn-thành-cả-bộ (1 lần/ngày).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;
  late BattlePassController bp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    g = Get.put(GameController());
    bp = Get.put(BattlePassController(g));
  });
  tearDown(Get.reset);

  group('pool mở rộng', () {
    test('kQuestPool nhiều tier hơn (>=14) + đủ 5 loại', () {
      expect(kQuestPool.length, greaterThanOrEqualTo(14));
      expect(
        kQuestPool.map((q) => q.type).toSet().length,
        QuestType.values.length,
      );
    });
    test('dailyQuests luôn 3 quest KHÁC loại (nhiều ngày)', () {
      for (var d = 0; d < 60; d++) {
        final qs = dailyQuests(d);
        expect(qs.length, 3);
        expect(qs.map((q) => q.type).toSet().length, 3);
      }
    });
    test('dailyQuests tất định: cùng ngày → cùng bộ (type+target)', () {
      for (var d = 0; d < 40; d++) {
        final a = dailyQuests(d);
        final b = dailyQuests(d);
        expect(a.map((q) => q.type).toList(), b.map((q) => q.type).toList());
        expect(
          a.map((q) => q.target).toList(),
          b.map((q) => q.target).toList(),
        );
      }
    });
    test('dailyQuests ngày khác → bộ KHÁC (xoay vòng, không kẹt 1 bộ)', () {
      final sigs = <String>{};
      for (var d = 0; d < 14; d++) {
        sigs.add(dailyQuests(d).map((q) => '${q.type}:${q.target}').join('|'));
      }
      expect(sigs.length, greaterThan(1));
    });
  });

  group('sang ngày mới (anti-farm + reset tiến trình)', () {
    test(
      'claim ngày A → ngày A+1 reset: progress về 0, được claim lại',
      () async {
        // tự chứa: ghim clock TRƯỚC onInit (tránh maxDay monotonic của setUp)
        Get.reset();
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        Get.put(StorageService(prefs));
        final g2 = GameController();
        g2.clock = () => DateTime(2026, 6, 20); // ngày A
        Get.put(g2);
        final bp2 = Get.put(BattlePassController(g2));

        // hoàn thành + nhận thưởng ngày A
        for (var i = 0; i < bp2.todayQuests.length; i++) {
          bp2.questProgress[i] = bp2.todayQuests[i].target;
        }
        expect(bp2.claimDailyBonus(), kDailyQuestBonusCoins);
        expect(bp2.dailyBonusClaimed, isTrue);

        // tiến sang ngày A+1 (forward — hợp lệ với chống-lùi-giờ)
        g2.clock = () => DateTime(2026, 6, 21);
        // claimDailyBonus trigger _ensureToday → nạp lại quest ngày mới, KHÔNG
        // cộng tiến trình (trả 0 vì chưa hoàn thành) → quan sát trạng thái reset
        expect(bp2.claimDailyBonus(), 0);
        expect(bp2.questProgress, [0, 0, 0]); // tiến trình reset sang ngày mới
        expect(bp2.dailyBonusClaimed, isFalse); // mốc nhận thuộc ngày A
        expect(bp2.dailyBonusClaimable, isFalse); // chưa đủ bộ ngày mới
      },
    );
  });

  void completeAllQuests() {
    for (var i = 0; i < bp.todayQuests.length; i++) {
      bp.questProgress[i] = bp.todayQuests[i].target;
    }
  }

  group('thưởng hoàn-thành-cả-bộ (1 lần/ngày)', () {
    test('chưa đủ quest → không claimable, claim trả 0', () {
      expect(bp.allQuestsDone, isFalse);
      expect(bp.dailyBonusClaimable, isFalse);
      expect(bp.claimDailyBonus(), 0);
    });

    test(
      'đủ cả bộ → claimable; claim cộng xu + XP, lần 2 trả 0 (anti-farm)',
      () {
        completeAllQuests();
        expect(bp.allQuestsDone, isTrue);
        expect(bp.dailyBonusClaimable, isTrue);

        final coinsBefore = g.coins.value;
        final xpBefore = bp.xp.value;
        final got = bp.claimDailyBonus();
        expect(got, kDailyQuestBonusCoins);
        expect(g.coins.value, coinsBefore + kDailyQuestBonusCoins);
        expect(bp.xp.value, greaterThan(xpBefore)); // +XP
        expect(bp.dailyBonusClaimed, isTrue);
        expect(bp.dailyBonusClaimable, isFalse);

        final coins2 = g.coins.value;
        expect(bp.claimDailyBonus(), 0); // đã nhận → không thưởng lại
        expect(g.coins.value, coins2);
      },
    );
  });

  test('resetProgress xoá mốc bonus (đĩa + RAM)', () async {
    completeAllQuests();
    bp.claimDailyBonus();
    await g.resetProgress();
    expect(bp.dailyBonusClaimed, isFalse);
    expect(StorageService.to.getInt(StorageKeys.questBonusDay, def: -1), -1);
  });

  testWidgets('BattlePassScreen: đủ quest → hiện thẻ bonus + nút CLAIM', (
    tester,
  ) async {
    completeAllQuests();
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('vi', 'VN'),
        fallbackLocale: const Locale('en', 'US'),
        home: const BattlePassScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    // thẻ bonus hiện (nhãn vi) + nút CLAIM (daily_claim) khả dụng
    expect(find.text('Thưởng Trọn Bộ', skipOffstage: false), findsOneWidget);
    expect(bp.dailyBonusClaimable, isTrue);
  });
}
