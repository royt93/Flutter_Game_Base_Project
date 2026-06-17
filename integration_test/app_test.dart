import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:neon_jewels/data/cosmetics.dart';
import 'package:neon_jewels/main.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;

  // Reset GetX giữa các test → tránh rò rỉ state (overlay còn mở, controller
  // permanent giữ Rx cũ) khi app() chạy lại trong cùng tiến trình.
  tearDown(Get.reset);

  // Các màn có animation lặp (Home/World Map/wheel) → KHÔNG dùng pumpAndSettle
  // (sẽ treo). Dùng pump cố định để "ổn định" khung hình.
  Future<void> settle(WidgetTester t, [int ms = 900]) async {
    await t.pump();
    await t.pump(Duration(milliseconds: ms));
  }

  // Màn đầu mỗi thế giới (lần đầu, state mới) hiện cốt truyện intro TRƯỚC pre-game.
  // Bỏ qua nếu xuất hiện → tới được pre-game (an toàn cho cả state đã xem story).
  Future<void> skipStoryIfAny(WidgetTester t) async {
    if (find.text('story_skip'.tr).evaluate().isNotEmpty) {
      await t.tap(find.text('story_skip'.tr));
      await settle(t);
    }
  }

  // Home → World Map → node màn 1 → (cốt truyện nếu state mới) → (pre-game nếu
  // CÒN booster) → vào game. Pre-game CHỈ hiện khi sở hữu booster (PregameController
  // .hasAny); hết booster thì vào thẳng game → test phải chịu được CẢ HAI (độc lập
  // thứ tự chạy & state đĩa tích luỹ).
  Future<void> enterLevelOne(WidgetTester t) async {
    await t.tap(find.text('play_now'.tr)); // Home → World Map
    await settle(t);
    await t.tap(find.text('1').first); // node màn 1
    await settle(t);
    await skipStoryIfAny(t);
    if (find.text('pregame_title'.tr).evaluate().isNotEmpty) {
      await t.tap(find.text('play_now'.tr).last); // CHƠI NGAY (pre-game)
    }
    await settle(t, 1500);
  }

  group('Neon Jewels — Wave 5 end-to-end', () {
    testWidgets('Home → World Map (mặc định) → grid view', (tester) async {
      await app(withAudio: false);
      await settle(tester, 1200);
      expect(find.text('NEON'), findsOneWidget);
      expect(find.text('play_now'.tr), findsOneWidget);

      await tester.tap(find.text('play_now'.tr));
      await settle(tester);
      expect(find.text('world_map'.tr), findsOneWidget); // mặc định bản đồ

      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await settle(tester);
      expect(find.text('select_level'.tr), findsOneWidget); // chuyển grid
    });

    testWidgets('Home → Thành tựu', (tester) async {
      await app(withAudio: false);
      await settle(tester, 1200);
      await tester.tap(find.text('achievements'.tr));
      await settle(tester);
      expect(find.text('achievements'.tr), findsWidgets);
      expect(find.text('ach_first_win_t'.tr), findsOneWidget);
    });

    testWidgets('Home → Vòng quay may mắn → quay', (tester) async {
      await app(withAudio: false);
      await settle(tester, 1200);
      await tester.tap(find.byIcon(Icons.casino_rounded));
      await settle(tester);
      expect(find.text('wheel_title'.tr), findsOneWidget);
      expect(find.text('wheel_spin'.tr), findsOneWidget);
      await tester.tap(find.text('wheel_spin'.tr));
      await settle(tester, 3600); // chờ bánh xe xoay xong
      // sau khi quay: nút SPIN biến mất (đã dùng lượt hôm nay)
      expect(find.text('wheel_spin'.tr), findsNothing);
    });

    testWidgets('Home → Quà hằng ngày', (tester) async {
      await app(withAudio: false);
      await settle(tester, 1200);
      await tester.tap(find.byIcon(Icons.card_giftcard_rounded));
      await settle(tester);
      expect(find.text('daily_title'.tr), findsOneWidget);
    });

    testWidgets('World Map → node → (pre-game) → vào game (HUD)',
        (tester) async {
      await app(withAudio: false);
      await settle(tester, 1200);
      await enterLevelOne(tester);
      expect(find.textContaining('hud_score'.tr), findsOneWidget);
      expect(find.textContaining('hud_goal'.tr), findsOneWidget);
    });

    testWidgets('Trong game bấm X → dialog thoát', (tester) async {
      await app(withAudio: false);
      await settle(tester, 1200);
      await enterLevelOne(tester);
      // màn 1 lần đầu có thể hiện tutorial → bỏ qua để chạm được nút X
      if (find.text('tut_skip'.tr).evaluate().isNotEmpty) {
        await tester.tap(find.text('tut_skip'.tr));
        await settle(tester);
      }

      await tester.tap(find.byIcon(Icons.close_rounded));
      await settle(tester);
      expect(find.text('quit_title'.tr), findsOneWidget);
      await tester.tap(find.text('cancel'.tr));
      await settle(tester);
      expect(find.textContaining('hud_score'.tr), findsOneWidget);
    });

    testWidgets('Đổi ngôn ngữ trong Settings', (tester) async {
      await app(withAudio: false);
      await settle(tester, 1200);
      await tester.tap(find.text('settings'.tr));
      await settle(tester);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Tiếng Việt'), findsOneWidget);
    });

    testWidgets('Mở Hướng dẫn từ Home', (tester) async {
      await app(withAudio: false);
      await settle(tester, 1200);
      await tester.tap(find.text('guide'.tr));
      await settle(tester);
      expect(find.text('guide_special_title'.tr), findsOneWidget);
      expect(find.text('guide_modes_title'.tr), findsOneWidget);
    });

    testWidgets('Home → Cửa hàng → mua + trang bị skin', (tester) async {
      await app(withAudio: false);
      await settle(tester, 1200);
      // cấp đủ xu để mua (mặc định chỉ 50)
      Get.find<GameController>().coins.value = 5000;
      await tester.tap(find.byIcon(Icons.storefront_rounded));
      await settle(tester);
      expect(find.text('shop_title'.tr), findsOneWidget);
      expect(find.text('shop_skins'.tr), findsOneWidget);
      // mua skin trả phí đầu tiên qua nút giá → tự trang bị
      final paid = kGemSkins.firstWhere((s) => s.price > 0);
      // giá có thể trùng giữa skin & theme → lấy thẻ đầu (skin render trước)
      await tester.tap(find.text('💰 ${paid.price}').first);
      await settle(tester);
      expect(Get.find<GameController>().selectedSkin.value, paid.id);
    });
  });
}
