@Tags(['slow'])
library;

// TC-12 — các case P0 phụ thuộc thiết bị/OS (lifecycle, back stack, resume) mà
// unit/widget test không kích hoạt được. Điều khiển app thật qua channel vòng đời
// và nút Back vật lý.
//
// CHẬM: chạy real-time, vào GameScreen (Flame) → ~5-8 phút/case trên thiết bị thật.
// Vì vậy tách khỏi app_test.dart + gắn @Tags(['slow']). Cách chạy:
//   • Đầy đủ (nightly/device-farm):  flutter test integration_test/ -d <device>
//   • Bỏ qua nhóm chậm:              flutter test integration_test/ -d <device> --exclude-tags slow
//   • Chỉ nhóm này:                  flutter test integration_test/tc12_lifecycle_test.dart -d <device>

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:neon_jewels/main.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/screens/game_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;

  tearDown(Get.reset);

  // Màn có animation lặp → KHÔNG pumpAndSettle (treo). Dùng pump cố định.
  Future<void> settle(WidgetTester t, [int ms = 900]) async {
    await t.pump();
    await t.pump(Duration(milliseconds: ms));
  }

  Future<void> skipStoryIfAny(WidgetTester t) async {
    if (find.text('story_skip'.tr).evaluate().isNotEmpty) {
      await t.tap(find.text('story_skip'.tr));
      await settle(t);
    }
  }

  // Home → World Map → node màn 1 → (cốt truyện nếu state mới) → (pre-game nếu
  // CÒN booster) → vào game. Chịu được cả 2 nhánh (có/không pre-game).
  Future<void> enterLevelOne(WidgetTester t) async {
    await t.tap(find.text('play_now'.tr));
    await settle(t);
    await t.tap(find.text('1').first);
    await settle(t);
    await skipStoryIfAny(t);
    if (find.text('pregame_title'.tr).evaluate().isNotEmpty) {
      await t.tap(find.text('play_now'.tr).last);
    }
    await settle(t, 1500);
  }

  // Đẩy 1 trạng thái vòng đời qua channel chuẩn 'flutter/lifecycle'.
  // channelBuffers.push (không deprecated) thay handleAppLifecycleStateChanged (@protected).
  // KHÔNG pump ở đây: khi app paused engine ngừng cấp frame → pump() (chờ frame) treo vài phút.
  void pushLifecycle(WidgetTester t, AppLifecycleState s) {
    t.binding.channelBuffers.push(
      'flutter/lifecycle',
      const StringCodec().encodeMessage(s.toString()),
      (_) {},
    );
  }

  // Mô phỏng background→resume: đẩy inactive→paused→resumed LIÊN TIẾP, KHÔNG pump lúc
  // đang paused (tránh treo). Chỉ settle SAU khi đã resumed (engine cấp frame trở lại).
  Future<void> backgroundThenResume(WidgetTester t) async {
    pushLifecycle(t, AppLifecycleState.inactive);
    pushLifecycle(t, AppLifecycleState.paused);
    pushLifecycle(t, AppLifecycleState.resumed);
    await settle(t);
  }

  // Mô phỏng nút Back vật lý Android (popRoute) qua API public của binding.
  Future<void> androidBack(WidgetTester t) async {
    await t.binding.handlePopRoute();
    await settle(t);
  }

  group('TC-12 — lifecycle / back stack / resume', () {
    testWidgets(
      'Campaign: background 30s → resume giữ HUD, không tự kết thúc',
      (tester) async {
        await app(withAudio: false);
        await settle(tester, 1200);
        await enterLevelOne(tester);
        expect(find.textContaining('hud_score'.tr), findsOneWidget);

        await backgroundThenResume(tester);

        // Resume không được crash, không tự win/lose, HUD vẫn còn.
        expect(tester.takeException(), isNull);
        expect(find.textContaining('hud_score'.tr), findsOneWidget);
        final g = Get.find<GameController>();
        expect(g.isSideMode, isFalse); // Campaign = không phải side mode
      },
    );

    testWidgets('Rush: background → resume vẫn ở Rush, không crash', (
      tester,
    ) async {
      await app(withAudio: false);
      await settle(tester, 1200);
      // 'rush_short' = 'rush_title' = "TỐC CHIẾN" (label card + corner record chip
      // có thể trùng text) → .first; cả hai đều nằm trong GestureDetector card RUSH.
      await tester.tap(find.text('rush_short'.tr).first);
      await settle(tester);
      final g = Get.find<GameController>();
      expect(g.isRush.value, isTrue);

      await backgroundThenResume(tester);

      expect(tester.takeException(), isNull);
      expect(g.isRush.value, isTrue);
      expect(find.textContaining('hud_time'.tr), findsOneWidget);
    });

    testWidgets(
      'Android Back trong game → confirm quit, Cancel quay lại game',
      (tester) async {
        await app(withAudio: false);
        await settle(tester, 1200);
        await enterLevelOne(tester);
        if (find.text('tut_skip'.tr).evaluate().isNotEmpty) {
          await tester.tap(find.text('tut_skip'.tr));
          await settle(tester);
        }

        // PopScope(canPop:false) → Back không thoát app, mà mở confirm quit.
        await androidBack(tester);
        expect(find.text('quit_title'.tr), findsOneWidget);

        await tester.tap(find.text('cancel'.tr));
        await settle(tester);
        expect(find.textContaining('hud_score'.tr), findsOneWidget);
      },
    );

    testWidgets('Back stack: spam tap card Rush chỉ vào 1 GameScreen', (
      tester,
    ) async {
      await app(withAudio: false);
      await settle(tester, 1200);

      // Tap nhanh 5 lần: GetX preventDuplicates phải chặn push route trùng.
      // .first vì label + corner record chip có thể cùng text "TỐC CHIẾN".
      final card = find.text('rush_short'.tr).first;
      for (var i = 0; i < 5; i++) {
        await tester.tap(card, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 40));
      }
      await settle(tester, 1200);

      expect(Get.find<GameController>().isRush.value, isTrue);
      // skipOffstage:false → đếm cả route bị che; phát hiện nếu stack có >1 GameScreen.
      expect(find.byType(GameScreen, skipOffstage: false), findsOneWidget);
    });
  });
}
