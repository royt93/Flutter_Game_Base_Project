import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/section_header.dart';

void main() {
  testWidgets('render title, không có trailing thì không throw', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: SectionHeader(title: 'Daily Rewards')),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Daily Rewards'), findsOneWidget);
  });

  testWidgets('render trailing widget khi được truyền vào', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SectionHeader(
            title: 'Leaderboard',
            trailing: const Text('See all'),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
  });

  group('ENH-37: Semantics', () {
    testWidgets('title có header: true để screen reader nhảy giữa section', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(child: SectionHeader(title: 'Daily Rewards')),
        ),
      );

      final data = tester.getSemantics(find.bySemanticsLabel('Daily Rewards'));
      expect(data.getSemanticsData().flagsCollection.isHeader, isTrue);
      handle.dispose();
    });

    testWidgets('trailing (vd nút "See all") không bị gắn header: true lây', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: SectionHeader(
              title: 'Leaderboard',
              trailing: const Text('See all'),
            ),
          ),
        ),
      );

      final trailingData = tester.getSemantics(
        find.bySemanticsLabel('See all'),
      );
      expect(trailingData.getSemanticsData().flagsCollection.isHeader, isFalse);
      handle.dispose();
    });
  });
}
