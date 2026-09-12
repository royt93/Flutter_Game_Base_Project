import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/icon_badge_button.dart';

void main() {
  testWidgets('IconBadgeButton dùng semanticLabel tuỳ chỉnh khi được truyền', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: IconBadgeButton(
            icon: Icons.settings,
            semanticLabel: 'Settings',
            onTap: () {},
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(IconBadgeButton));
    expect(semantics.label, 'Settings');
    handle.dispose();
  });

  // x-scale (m11) của ma trận — không dùng `getMaxScaleOnAxis()` (đã verify
  // qua debug script ở ENH-31/32: trả sai giá trị cho ma trận scale thuần),
  // đọc trực tiếp phần tử ma trận thay thế.
  double badgeScaleOf(WidgetTester tester) => tester
      .widget<Transform>(find.byKey(const Key('iconBadgeButtonBadgeScale')))
      .transform
      .storage[0];

  testWidgets(
    'IDEA-16: mount lần đầu badge đã hiện sẵn → không pop (scale = 1.0 ngay)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: IconBadgeButton(
              icon: Icons.settings,
              onTap: () {},
              showBadge: true,
            ),
          ),
        ),
      );

      expect(badgeScaleOf(tester), 1.0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'IDEA-16: badge vừa xuất hiện (showBadge false → true) → pop (scale bounce)',
    (tester) async {
      var showBadge = false;
      late StateSetter setBadge;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: StatefulBuilder(
              builder: (context, setState) {
                setBadge = setState;
                return IconBadgeButton(
                  icon: Icons.settings,
                  onTap: () {},
                  showBadge: showBadge,
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(Positioned), findsNothing);

      setBadge(() => showBadge = true);
      await tester.pump();

      expect(badgeScaleOf(tester), isNot(1.0));

      await tester.pumpAndSettle();
      expect(badgeScaleOf(tester), 1.0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('IDEA-16: badgeCount đổi số → pop lại', (tester) async {
    var count = 3;
    late StateSetter setCount;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: StatefulBuilder(
            builder: (context, setState) {
              setCount = setState;
              return IconBadgeButton(
                icon: Icons.settings,
                onTap: () {},
                badgeCount: count,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(badgeScaleOf(tester), 1.0);

    setCount(() => count = 4);
    await tester.pump();

    expect(badgeScaleOf(tester), isNot(1.0));
    expect(find.text('4'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'IDEA-16: Reduce Motion bật → badge xuất hiện không animate, vẫn đúng nội dung',
    (tester) async {
      var showBadge = false;
      late StateSetter setBadge;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: StatefulBuilder(
                builder: (context, setState) {
                  setBadge = setState;
                  return IconBadgeButton(
                    icon: Icons.settings,
                    onTap: () {},
                    showBadge: showBadge,
                  );
                },
              ),
            ),
          ),
        ),
      );

      setBadge(() => showBadge = true);
      await tester.pump();

      expect(badgeScaleOf(tester), 1.0);
      expect(tester.takeException(), isNull);
    },
  );
}
