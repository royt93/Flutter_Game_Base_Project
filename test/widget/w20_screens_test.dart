import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/progression_tree.dart';
import 'package:neon_jewels/data/challenge_cards.dart';
import 'package:neon_jewels/presentation/controllers/challenge_card_controller.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/controllers/progression_tree_controller.dart';
import 'package:neon_jewels/presentation/screens/challenge_card_screen.dart';
import 'package:neon_jewels/presentation/screens/progression_tree_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 20 — Widget tests cho ProgressionTreeScreen và ChallengeCardScreen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late GameController g;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    g = Get.put(GameController());
  });
  tearDown(Get.reset);

  Widget appEn(Widget home) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: AppTranslations.fallback,
        home: home,
      );

  // ─── ProgressionTreeScreen ────────────────────────────────────────────────

  group('ProgressionTreeScreen', () {
    testWidgets('render 3 nodes với lock icon khi chưa unlock', (tester) async {
      Get.put(ProgressionTreeController(g));
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(appEn(const ProgressionTreeScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      // 3 nodes hiển thị
      expect(find.text('Radiant'), findsOneWidget);
      expect(find.text('Blazing'), findsOneWidget);
      expect(find.text('Prestige'), findsOneWidget);
      // Tất cả đều khoá (lock icon)
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(3));
    });

    testWidgets('node Radiant hiện UNLOCKED khi đủ sao', (tester) async {
      // 20 màn × 3 sao = 60 sao → đủ 50 sao cho Radiant
      for (int i = 1; i <= 20; i++) { g.stars[i] = 3; }
      final ctrl = Get.put(ProgressionTreeController(g));
      ctrl.checkAndUnlock();

      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(appEn(const ProgressionTreeScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      // Radiant node: hiện "✓ UNLOCKED" (pt_unlocked key)
      expect(find.text('✓ UNLOCKED'), findsOneWidget);
      // Stars icon cho node đã unlock
      expect(find.byIcon(Icons.stars_rounded), findsOneWidget);
      // 2 node còn lại vẫn lock
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(2));
    });

    testWidgets('hiện progress bar + cost cho node chưa unlock', (tester) async {
      Get.put(ProgressionTreeController(g));
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(appEn(const ProgressionTreeScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      // Mỗi node lock có LinearProgressIndicator (progress bar)
      expect(find.byType(LinearProgressIndicator), findsNWidgets(kPtNodes.length));
    });
  });

  // ─── ChallengeCardScreen ──────────────────────────────────────────────────

  group('ChallengeCardScreen', () {
    testWidgets('render 3 thử thách với progress bar', (tester) async {
      Get.put(ChallengeCardController(g));
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(appEn(const ChallengeCardScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      // 3 progress bar cho 3 thử thách
      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
      // Nút CLAIM chưa hiện (chưa hoàn thành)
      expect(find.text('CLAIM'), findsNothing);
    });

    testWidgets('CLAIM button hiện khi hoàn thành thử thách campaign', (tester) async {
      final ctrl = Get.put(ChallengeCardController(g));
      // Force complete challenge 0 (winCampaign)
      final target = ctrl.challenges.firstWhere(
          (c) => c.type == ChallengeType.winCampaign).target;
      for (int i = 0; i < target; i++) { ctrl.onCampaignWin(); }

      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(appEn(const ChallengeCardScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      // CLAIM button hiện cho thử thách đã hoàn thành
      expect(find.text('CLAIM'), findsOneWidget);
    });

    testWidgets('CLAIM: nhận xu + nút biến mất', (tester) async {
      final ctrl = Get.put(ChallengeCardController(g));
      final idx = ctrl.challenges.indexWhere(
          (c) => c.type == ChallengeType.winCampaign);
      final target = ctrl.challenges[idx].target;
      for (int i = 0; i < target; i++) { ctrl.onCampaignWin(); }

      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(appEn(const ChallengeCardScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      final coinsBefore = g.coins.value;
      await tester.tap(find.text('CLAIM'));
      // pump(100ms) thay vì pumpAndSettle — LinearProgressIndicator có animation
      // vô hạn nên pumpAndSettle sẽ timeout. claimReward() là synchronous →
      // 1 pump frame đủ để Obx rebuild.
      await tester.pump(const Duration(milliseconds: 100));

      // Xu tăng, CLAIM biến mất (thay bằng check icon)
      expect(g.coins.value, greaterThan(coinsBefore));
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('CLAIM'), findsNothing);
    });
  });
}
