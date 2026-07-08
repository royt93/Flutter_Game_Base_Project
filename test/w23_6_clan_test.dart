import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/clan_engine.dart';
import 'package:neon_jewels/data/achievements.dart';
import 'package:neon_jewels/presentation/controllers/achievement_controller.dart';
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

  group('Clan vs Clan (BXH)', () {
    test('rivalClanTotal: tất định + dải 500..1399', () {
      for (var w = 0; w < 40; w++) {
        for (var i = 0; i < kRivalClanNames.length; i++) {
          final v = rivalClanTotal(w, i);
          expect(v, rivalClanTotal(w, i));
          expect(v, inInclusiveRange(500, 1399));
        }
      }
    });
    test('buildClanLeague: gồm clan người chơi, giảm dần, có rank', () {
      final lg = buildClanLeague(700, 5);
      expect(lg.length, kRivalClanNames.length + 1);
      for (var i = 1; i < lg.length; i++) {
        expect(lg[i - 1].total, greaterThanOrEqualTo(lg[i].total));
      }
      expect(clanLeagueRank(lg), greaterThan(0));
    });
    test('clan người chơi tổng khủng → hạng 1', () {
      expect(clanLeagueRank(buildClanLeague(999999, 5)), 1);
    });
    test('controller.clanLeague/leagueRank khớp engine', () {
      final lg = cl.clanLeague();
      expect(lg.any((s) => s.isYou), isTrue);
      expect(cl.leagueRank(), clanLeagueRank(lg));
    });

    test('clanLeagueRewardFor: 1→300, 2→200, 3→100, ngoài top3→0', () {
      expect(clanLeagueRewardFor(1), 300);
      expect(clanLeagueRewardFor(2), 200);
      expect(clanLeagueRewardFor(3), 100);
      expect(clanLeagueRewardFor(4), 0);
      expect(clanLeagueRewardFor(0), 0);
    });

    test('clan lên hạng 1 → nhận thưởng hạng 1 lần (anti-farm)', () {
      // bơm đóng góp khủng → clan vượt mọi clan bot → hạng 1
      for (var i = 0; i < 300; i++) {
        cl.addContribution(3);
      }
      expect(cl.leagueRank(), 1);
      expect(cl.leagueRewardClaimable, isTrue);
      final before = g.coins.value;
      final r = cl.claimLeagueReward();
      expect(r, clanLeagueRewardFor(1));
      expect(g.coins.value, before + r);
      expect(cl.leagueRewardClaimed, isTrue);
      // lần 2 → 0, xu không đổi
      final coins2 = g.coins.value;
      expect(cl.claimLeagueReward(), 0);
      expect(g.coins.value, coins2);
    });
  });

  group('W23 — thành tựu Clan (đóng góp tích luỹ)', () {
    test('addContribution cộng dồn clanContribLifetime + persist', () {
      expect(g.clanContribLifetime.value, 0);
      cl.addContribution(3);
      cl.addContribution(3);
      final expected = clanPointsForWin(3) * 2;
      expect(g.clanContribLifetime.value, expected);
      expect(
        StorageService.to.getInt(StorageKeys.clanContribLifetime),
        expected,
      );
    });

    test('đạt 100 tích luỹ → mở khoá thành tựu clan_contrib1', () {
      final ac = Get.put(AchievementController(g));
      final a = kAchievements.firstWhere((x) => x.id == 'clan_contrib1');
      expect(ac.isUnlocked(a), isFalse);
      // bơm đóng góp tới >=100
      while (g.clanContribLifetime.value < a.threshold) {
        cl.addContribution(3);
      }
      expect(ac.isUnlocked(a), isTrue);
    });

    test('resetProgress → clanContribLifetime về 0', () async {
      cl.addContribution(3);
      expect(g.clanContribLifetime.value, greaterThan(0));
      await g.resetProgress();
      expect(g.clanContribLifetime.value, 0);
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

  group('W24.4 — đóng góp từ side-mode', () {
    test('addSideModeContribution cộng dồn đúng bộ đếm tuần + lifetime', () {
      expect(cl.playerContribution, 0);
      expect(g.clanContribLifetime.value, 0);
      cl.addSideModeContribution();
      expect(cl.playerContribution, kClanPointsForSideModeWin);
      expect(g.clanContribLifetime.value, kClanPointsForSideModeWin);
      cl.addSideModeContribution();
      expect(cl.playerContribution, kClanPointsForSideModeWin * 2);
    });

    test('side-mode và campaign cộng CHUNG 1 bộ đếm (không tách trục)', () {
      cl.addContribution(3); // campaign
      cl.addSideModeContribution(); // side-mode
      expect(
        cl.playerContribution,
        clanPointsForWin(3) + kClanPointsForSideModeWin,
      );
    });

    test('side-mode contribution KHÔNG đụng win-streak/level-unlock/lives', () {
      final unlockedBefore = g.unlockedLevel.value;
      final streakBefore = g.winStreak.value;
      final livesBefore = g.lives.value;
      for (var i = 0; i < 5; i++) {
        cl.addSideModeContribution();
      }
      expect(g.unlockedLevel.value, unlockedBefore);
      expect(g.winStreak.value, streakBefore);
      expect(g.lives.value, livesBefore);
    });

    test('resetState → side-mode contribution về 0 (không nhận lại)', () {
      cl.addSideModeContribution();
      expect(cl.playerContribution, greaterThan(0));
      cl.resetState();
      expect(cl.playerContribution, 0);
      expect(g.clanContribLifetime.value, greaterThan(0)); // reset riêng ở g
    });

    test(
      'resetProgress → xoá cả đĩa lẫn RAM, side-mode contribution về 0',
      () async {
        cl.addSideModeContribution();
        cl.addSideModeContribution();
        expect(cl.playerContribution, greaterThan(0));
        await g.resetProgress();
        expect(cl.playerContribution, 0);
        expect(g.clanContribLifetime.value, 0);
        // Khởi tạo controller mới đọc đĩa (đã xoá) → vẫn 0, không rò rỉ qua storage.
        final cl2 = ClanController(g)..onInit();
        expect(cl2.playerContribution, 0);
      },
    );

    test(
      'side-mode contribution giúp đạt mục tiêu tuần + claim thưởng (anti-farm)',
      () {
        while (cl.total() < kClanWeeklyGoal) {
          cl.addSideModeContribution();
        }
        expect(cl.weeklyRewardClaimable, isTrue);
        final before = g.coins.value;
        final r = cl.claimWeeklyReward();
        expect(r, kClanWeeklyReward);
        expect(g.coins.value, before + kClanWeeklyReward);
        // Guard-key (rewardWeekRx) đã ghi TRƯỚC grant xu → claim lại trả 0.
        final coins2 = g.coins.value;
        expect(cl.claimWeeklyReward(), 0);
        expect(g.coins.value, coins2);
      },
    );
  });

  testWidgets('ClanScreen mount → hiện roster (Bạn) + goal, không crash', (
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
    expect(find.text('Bạn', skipOffstage: false), findsOneWidget);
    // W24.4 — chú thích side-mode cũng tính, hiện trên goal card (vi_VN).
    expect(
      find.text(
        'Thắng màn thường lẫn chế độ phụ đều được tính',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
