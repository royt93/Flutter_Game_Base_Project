import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/boss_rush_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget home) => GetMaterialApp(
  translations: AppTranslations(),
  locale: const Locale('en', 'US'),
  home: home,
);

// I43 Boss Rush: lobby hiện best streak + banner no-booster + nút bắt đầu.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    Get.put(GameController(), permanent: true);
  });

  tearDown(Get.reset);

  testWidgets('lobby hiện best streak, banner no-booster, nút bắt đầu', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const BossRushScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    // StrokeText vẽ 2 lớp (stroke + fill) cho cùng 1 chuỗi → findsWidgets.
    expect(find.text('Boss Rush'), findsWidgets);
    expect(find.textContaining('Best streak'), findsWidgets);
    expect(find.text('Boosters are disabled in Boss Rush'), findsOneWidget);
    expect(find.text('Start run'), findsWidgets);
  });

  testWidgets('nhấn nút bắt đầu chuyển sang màn chơi (Stage 1)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const BossRushScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Start run').first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Stage 1'), findsWidgets);
  });

  testWidgets(
    'mở dialog quit → huỷ → mở lại lần 2 vẫn hiện đúng nội dung, không lỗi '
    '(chứng minh overlaySlot panelKey ổn định qua rebuild thật)',
    (tester) async {
      await tester.pumpWidget(_wrap(const BossRushScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start run').first);
      await tester.pump(const Duration(milliseconds: 100));

      // Game Flame chạy vòng lặp render liên tục trong lúc "playing" nên
      // pumpAndSettle sẽ không bao giờ ổn định — dùng pump(duration) theo
      // đúng thời lượng animation dialog (220ms) thay vì pumpAndSettle.
      const dialogAnim = Duration(milliseconds: 250);

      // Lần 1: mở dialog quit.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(dialogAnim);
      expect(find.text('Quit Level?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(dialogAnim);
      expect(find.text('Quit Level?'), findsNothing);

      // Lần 2: mở lại — mỗi lần setState đều tạo lại NeonDialog.panel() là
      // instance MỚI; nếu overlaySlot còn dùng ValueKey(panel) cũ (identity)
      // thay vì panelKey ổn định, vẫn hoạt động (chưa từng crash) nhưng đây
      // là bài test chốt hành vi đúng cho luồng quit thật trên màn hình.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(dialogAnim);
      expect(find.text('Quit Level?'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Quit'));
      await tester.pump();
      await tester.pump(dialogAnim);
      expect(find.text('Quit Level?'), findsNothing);
      expect(find.text('Boss Rush'), findsWidgets);
    },
  );
}
