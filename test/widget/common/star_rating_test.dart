import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/star_rating.dart';

void main() {
  testWidgets('StarRating (animate: false) hiển thị đúng số sao earned/dim', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: StarRating(earned: 2, total: 3)),
      ),
    );

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(1));

    final filled = tester.widgetList<Icon>(find.byIcon(Icons.star_rounded));
    for (final icon in filled) {
      expect(icon.color, NeonTheme.gold);
    }
    final dim = tester.widgetList<Icon>(
      find.byIcon(Icons.star_outline_rounded),
    );
    for (final icon in dim) {
      expect(icon.color, NeonTheme.muted);
    }

    // Không có ScaleTransition khi animate: false.
    expect(find.byType(ScaleTransition), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StarRating (animate: true) pop-in staggered, không throw', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: StarRating(earned: 3, total: 3, animate: true),
        ),
      ),
    );

    // Ngay sau frame đầu, các ScaleTransition đã được gắn (animation đang
    // chạy). AnimationController này tự settle (không phải ticker vô hạn)
    // nhưng vẫn dùng bounded pump theo convention của repo thay vì
    // pumpAndSettle.
    expect(find.byType(ScaleTransition), findsNWidgets(3));

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'FEAT-17: Reduce Motion bật → animate: true không chạy pop-in, hiện tĩnh',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: StarRating(earned: 2, total: 3, animate: true),
            ),
          ),
        ),
      );

      expect(find.byType(ScaleTransition), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('StarRating earned=0 thì tất cả sao đều là outline (dim)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: StarRating(earned: 0, total: 3)),
      ),
    );

    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(3));
  });

  // x-scale (m11) của ma trận — không dùng `getMaxScaleOnAxis()` (đã verify
  // qua debug script ở progress_bar_stars_test.dart: trả sai giá trị cho ma
  // trận scale thuần trong bản Flutter này), đọc trực tiếp phần tử ma trận.
  double scaleOfNthIcon(WidgetTester tester, IconData icon, int index) {
    final transform = tester.widget<Transform>(
      find.ancestor(
        of: find.byIcon(icon).at(index),
        matching: find.byType(Transform),
      ),
    );
    return transform.transform.storage[0];
  }

  group('BUG-31: didUpdateWidget trigger pop-in khi earned tăng lúc runtime', () {
    testWidgets(
      'earned tăng trên CÙNG 1 instance (không remount, animate: false) → '
      'sao mới đạt được pop-in ngay, sao cũ không bị ảnh hưởng',
      (tester) async {
        var earned = 1;
        late StateSetter setLocalState;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              setLocalState = setState;
              return MaterialApp(
                home: Material(
                  child: StarRating(earned: earned, total: 3, animate: false),
                ),
              );
            },
          ),
        );

        // Mount đầu tiên: không pop toàn bộ (giữ nguyên hành vi cũ).
        expect(find.byType(ScaleTransition), findsNothing);

        setLocalState(() => earned = 2);
        await tester.pump();

        // Sao thứ 2 (index 1, vừa đạt) giờ có ScaleTransition đang chạy từ 0.
        expect(find.byType(ScaleTransition), findsOneWidget);
        expect(scaleOfNthIcon(tester, Icons.star_rounded, 1), 0.0);

        await tester.pump(const Duration(milliseconds: 300));
        expect(scaleOfNthIcon(tester, Icons.star_rounded, 1), closeTo(1.0, 0.001));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'earned tăng nhiều sao cùng lúc (ví dụ 0 → 3) → mỗi sao mới đều pop-in',
      (tester) async {
        var earned = 0;
        late StateSetter setLocalState;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              setLocalState = setState;
              return MaterialApp(
                home: Material(
                  child: StarRating(earned: earned, total: 3, animate: false),
                ),
              );
            },
          ),
        );

        setLocalState(() => earned = 3);
        await tester.pump();

        expect(find.byType(ScaleTransition), findsNWidgets(3));
        for (var i = 0; i < 3; i++) {
          expect(scaleOfNthIcon(tester, Icons.star_rounded, i), 0.0);
        }

        await tester.pump(const Duration(milliseconds: 300));
        for (var i = 0; i < 3; i++) {
          expect(scaleOfNthIcon(tester, Icons.star_rounded, i), closeTo(1.0, 0.001));
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('earned GIẢM lúc runtime → không trigger pop-in nào (chỉ snap)', (
      tester,
    ) async {
      var earned = 2;
      late StateSetter setLocalState;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setLocalState = setState;
            return MaterialApp(
              home: Material(child: StarRating(earned: earned, total: 3)),
            );
          },
        ),
      );

      setLocalState(() => earned = 0);
      await tester.pump();

      expect(find.byType(ScaleTransition), findsNothing);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('earned không đổi (rebuild vì lý do khác) → không trigger pop-in thừa', (
      tester,
    ) async {
      const earned = 2;
      var unrelated = 0.0;
      late StateSetter setLocalState;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setLocalState = setState;
            return MaterialApp(
              home: Material(
                child: StarRating(earned: earned, total: 3, size: 40 + unrelated),
              ),
            );
          },
        ),
      );

      setLocalState(() => unrelated = 1);
      await tester.pump();

      expect(find.byType(ScaleTransition), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Reduce Motion bật → earned tăng lúc runtime KHÔNG pop-in, chỉ snap tĩnh',
      (tester) async {
        var earned = 1;
        late StateSetter setLocalState;

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: StatefulBuilder(
              builder: (context, setState) {
                setLocalState = setState;
                return MaterialApp(
                  home: Material(child: StarRating(earned: earned, total: 3)),
                );
              },
            ),
          ),
        );

        setLocalState(() => earned = 2);
        await tester.pump();

        expect(find.byType(ScaleTransition), findsNothing);
        expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
