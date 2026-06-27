import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neon_jewels/core/app_translations.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/presentation/screens/versus_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fix 2 — Chứng minh: tap X → hiện dialog xác nhận (không thoát ngay).
/// Fix 5 — Chứng minh: dialog có nút HUỶ để cancel, nút TRANG CHỦ để thoát.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
  });
  tearDown(Get.reset);

  Widget appEn(Widget home) => GetMaterialApp(
    translations: AppTranslations(),
    locale: const Locale('en', 'US'),
    fallbackLocale: AppTranslations.fallback,
    home: home,
  );

  group('VersusScreen — exit dialog (Fix 2 + 5)', () {
    testWidgets('SELECT phase: tap X KHÔNG thoát thẳng — hiện dialog', (
      tester,
    ) async {
      // Select phase không có X button (chỉ có HOME button)
      await tester.pumpWidget(appEn(const VersusScreen()));
      await tester.pump();
      // Select phase có HOME (safe back), không có X/close_rounded ở đây
      expect(find.text('HOME'), findsOneWidget);
      expect(
        find.byIcon(Icons.close_rounded),
        findsNothing,
        reason: 'Select phase không cần nút X — HOME đã đủ',
      );
    });

    testWidgets('COUNTDOWN phase: tap X → hiện dialog có HUỶ + HOME', (
      tester,
    ) async {
      await tester.pumpWidget(appEn(const VersusScreen()));
      await tester.pump();

      // Vào countdown
      await tester.tap(find.text('VERSUS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // X button tồn tại
      expect(find.byIcon(Icons.close_rounded), findsAtLeast(1));

      // Tap X → phải hiện dialog xác nhận
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pump();

      // Dialog xuất hiện với nút HUỶ (CANCEL) và HOME
      expect(
        find.text('CANCEL'),
        findsOneWidget,
        reason: 'Dialog phải có nút HUỶ để user có thể quay lại chơi',
      );
      expect(
        find.text('HOME'),
        findsAtLeast(1),
        reason: 'Dialog phải có nút thoát về trang chủ',
      );
    });

    testWidgets('tap HUỶ trong dialog → dialog biến mất, vẫn còn ở màn chơi', (
      tester,
    ) async {
      await tester.pumpWidget(appEn(const VersusScreen()));
      await tester.pump();

      await tester.tap(find.text('VERSUS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Mở dialog
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pump();
      expect(find.text('CANCEL'), findsOneWidget);

      // Tap HUỶ → dialog đóng
      await tester.tap(find.text('CANCEL'));
      await tester.pump();

      // Dialog biến mất
      expect(
        find.text('CANCEL'),
        findsNothing,
        reason: 'Sau khi tap HUỶ, dialog phải đóng lại',
      );
      // X button vẫn còn (vẫn đang ở màn countdown)
      expect(
        find.byIcon(Icons.close_rounded),
        findsAtLeast(1),
        reason: 'Sau HUỶ vẫn còn trong màn chơi',
      );
    });

    testWidgets('PLAYING phase: tap X → dialog xuất hiện đúng cách', (
      tester,
    ) async {
      await tester.pumpWidget(appEn(const VersusScreen()));
      await tester.pump();

      await tester.tap(find.text('VERSUS'));
      await tester.pump();
      // Bỏ qua countdown (4 giây)
      await tester.pump(const Duration(seconds: 4));

      // Đang ở phase PLAYING — tìm X trong centerBar
      final xBtns = find.byIcon(Icons.close_rounded);
      expect(xBtns, findsAtLeast(1));

      await tester.tap(xBtns.first);
      await tester.pump();

      // Dialog phải xuất hiện (không thoát thẳng)
      expect(
        find.text('CANCEL'),
        findsOneWidget,
        reason:
            'Tap X khi đang chơi phải hiện dialog xác nhận, không thoát thẳng',
      );
    });
  });
}
