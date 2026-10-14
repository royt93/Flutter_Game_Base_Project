import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/swipeable_action_tile.dart';

void main() {
  test('validates reveal/haptic thresholds and resistance', () {
    expect(
      () => SwipeableActionTile(revealThreshold: 0, child: const SizedBox()),
      throwsArgumentError,
    );
    expect(
      () => SwipeableActionTile(hapticThreshold: 1, child: const SizedBox()),
      throwsArgumentError,
    );
    expect(
      () => SwipeableActionTile(resistance: 2, child: const SizedBox()),
      throwsArgumentError,
    );
    expect(
      () => SwipeableAction(label: 'Bad width', width: 0, onTap: _noop),
      throwsArgumentError,
    );
  });

  testWidgets(
    'horizontal swipe reveals start action and requires explicit tap',
    (tester) async {
      var actions = 0;
      final key = GlobalKey<SwipeableActionTileState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeableActionTile(
              key: key,
              enableHaptic: false,
              leadingActions: [
                SwipeableAction(
                  label: 'Claim',
                  icon: Icons.card_giftcard,
                  color: Colors.green,
                  onTap: () => actions++,
                ),
              ],
              child: const SizedBox(
                height: 72,
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(child: Text('Inbox item')),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.drag(find.text('Inbox item'), const Offset(180, 0));
      await tester.pumpAndSettle();

      expect(key.currentState!.isOpen, isTrue);
      expect(find.byKey(const ValueKey('swipeAction_Claim')), findsOneWidget);
      expect(actions, 0);
      await tester.tap(find.byKey(const ValueKey('swipeAction_Claim')));
      await tester.pumpAndSettle();
      expect(actions, 1);
      expect(key.currentState!.isOpen, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'trailing swipe reveals end action and outside child tap closes',
    (tester) async {
      final key = GlobalKey<SwipeableActionTileState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeableActionTile(
              key: key,
              enableHaptic: false,
              trailingActions: [SwipeableAction(label: 'Delete', onTap: _noop)],
              child: const SizedBox(
                height: 72,
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(child: Text('Message')),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.drag(find.text('Message'), const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(key.currentState!.offset, lessThan(0));
      expect(find.byKey(const ValueKey('swipeAction_Delete')), findsOneWidget);
      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();
      expect(key.currentState!.isOpen, isFalse);
    },
  );

  testWidgets('vertical gesture stays with parent scrollable', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            controller: controller,
            itemCount: 12,
            itemBuilder: (context, index) => SwipeableActionTile(
              enableHaptic: false,
              leadingActions: [SwipeableAction(label: 'Claim', onTap: _noop)],
              child: SizedBox(
                height: 80,
                child: ColoredBox(
                  color: Colors.white,
                  child: Text('Row $index'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.text('Row 0'), const Offset(2, -250));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('RTL swipe reveals logical start action on physical right', (
    tester,
  ) async {
    final key = GlobalKey<SwipeableActionTileState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: SwipeableActionTile(
              key: key,
              enableHaptic: false,
              leadingActions: [SwipeableAction(label: 'Start', onTap: _noop)],
              child: const SizedBox(
                width: double.infinity,
                height: 72,
                child: ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ColoredBox).last, const Offset(-180, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('swipeAction_Start')), findsOneWidget);
    expect(key.currentState!.isOpen, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion snaps open without settling animation', (
    tester,
  ) async {
    final key = GlobalKey<SwipeableActionTileState>();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: SwipeableActionTile(
              key: key,
              enableHaptic: false,
              leadingActions: [SwipeableAction(label: 'Read', onTap: _noop)],
              child: const SizedBox(
                height: 72,
                child: ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );

    key.currentState!.openLeading();
    await tester.pump();
    expect(key.currentState!.isOpen, isTrue);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
