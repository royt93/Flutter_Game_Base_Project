import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/tournament.dart';
import 'package:neon_jewels/presentation/controllers/collection_controller.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/piggy_controller.dart';
import 'package:neon_jewels/presentation/controllers/season_league_controller.dart';
import 'package:neon_jewels/presentation/screens/collection_screen.dart';
import 'package:neon_jewels/presentation/screens/piggy_screen.dart';
import 'package:neon_jewels/presentation/screens/season_league_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late GameController c;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    c = Get.put(GameController());
  });
  tearDown(Get.reset);

  Widget appEn(Widget home) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: AppTranslations.fallback,
        home: home,
      );

  // ----------------------------------------------------------- Collection
  group('CollectionScreen', () {
    testWidgets('render tiêu đề + đếm 0/12 + sticker ẩn', (tester) async {
      await tester.pumpWidget(appEn(const CollectionScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ALBUM'), findsWidgets);
      expect(find.text('0/12'), findsOneWidget);
      expect(find.text('???'), findsWidgets); // sticker chưa mở
    });

    testWidgets('đủ điểm → thu thập sticker (W18.2: vật sưu tập, KHÔNG xu)',
        (tester) async {
      final cc = Get.put(CollectionController(c));
      cc.points.value = 100; // mở được item 0 (30) + item 1 (80)
      c.coins.value = 0;
      await tester.pumpWidget(appEn(const CollectionScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      // W18.2: ô thu-được hiện icon add_circle (không còn 🎁/thưởng xu).
      final collect = find.byIcon(Icons.add_circle_rounded);
      expect(collect, findsWidgets);
      await tester.tap(collect.first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(cc.claimed.length, greaterThanOrEqualTo(1));
      expect(c.coins.value, 0, reason: 'thu thập KHÔNG cộng xu (W18.2)');
    });
  });

  // -------------------------------------------------------------- Piggy
  group('PiggyScreen', () {
    testWidgets('render heo + nút SMASH + số xu tích', (tester) async {
      final pc = Get.put(PiggyController(c));
      pc.saved.value = 200;
      await tester.pumpWidget(appEn(const PiggyScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('PIGGY BANK'), findsWidgets);
      expect(find.text('SMASH'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
    });

    testWidgets('đủ min → bấm SMASH → cộng xu, ống về 0', (tester) async {
      final pc = Get.put(PiggyController(c));
      pc.saved.value = 300;
      c.coins.value = 0;
      await tester.pumpWidget(appEn(const PiggyScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('SMASH'));
      await tester.pump(const Duration(milliseconds: 300)); // dialog
      expect(pc.saved.value, 0);
      expect(c.coins.value, 300);
    });
  });

  // -------------------------------------- Mùa giải (W18.1 gộp Mùa + Giải đấu)
  group('SeasonLeagueScreen', () {
    testWidgets('render bảng xếp hạng: You + bot', (tester) async {
      c.clock = () => DateTime(2026, 6, 18);
      final lc = Get.put(SeasonLeagueController(c));
      lc.points.value = 9999; // You hạng 1
      await tester.pumpWidget(appEn(const SeasonLeagueScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      // 'You' (tour_you) nằm dưới khu mốc → cuộn tới.
      await tester.scrollUntilVisible(
        find.text('You'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('You'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(kTournamentBots.first.name),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(kTournamentBots.first.name), findsOneWidget);
    });

    testWidgets('có điểm → bấm claim hạng → đánh dấu đã nhận tuần', (tester) async {
      c.clock = () => DateTime(2026, 6, 18);
      final lc = Get.put(SeasonLeagueController(c));
      lc.addWin(3); // có điểm để claim
      c.coins.value = 0;
      await tester.pumpWidget(appEn(const SeasonLeagueScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      final btn = find.textContaining('Claim');
      await tester.scrollUntilVisible(
        btn,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.tap(btn, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(lc.claimedRankThisWeek.value, isTrue);
      expect(c.coins.value, greaterThan(0));
    });
  });
}
