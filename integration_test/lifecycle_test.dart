import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/main.dart' as app;
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:pop_star_blast/presentation/screens/level_select_screen.dart';

/// Không dùng pumpAndSettle() ở BẤT KỲ đâu trong file này: StarMascot được
/// mount không điều kiện ở cả HomeScreen (home_screen.dart:328-334) lẫn
/// GameScreen, với AnimationController.repeat() vô hạn khi reduceMotion=false
/// (mặc định trên thiết bị test sạch) → pumpAndSettle không bao giờ ổn định,
/// treo tới khi hết timeout nội bộ. Dùng vòng lặp pump() có giới hạn thay thế
/// (như manual_hint_test.dart).
Future<void> pumpBounded(
  WidgetTester tester, {
  int times = 5,
  Duration step = const Duration(milliseconds: 400),
}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(step);
  }
}

/// Thiết bị thật có thể còn state (streak/comeback) từ lần chạy trước →
/// dialog thưởng hằng ngày/comeback che nút PLAY trên Home. Đóng trước nếu
/// có. Scope theo `Dialog` vì label 'daily_claim' còn dùng ở nhiều nơi khác
/// (shop, vòng quay...) nên tìm text trần trên toàn cây sẽ bị ambiguous.
Future<void> dismissDailyRewardIfShown(WidgetTester tester) async {
  final dialog = find.byType(Dialog);
  if (dialog.evaluate().isEmpty) return;
  await tester.tap(
    find.descendant(of: dialog, matching: find.text('daily_claim'.tr)),
  );
  await pumpBounded(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mở app, chọn level, chơi 1 tap, thoát về danh sách level', (
    tester,
  ) async {
    await app.app(withAudio: false);
    await pumpBounded(tester, times: 15);
    await dismissDailyRewardIfShown(tester);

    // 'PLAY' hiện qua StrokeText (stroke + fill xếp chồng trong Stack) → 2
    // Text trùng nội dung tại cùng vị trí, .first vẫn trúng đúng nút.
    await tester.tap(find.text('PLAY').first);
    await pumpBounded(tester);
    expect(find.byType(LevelSelectScreen), findsOneWidget);

    // Không dùng pumpAndSettle: GameScreen chứa StarMascot với
    // AnimationController.repeat() vô hạn (mặc định reduceMotion=false trên
    // thiết bị test sạch) → pumpAndSettle không bao giờ ổn định, treo tới
    // khi hết timeout 10 phút. Lặp vài lần pump() có giới hạn (như
    // manual_hint_test.dart) để chắc chắn route + Flame game load xong.
    await tester.tap(find.byKey(const Key('level_tile_1')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.byType(GameScreen), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byType(GameWidget<PopStarGame>)));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    // 'quit_action'.tr, không phải literal 'Quit' — thiết bị thật có thể chạy
    // locale khác tiếng Anh (vd tiếng Việt → 'Thoát').
    await tester.tap(find.text('quit_action'.tr));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LevelSelectScreen), findsOneWidget);
  });

  testWidgets(
    'I31: bấm nút Hint 2 lần liên tiếp khi gợi ý đang hiện chỉ trừ 1 lượt '
    '(regression cho bug double-spend đã fix)',
    (tester) async {
      await app.app(withAudio: false);
      await pumpBounded(tester, times: 15);
      await dismissDailyRewardIfShown(tester);

      await tester.tap(find.text('PLAY').first);
      await pumpBounded(tester);
      expect(find.byType(LevelSelectScreen), findsOneWidget);

      // Không dùng pumpAndSettle ở đây — xem lý do ở test đầu tiên (StarMascot
      // repeat() vô hạn trong GameScreen).
      await tester.tap(find.byKey(const Key('level_tile_1')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.byType(GameScreen), findsOneWidget);

      final gameCtrl = Get.find<GameController>();
      final startCount = gameCtrl.hintCount.value;
      expect(startCount, greaterThan(0));

      // Nút Hint là nút cuối trong Row 7 booster nằm trong
      // SingleChildScrollView cuộn ngang (game_screen.dart:341-414) — trên
      // màn hình hẹp, dãy nút tràn ra ngoài nên cần cuộn mới thấy được nút
      // Hint. tap() không tự cuộn Scrollable, phải ensureVisible() trước.
      final hintFinder = find.byIcon(Icons.lightbulb_rounded);
      await tester.ensureVisible(hintFinder);
      await pumpBounded(tester);

      // Bấm 1: hiện gợi ý thật (bàn mới sinh trên thiết bị thật, không mock).
      await tester.tap(hintFinder);
      await tester.pump();
      expect(gameCtrl.hintCount.value, startCount - 1);

      // Bấm 2 ngay lập tức, trong lúc gợi ý bấm-1 vẫn còn đang hiện (chưa
      // qua 1.5s countdown) — trước khi fix, đây chính là double-spend: sẽ
      // trừ thêm 1 lượt nữa. Sau fix, showHint() phải no-op (trả false) vì
      // _hint đã khác rỗng, nên hintCount KHÔNG được giảm thêm.
      await tester.tap(hintFinder);
      await tester.pump();
      expect(gameCtrl.hintCount.value, startCount - 1);

      // Đợi qua mốc 1.5s để gợi ý tự tắt, xác nhận bàn trở về trạng thái
      // bình thường (không còn khoá do gợi ý cũ).
      await tester.pump(const Duration(milliseconds: 1600));

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('quit_action'.tr));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LevelSelectScreen), findsOneWidget);
    },
  );
}
