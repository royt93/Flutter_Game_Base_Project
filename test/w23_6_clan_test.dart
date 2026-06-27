import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/clan_engine.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/tournament.dart' show tournamentWeek;
import 'package:neon_jewels/presentation/controllers/clan_controller.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/screens/clan_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 23 — Clan/Friends offline: engine tất định + đóng góp tuần + thưởng anti-farm.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;
  late ClanController cl;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    g = Get.put(GameController());
    cl = Get.put(ClanController(g));
  });
  tearDown(Get.reset);

  group('engine tất định', () {
    test(
      'clanBotContribution: cùng (week,rank) → cùng giá trị, dải 40..160',
      () {
        for (var w = 0; w < 40; w++) {
          for (var r = 0; r < kClanBotCount; r++) {
            final v = clanBotContribution(w, r);
            expect(v, clanBotContribution(w, r));
            expect(v, inInclusiveRange(40, 160));
          }
        }
      },
    );
    test('clanBotName: 9 bot KHÔNG trùng tên', () {
      for (var w = 0; w < 30; w++) {
        final names = {
          for (var r = 0; r < kClanBotCount; r++) clanBotName(r, w),
        };
        expect(names.length, kClanBotCount);
      }
    });
    test(
      'buildClanRoster: 10 thành viên (9 bot + player), giảm dần, có player',
      () {
        final roster = buildClanRoster(120, 7);
        expect(roster.length, kClanBotCount + 1);
        for (var i = 1; i < roster.length; i++) {
          expect(
            roster[i - 1].contribution,
            greaterThanOrEqualTo(roster[i].contribution),
          );
        }
        expect(clanPlayerRank(roster), greaterThan(0));
      },
    );
    test('player đóng góp khủng → hạng 1', () {
      expect(clanPlayerRank(buildClanRoster(999999, 7)), 1);
    });
  });

  group('controller — đóng góp tuần + reset tuần', () {
    test('addContribution tích luỹ + persist', () {
      expect(cl.playerContribution, 0);
      cl.addContribution(3); // +clanPointsForWin(3)
      cl.addContribution(1);
      expect(cl.playerContribution, clanPointsForWin(3) + clanPointsForWin(1));
    });
    test('tuần CŨ trong storage → đóng góp về 0 (reset tuần)', () {
      final stale = tournamentWeek(g.todayEpochDay) - 2;
      StorageService.to.setString(StorageKeys.clanPointsWeek, '$stale|999');
      final cl2 = ClanController(g)..onInit();
      expect(cl2.playerContribution, 0);
    });
  });

  group('thưởng mục tiêu tuần (anti-farm)', () {
    test('đạt mục tiêu → claim 1 lần cộng xu, lần 2 trả 0', () {
      // bơm đóng góp tới khi tổng clan >= mục tiêu
      while (cl.total() < kClanWeeklyGoal) {
        cl.addContribution(3);
      }
      expect(cl.weeklyRewardClaimable, isTrue);
      final before = g.coins.value;
      final r = cl.claimWeeklyReward();
      expect(r, kClanWeeklyReward);
      expect(g.coins.value, before + kClanWeeklyReward);
      expect(cl.weeklyRewardClaimed, isTrue);

      final coins2 = g.coins.value;
      expect(cl.claimWeeklyReward(), 0); // 1 lần/tuần
      expect(g.coins.value, coins2);
    });
  });

  test('resetProgress → đóng góp + thưởng về fresh', () async {
    while (cl.total() < kClanWeeklyGoal) {
      cl.addContribution(3);
    }
    cl.claimWeeklyReward();
    await g.resetProgress();
    expect(cl.playerContribution, 0);
    expect(cl.weeklyRewardClaimed, isFalse);
  });

  testWidgets('ClanScreen mount → hiện roster (BẠN) + goal, không crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('vi', 'VN'),
        fallbackLocale: const Locale('en', 'US'),
        home: const ClanScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ClanScreen), findsOneWidget);
    expect(find.text('BẠN', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
