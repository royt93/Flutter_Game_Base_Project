import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:neon_jewels/main.dart';

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

    testWidgets('World Map → node → pre-game → vào game (HUD)',
        (tester) async {
      await app(withAudio: false);
      await settle(tester, 1200);
      await tester.tap(find.text('play_now'.tr));
      await settle(tester);
      // tap node màn 1
      await tester.tap(find.text('1').first);
      await settle(tester);
      // pre-game panel
      expect(find.text('pregame_title'.tr), findsOneWidget);
      await tester.tap(find.text('play_now'.tr).last); // CHƠI NGAY
      await settle(tester, 1500);
      expect(find.textContaining('hud_score'.tr), findsOneWidget);
      expect(find.textContaining('hud_goal'.tr), findsOneWidget);
    });

    testWidgets('Trong game bấm X → dialog thoát', (tester) async {
      await app(withAudio: false);
      await settle(tester, 1200);
      await tester.tap(find.text('play_now'.tr));
      await settle(tester);
      await tester.tap(find.text('1').first);
      await settle(tester);
      await tester.tap(find.text('play_now'.tr).last);
      await settle(tester, 1500);
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
  });
}
