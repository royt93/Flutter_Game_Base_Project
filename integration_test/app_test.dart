import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:neon_jewels/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Luồng chơi Neon Jewels (end-to-end)', () {
    testWidgets('Home → chọn màn → vào game thấy HUD', (tester) async {
      app();
      await tester.pump(const Duration(milliseconds: 300));

      // Màn hình Home
      expect(find.text('NEON'), findsOneWidget);
      expect(find.text('CHƠI NGAY'), findsOneWidget);

      // Vào màn chọn level
      await tester.tap(find.text('CHƠI NGAY'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('CHỌN MÀN'), findsOneWidget);

      // Chọn level 1
      await tester.tap(find.text('1').first);
      await tester.pump(const Duration(seconds: 1));

      // Màn game: HUD hiển thị các chỉ số
      expect(find.textContaining('ĐIỂM'), findsOneWidget);
      expect(find.textContaining('MỤC TIÊU'), findsOneWidget);
      expect(find.textContaining('LƯỢT'), findsOneWidget);
    });

    testWidgets('Quay lại được từ màn game', (tester) async {
      app();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('CHƠI NGAY'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('1').first);
      await tester.pump(const Duration(seconds: 1));

      // Nút đóng (X) trên HUD
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('CHỌN MÀN'), findsOneWidget);
    });
  });
}
