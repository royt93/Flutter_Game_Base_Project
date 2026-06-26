import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/leaderboard_engine.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/leaderboard_controller.dart';
import 'package:neon_jewels/presentation/screens/leaderboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 21.6 — Offline Leaderboard: controller logic + widget smoke (2 tab).
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

  group('LeaderboardController', () {
    test('campaignBoard: 10 dòng, có người chơi, đổi theo màn', () {
      final lb = Get.put(LeaderboardController(g));
      lb.setLevel(5);
      final b5 = lb.campaignBoard();
      expect(b5.length, 10);
      expect(playerRank(b5), greaterThan(0)); // người chơi luôn có mặt
      lb.setLevel(6);
      final b6 = lb.campaignBoard();
      // màn khác → bảng bot khác (period trộn level)
      expect(
        b6.map((e) => e.score).toList(),
        isNot(equals(b5.map((e) => e.score).toList())),
      );
    });

    test('setLevel clamp trong [1, maxLevel]', () {
      final lb = Get.put(LeaderboardController(g));
      lb.setLevel(0);
      expect(lb.selectedLevel.value, 1);
      lb.setLevel(99999);
      expect(lb.selectedLevel.value, lb.maxLevel);
    });

    test('dailyBoard: chỉ bot (người chơi ẩn), tất định', () {
      final lb = Get.put(LeaderboardController(g));
      final d = lb.dailyBoard();
      expect(playerRank(d), 0); // người chơi ẩn ở Daily
      expect(d.every((e) => !e.isPlayer), isTrue);
    });

    test('điểm thật người chơi đẩy hạng lên', () {
      final lb = Get.put(LeaderboardController(g));
      lb.setLevel(3);
      final rankZero = playerRank(lb.campaignBoard());
      g.highScores[3] = 999999; // điểm khủng
      final rankHigh = playerRank(lb.campaignBoard());
      expect(rankHigh, lessThanOrEqualTo(rankZero));
      expect(rankHigh, 1);
    });

    test('W22.4A — điểm Daily hôm nay → người chơi xuất hiện ở tab Daily', () {
      final lb = Get.put(LeaderboardController(g));
      final today = g.todayEpochDay;
      // chưa có điểm → ẩn
      expect(lb.dailyPlayerScore(), -1);
      expect(playerRank(lb.dailyBoard()), 0);
      // ghi điểm Daily hôm nay
      StorageService.to.setString(StorageKeys.dailyBestScore, '$today|99999');
      expect(lb.dailyPlayerScore(), 99999);
      expect(playerRank(lb.dailyBoard()), 1); // điểm khủng → hạng 1
    });

    test('W22.4A — điểm Daily ngày CŨ bị bỏ qua (ẩn người chơi)', () {
      final lb = Get.put(LeaderboardController(g));
      final stale = g.todayEpochDay - 3;
      StorageService.to.setString(StorageKeys.dailyBestScore, '$stale|99999');
      expect(lb.dailyPlayerScore(), -1); // khác ngày → bỏ
      expect(playerRank(lb.dailyBoard()), 0);
    });
  });

  group('LeaderboardScreen widget', () {
    Widget app() => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('vi', 'VN'),
      fallbackLocale: const Locale('en', 'US'),
      home: const LeaderboardScreen(),
    );

    // NeonBg animation chạy liên tục → KHÔNG dùng pumpAndSettle (sẽ timeout).
    testWidgets('mount Campaign tab → hiển thị dòng xếp hạng', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LeaderboardScreen), findsOneWidget);
      // skipOffstage:false — người chơi có thể ở cuối ListView (offstage).
      expect(find.text('BẠN', skipOffstage: false), findsOneWidget);
    });

    testWidgets('đổi sang tab Daily không crash', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Hằng ngày'));
      await tester.pump(const Duration(milliseconds: 300));
      // Daily ẩn người chơi (kể cả offstage)
      expect(find.text('BẠN', skipOffstage: false), findsNothing);
      expect(find.byType(LeaderboardScreen), findsOneWidget);
    });
  });
}
