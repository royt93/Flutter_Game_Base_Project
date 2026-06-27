import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_jewels/core/neon_theme.dart';
import 'package:neon_jewels/presentation/widgets/neon_button.dart';

/// Fix 7: NeonButton trong Row panel đền neon được bọc Expanded →
/// không overflow trên phone nhỏ (trước fix: NeonButton width=240
/// trong Row với text cố định → tổng > chiều rộng panel).
void main() {
  group('Temple panel Row layout (Fix 7)', () {
    Widget _buildPanel({required double screenWidth}) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: screenWidth,
            child: Container(
              padding: const EdgeInsets.all(NeonTheme.s16),
              margin: const EdgeInsets.all(NeonTheme.s16),
              child: Row(
                children: [
                  // Khu vực chi phí (không flex)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '80',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('· +30 xu', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(width: NeonTheme.s16),
                  // NeonButton bọc Expanded → lấy phần còn lại
                  Expanded(
                    child: NeonButton(
                      label: 'XÂY',
                      color: NeonTheme.cyan,
                      icon: Icons.construction_rounded,
                      width: double.infinity,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('không overflow trên màn 360px (phone nhỏ)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildPanel(screenWidth: 360));
      await tester.pump();

      // Không có RenderFlex overflow error
      expect(tester.takeException(), isNull);
      // NeonButton phải xuất hiện
      expect(find.text('XÂY'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
    });

    testWidgets('không overflow trên màn 320px (phone rất nhỏ)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildPanel(screenWidth: 320));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('XÂY'), findsOneWidget);
    });

    testWidgets('Expanded bọc NeonButton tồn tại trong widget tree', (
      tester,
    ) async {
      await tester.pumpWidget(_buildPanel(screenWidth: 400));
      await tester.pump();

      // Tìm Expanded widget
      expect(find.byType(Expanded), findsWidgets);
      // NeonButton nằm trong Expanded (đúng với fix)
      final expanded = tester.widgetList<Expanded>(find.byType(Expanded)).last;
      expect(expanded.child, isA<NeonButton>());
    });

    testWidgets('text chi phí + reward hiển thị đủ', (tester) async {
      await tester.pumpWidget(_buildPanel(screenWidth: 375));
      await tester.pump();

      expect(find.text('80'), findsOneWidget);
      expect(find.text('· +30 xu'), findsOneWidget);
      expect(find.text('XÂY'), findsOneWidget);
    });
  });
}
