import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:neon_jewels/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true; // cho phép tải font trên thiết bị thật

  group('Luồng chơi Neon Jewels (end-to-end)', () {
    // Dùng .tr để khớp đúng ngôn ngữ hiện hành của app (không phụ thuộc en/vi).
    testWidgets('Home → chọn màn → vào game thấy HUD', (tester) async {
      await app();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('NEON'), findsOneWidget);
      expect(find.text('play_now'.tr), findsOneWidget);

      await tester.tap(find.text('play_now'.tr));
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      expect(find.text('select_level'.tr), findsOneWidget);

      await tester.tap(find.text('1').first);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.textContaining('hud_score'.tr), findsOneWidget);
      expect(find.textContaining('hud_target'.tr), findsOneWidget);
      expect(find.textContaining('hud_moves'.tr), findsOneWidget);
    });

    testWidgets('Quay lại được từ màn game', (tester) async {
      await app();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('play_now'.tr));
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      await tester.tap(find.text('1').first);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      expect(find.text('select_level'.tr), findsOneWidget);
    });

    testWidgets('Đổi ngôn ngữ trong Settings', (tester) async {
      await app();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('settings'.tr));
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      expect(find.text('settings'.tr), findsWidgets);
      // có lựa chọn English và Tiếng Việt
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Tiếng Việt'), findsOneWidget);
    });
  });
}
