import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/avatar_frame.dart';
import 'package:roy_casual_kit/presentation/widgets/common/stacked_avatar_group.dart';

void main() {
  test('limits visible avatars and reports overflow count', () {
    final group = StackedAvatarGroup(
      items: List.generate(
        6,
        (index) => StackedAvatarItem.widget(Text('$index')),
      ),
      maxAvatars: 3,
    );
    expect(group.visibleAvatarCount, 3);
    expect(group.overflowCount, 3);
  });

  test('rejects invalid layout parameters', () {
    expect(
      () => StackedAvatarGroup(items: const [], maxAvatars: 0),
      throwsArgumentError,
    );
    expect(
      () => StackedAvatarGroup(items: const [], size: 0),
      throwsArgumentError,
    );
    expect(
      () => StackedAvatarGroup(items: const [], size: 36, overlap: 36),
      throwsArgumentError,
    );
  });

  testWidgets('shows capped avatar count followed by +N badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StackedAvatarGroup(
            items: List.generate(
              6,
              (index) => StackedAvatarItem.widget(
                Text('$index'),
                semanticLabel: 'Player ${index + 1}',
              ),
            ),
            maxAvatars: 3,
          ),
        ),
      ),
    );

    expect(find.byType(AvatarFrame), findsNWidgets(3));
    expect(find.text('+3'), findsOneWidget);
    final avatar0 = tester.getRect(find.widgetWithText(AvatarFrame, '0'));
    final avatar1 = tester.getRect(find.widgetWithText(AvatarFrame, '1'));
    final avatar2 = tester.getRect(find.widgetWithText(AvatarFrame, '2'));
    expect(avatar0.center.dx, lessThan(avatar1.center.dx));
    expect(avatar1.center.dx, lessThan(avatar2.center.dx));
  });

  testWidgets('shows no overflow badge when all avatars fit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StackedAvatarGroup(
            items: const [
              StackedAvatarItem.widget(Text('A')),
              StackedAvatarItem.widget(Text('B')),
            ],
            maxAvatars: 2,
          ),
        ),
      ),
    );

    expect(find.byType(AvatarFrame), findsNWidgets(2));
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets(
    'avatar and overflow callbacks remain caller controlled',
    (tester) async {
      var avatarTaps = 0;
      var overflowTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StackedAvatarGroup(
              items: [
                StackedAvatarItem.widget(
                  const Text('A'),
                  semanticLabel: 'Alice',
                  onTap: () => avatarTaps++,
                ),
                const StackedAvatarItem.widget(Text('B')),
                const StackedAvatarItem.widget(Text('C')),
                const StackedAvatarItem.widget(Text('D')),
              ],
              maxAvatars: 2,
              onOverflowTap: () => overflowTaps++,
              semanticLabel: 'Friends',
            ),
          ),
        ),
      );

      await tester.tap(find.text('A'));
      await tester.tap(find.byKey(const ValueKey('stackedAvatarOverflow')));
      expect(avatarTaps, 1);
      expect(overflowTaps, 1);
      expect(find.bySemanticsLabel(RegExp('Friends')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('2 more avatars')), findsOneWidget);
    },
    semanticsEnabled: true,
  );

  testWidgets('mirrors start/end positions in RTL', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: StackedAvatarGroup(
              items: const [
                StackedAvatarItem.widget(Text('A')),
                StackedAvatarItem.widget(Text('B')),
                StackedAvatarItem.widget(Text('C')),
              ],
              maxAvatars: 2,
            ),
          ),
        ),
      ),
    );

    final avatarA = tester.getRect(find.widgetWithText(AvatarFrame, 'A'));
    final avatarB = tester.getRect(find.widgetWithText(AvatarFrame, 'B'));
    expect(avatarA.center.dx, greaterThan(avatarB.center.dx));
  });
}
