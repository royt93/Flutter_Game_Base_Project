import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/leaderboard_list.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Material(child: Center(child: child)));

void main() {
  group('LeaderboardList', () {
    testWidgets('renders rank, name and score for each entry', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LeaderboardList(
            entries: [
              LeaderboardEntry(rank: 1, name: 'Alice', score: '9,000'),
              LeaderboardEntry(rank: 2, name: 'Bob', score: '8,500'),
            ],
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('9,000'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('8,500'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders caller-supplied avatar widget when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LeaderboardList(
            entries: [
              LeaderboardEntry(
                rank: 1,
                name: 'Alice',
                score: '9,000',
                avatar: Text('A'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('highlighted entry gets a bordered row, others do not', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LeaderboardList(
            entries: [
              LeaderboardEntry(rank: 1, name: 'Alice', score: '9,000'),
              LeaderboardEntry(
                rank: 2,
                name: 'Me',
                score: '8,500',
                highlighted: true,
              ),
            ],
          ),
        ),
      );

      final aliceRow = tester.widget<Container>(
        find.byKey(const ValueKey('leaderboardRow_1')),
      );
      final meRow = tester.widget<Container>(
        find.byKey(const ValueKey('leaderboardRow_2')),
      );
      final aliceDecoration = aliceRow.decoration as BoxDecoration?;
      final meDecoration = meRow.decoration as BoxDecoration?;

      expect(aliceDecoration?.border, isNull);
      expect(meDecoration?.border, isNotNull);
    });

    testWidgets('empty entries renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap(const LeaderboardList(entries: [])));

      expect(tester.takeException(), isNull);
    });

    group('ENH-46: onTap', () {
      testWidgets('onTap null (mặc định) → tap không throw, không có Semantics button', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _wrap(
            const LeaderboardList(
              entries: [LeaderboardEntry(rank: 1, name: 'Alice', score: '9,000')],
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('leaderboardRow_1')));
        await tester.pump();

        expect(tester.takeException(), isNull);
        final data = tester.getSemantics(
          find.byKey(const ValueKey('leaderboardRow_1')),
        );
        expect(data.getSemanticsData().flagsCollection.isButton, isFalse);
        handle.dispose();
      });

      testWidgets('onTap truyền vào → tap gọi đúng callback, có Semantics button', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        var tapped = false;
        await tester.pumpWidget(
          _wrap(
            LeaderboardList(
              entries: [
                LeaderboardEntry(
                  rank: 1,
                  name: 'Alice',
                  score: '9,000',
                  onTap: () => tapped = true,
                ),
              ],
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('leaderboardRow_1')));
        await tester.pump();

        expect(tapped, isTrue);
        final data = tester.getSemantics(
          find.byKey(const ValueKey('leaderboardRow_1')),
        );
        expect(data.getSemanticsData().flagsCollection.isButton, isTrue);
        handle.dispose();
      });
    });
  });
}
