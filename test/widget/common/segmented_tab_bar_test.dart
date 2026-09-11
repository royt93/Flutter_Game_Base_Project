import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/segmented_tab_bar.dart';

void main() {
  testWidgets('SegmentedTabBar hiển thị đủ label và bấm vào tab gọi onChanged đúng index', (
    tester,
  ) async {
    var selected = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SegmentedTabBar(
            labels: const ['Easy', 'Medium', 'Hard'],
            selectedIndex: selected,
            onChanged: (i) => selected = i,
          ),
        ),
      ),
    );

    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);

    await tester.tap(find.text('Hard'));
    await tester.pump();

    expect(selected, 2);
  });

  testWidgets('SegmentedTabBar đánh dấu đúng segment đang chọn qua Semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SegmentedTabBar(
            labels: const ['A', 'B'],
            selectedIndex: 1,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final semanticsA = tester.getSemantics(find.text('A'));
    final semanticsB = tester.getSemantics(find.text('B'));
    expect(semanticsA.flagsCollection.isSelected.toBoolOrNull(), false);
    expect(semanticsB.flagsCollection.isSelected.toBoolOrNull(), true);
  });

  testWidgets('SegmentedTabBar throw assert khi số lượng label ngoài 2-4', (
    tester,
  ) async {
    expect(
      () => SegmentedTabBar(
        labels: const ['Only one'],
        selectedIndex: 0,
        onChanged: (_) {},
      ),
      throwsAssertionError,
    );
  });

  testWidgets('ENH-24: pill indicator (AnimatedAlign) dùng easeOutBack (nảy)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SegmentedTabBar(
            labels: const ['A', 'B'],
            selectedIndex: 0,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).curve,
      Curves.easeOutBack,
    );
  });

  testWidgets(
    'ENH-20: Reduce Motion bật → AnimatedAlign duration = 0 (không tween)',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: SegmentedTabBar(
                labels: const ['A', 'B'],
                selectedIndex: 0,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final align = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
      expect(align.duration, Duration.zero);
      expect(tester.takeException(), isNull);
    },
  );
}
