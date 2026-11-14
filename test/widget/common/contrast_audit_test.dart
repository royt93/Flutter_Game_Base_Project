import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';

import '../../support/contrast_audit.dart';

void main() {
  tearDown(() => NeonTheme.dark = false);

  group('FEAT-205 contrast_audit harness', () {
    testWidgets('phát hiện text độ tương phản thấp trên nền phẳng pha alpha', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.white,
            body: ColoredBox(
              color: Color(0x1FFF9800), // orange 12%
              child: Text('Warning', style: TextStyle(color: Colors.orange)),
            ),
          ),
        ),
      );

      final issues = auditRenderedTextContrast(
        tester,
        find.byType(Scaffold),
        defaultBackground: Colors.white,
      );
      expect(issues, hasLength(1), reason: '$issues');
      expect(issues.single.text, 'Warning');
      expect(issues.single.ratio, lessThan(4.5));
    });

    testWidgets('bỏ qua text trên nền gradient (không thể tính bằng alpha blend phẳng)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple, Colors.deepPurple],
                ),
              ),
              child: const Text('Button', style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      );

      final issues = auditRenderedTextContrast(
        tester,
        find.byType(Scaffold),
        defaultBackground: Colors.white,
      );
      expect(issues, isEmpty, reason: '$issues');
    });

    for (final dark in [false, true]) {
      testWidgets('dark=$dark: chip cảnh báo PrestigeConfirmationCard đạt chuẩn', (
        tester,
      ) async {
        NeonTheme.dark = dark;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: NeonTheme.card,
              body: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Requires Level 50',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: NeonTheme.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final issues = auditRenderedTextContrast(
          tester,
          find.byType(Scaffold),
          defaultBackground: NeonTheme.card,
        );
        expect(issues, isEmpty, reason: '$issues');
      });

      testWidgets('dark=$dark: bắt lại lỗi cũ ENH-104 nếu hoàn nguyên dùng Colors.orange', (
        tester,
      ) async {
        NeonTheme.dark = dark;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: NeonTheme.card,
              body: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Requires Level 50',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange, // Lỗi cũ trước ENH-104
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final issues = auditRenderedTextContrast(
          tester,
          find.byType(Scaffold),
          defaultBackground: NeonTheme.card,
        );
        if (!dark) {
          // Ở light theme: Colors.orange trên tint orange chỉ đạt ~1.96:1 (< 3.0:1)
          expect(issues, hasLength(1), reason: '$issues');
          expect(issues.single.ratio, lessThan(3.0));
        } else {
          // Ở dark theme: nền navy tối nên Colors.orange đạt tương phản cao
          expect(issues, isEmpty, reason: '$issues');
        }
      });
    }
  });
}
