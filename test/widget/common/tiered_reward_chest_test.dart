import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/tiered_reward_chest.dart';

Widget _wrap(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

Map<ChestTier, Widget> _rewards() => {
  for (final t in ChestTier.values) t: Text('reward-${t.name}'),
};

double _scaleY(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('tieredChestBounce')))
    .transform
    .entry(1, 1);

void main() {
  test('ChestTier ladder is ordered and has distinct names', () {
    expect(ChestTier.values.map((t) => t.displayName), [
      'Wood',
      'Silver',
      'Gold',
      'Diamond',
    ]);
    expect(ChestTier.values.map((t) => t.rayColor).toSet().length, 4);
  });

  test('rejects non-finite or non-positive size', () {
    expect(
      () => TieredRewardChest(
        currentTier: ChestTier.wood,
        onOpen: () {},
        size: const Size(0, 100),
      ),
      throwsArgumentError,
    );
    expect(
      () => TieredRewardChest(
        currentTier: ChestTier.wood,
        onOpen: () {},
        size: const Size(double.infinity, 100),
      ),
      throwsArgumentError,
    );
  });

  testWidgets('tap on closed chest calls onOpen; opened chest ignores tap', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(
      _wrap(
        TieredRewardChest(currentTier: ChestTier.gold, onOpen: () => opens++),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('tieredChestTap')));
    expect(opens, 1);

    await tester.pumpWidget(
      _wrap(
        TieredRewardChest(
          currentTier: ChestTier.gold,
          isOpened: true,
          onOpen: () => opens++,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('tieredChestTap')));
    expect(opens, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tier upgrade plays squash-stretch bounce then settles', (
    tester,
  ) async {
    Widget build(ChestTier t) =>
        _wrap(TieredRewardChest(currentTier: t, onOpen: () {}));
    await tester.pumpWidget(build(ChestTier.wood));
    expect(_scaleY(tester), 1.0);

    await tester.pumpWidget(build(ChestTier.silver));
    await tester.pump(const Duration(milliseconds: 210));
    expect(_scaleY(tester), greaterThan(1.05));

    await tester.pump(const Duration(milliseconds: 400));
    expect(_scaleY(tester), closeTo(1.0, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('downgrade and Reduced Motion do not bounce', (tester) async {
    Widget build(ChestTier t, {bool reduced = false}) => _wrap(
      TieredRewardChest(currentTier: t, onOpen: () {}),
      reduced: reduced,
    );
    await tester.pumpWidget(build(ChestTier.gold));
    await tester.pumpWidget(build(ChestTier.silver));
    await tester.pump(const Duration(milliseconds: 210));
    expect(_scaleY(tester), 1.0);

    await tester.pumpWidget(build(ChestTier.wood, reduced: true));
    await tester.pumpWidget(build(ChestTier.diamond, reduced: true));
    await tester.pump(const Duration(milliseconds: 210));
    expect(_scaleY(tester), 1.0);
  });

  testWidgets('opening reveals only the current tier reward', (tester) async {
    Widget build(bool opened) => _wrap(
      TieredRewardChest(
        currentTier: ChestTier.gold,
        isOpened: opened,
        tierRewards: _rewards(),
        onOpen: () {},
      ),
    );
    await tester.pumpWidget(build(false));
    expect(find.text('reward-gold'), findsNothing);

    await tester.pumpWidget(build(true));
    await tester.pump(NeonDurations.opening);
    expect(find.text('reward-gold'), findsOneWidget);
    expect(find.text('reward-wood'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mounted already opened shows reward without animating', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TieredRewardChest(
          currentTier: ChestTier.diamond,
          isOpened: true,
          tierRewards: _rewards(),
          onOpen: () {},
        ),
      ),
    );
    expect(find.text('reward-diamond'), findsOneWidget);
  });

  testWidgets('Reduced Motion opens instantly', (tester) async {
    Widget build(bool opened) => _wrap(
      TieredRewardChest(
        currentTier: ChestTier.silver,
        isOpened: opened,
        tierRewards: _rewards(),
        onOpen: () {},
      ),
      reduced: true,
    );
    await tester.pumpWidget(build(false));
    await tester.pumpWidget(build(true));
    await tester.pump();
    expect(find.text('reward-silver'), findsOneWidget);
  });

  testWidgets('semantics announce tier and state', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(TieredRewardChest(currentTier: ChestTier.silver, onOpen: () {})),
    );
    final node = tester.getSemantics(
      find.byKey(const ValueKey('tieredChestTap')),
    );
    expect(node.label, 'Silver chest');
    expect(node.value, 'closed');
    handle.dispose();
  });
}

class NeonDurations {
  static const opening = Duration(milliseconds: 900);
}
