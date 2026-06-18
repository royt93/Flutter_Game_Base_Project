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
import 'package:neon_jewels/presentation/controllers/tournament_controller.dart';
import 'package:neon_jewels/presentation/screens/collection_screen.dart';
import 'package:neon_jewels/presentation/screens/piggy_screen.dart';
import 'package:neon_jewels/presentation/screens/tournament_screen.dart';
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

    testWidgets('đủ điểm → 🎁 hiện, bấm claim → tăng claimed + xu',
        (tester) async {
      final cc = Get.put(CollectionController(c));
      cc.points.value = 100; // mở được item 0 (30) + item 1 (80)
      c.coins.value = 0;
      await tester.pumpWidget(appEn(const CollectionScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('🎁'), findsWidgets);
      await tester.tap(find.text('🎁').first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(cc.claimed.length, greaterThanOrEqualTo(1));
      expect(c.coins.value, greaterThan(0)); // item 0 thưởng 40 xu
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

  // ---------------------------------------------------------- Tournament
  group('TournamentScreen', () {
    testWidgets('render bảng xếp hạng: You + bot', (tester) async {
      c.clock = () => DateTime(2026, 6, 18);
      final tc = Get.put(TournamentController(c));
      tc.points.value = 9999; // You hạng 1 → ở đầu list (chắc chắn render)
      await tester.pumpWidget(appEn(const TournamentScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('TOURNAMENT'), findsWidgets);
      expect(find.text('You'), findsOneWidget);
      // bot xếp hạng thấp có thể nằm dưới fold (ListView lazy) → cuộn tới.
      await tester.scrollUntilVisible(
        find.text(kTournamentBots.first.name),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(kTournamentBots.first.name), findsOneWidget);
    });

    testWidgets('có điểm → bấm claim → đánh dấu đã nhận tuần', (tester) async {
      c.clock = () => DateTime(2026, 6, 18);
      final tc = Get.put(TournamentController(c));
      tc.addWin(3); // có điểm để claim
      c.coins.value = 0;
      await tester.pumpWidget(appEn(const TournamentScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      final btn = find.textContaining('Claim');
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tc.claimedThisWeek.value, isTrue);
      expect(c.coins.value, greaterThan(0));
    });
  });
}
