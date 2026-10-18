import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

const _stats = [
  UpgradeStatChange(
    label: 'Attack',
    currentValue: '25',
    nextValue: '32',
    icon: Icons.flash_on_rounded,
  ),
  UpgradeStatChange(
    label: 'Defense',
    currentValue: '10',
    nextValue: '14',
    icon: Icons.shield_rounded,
  ),
];

const _affordable = [
  UpgradeCost(label: 'Coins', currentAmount: 1000, requiredAmount: 750),
  UpgradeCost(
    label: 'Gems',
    currentAmount: 15,
    requiredAmount: 10,
    icon: Icons.diamond_rounded,
  ),
];

Widget _subject({
  List<UpgradeCost> costs = _affordable,
  bool isMaxLevel = false,
  bool isUpgrading = false,
  VoidCallback? onUpgrade,
  bool textScale2 = false,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale2 ? 2 : 1)),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: SingleChildScrollView(
        child: UpgradePreviewPanel(
          title: 'Dragon Sword',
          currentLevel: 3,
          nextLevel: 4,
          statChanges: _stats,
          costs: costs,
          onUpgrade: onUpgrade ?? () {},
          isMaxLevel: isMaxLevel,
          isUpgrading: isUpgrading,
        ),
      ),
    ),
  ),
);

void main() {
  group('UpgradePreviewPanel validation', () {
    test('rejects bad levels, empty stats and invalid costs', () {
      expect(
        () => UpgradePreviewPanel(
          title: 'Sword',
          currentLevel: 2,
          nextLevel: 2,
          statChanges: _stats,
          costs: _affordable,
          onUpgrade: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => UpgradePreviewPanel(
          title: 'Sword',
          currentLevel: 2,
          nextLevel: 3,
          statChanges: const [],
          costs: _affordable,
          onUpgrade: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => UpgradePreviewPanel(
          title: 'Sword',
          currentLevel: 2,
          nextLevel: 3,
          statChanges: _stats,
          costs: const [
            UpgradeCost(label: 'Coins', currentAmount: -1, requiredAmount: 3),
          ],
          onUpgrade: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => UpgradePreviewPanel(
          title: 'Sword',
          currentLevel: 2,
          nextLevel: 3,
          statChanges: _stats,
          costs: const [
            UpgradeCost(label: 'Coins', currentAmount: 2, requiredAmount: 3),
          ],
          upgradeLabel: ' ',
          onUpgrade: () {},
        ),
        throwsArgumentError,
      );
    });
  });

  group('UpgradePreviewPanel UI', () {
    testWidgets('shows before/after stats and affordable costs', (
      tester,
    ) async {
      await tester.pumpWidget(_subject());
      expect(find.text('LV 3'), findsOneWidget);
      expect(find.text('LV 4'), findsOneWidget);
      expect(find.text('Attack'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      expect(find.text('32'), findsOneWidget);
      expect(find.text('1000/750 Coins'), findsOneWidget);
      expect(find.text('15/10 Gems'), findsOneWidget);
      expect(
        tester
            .widget<CommonButton>(
              find.byKey(const ValueKey('upgradePreviewButton')),
            )
            .onTap,
        isNotNull,
      );
    });

    testWidgets('insufficient resource disables upgrade', (tester) async {
      await tester.pumpWidget(
        _subject(
          costs: const [
            UpgradeCost(label: 'Coins', currentAmount: 2, requiredAmount: 3),
          ],
        ),
      );
      expect(find.text('Insufficient resources'), findsOneWidget);
      expect(
        tester
            .widget<CommonButton>(
              find.byKey(const ValueKey('upgradePreviewButton')),
            )
            .onTap,
        isNull,
      );
    });

    testWidgets('max and upgrading states disable action', (tester) async {
      await tester.pumpWidget(_subject(isMaxLevel: true));
      expect(
        tester.widget<CommonButton>(
          find.byKey(const ValueKey('upgradePreviewButton')),
        ).label,
        'MAX LEVEL',
      );
      expect(
        tester
            .widget<CommonButton>(
              find.byKey(const ValueKey('upgradePreviewButton')),
            )
            .onTap,
        isNull,
      );

      await tester.pumpWidget(_subject(isUpgrading: true));
      expect(find.text('Upgrading…'), findsOneWidget);
      expect(
        tester
            .widget<CommonButton>(
              find.byKey(const ValueKey('upgradePreviewButton')),
            )
            .loading,
        isTrue,
      );
    });

    testWidgets('upgrade callback routes to caller', (tester) async {
      var upgrades = 0;
      await tester.pumpWidget(_subject(onUpgrade: () => upgrades++));
      await tester.tap(find.byKey(const ValueKey('upgradePreviewButton')));
      expect(upgrades, 1);
    });

    testWidgets('semantics and textScale 2.0', (tester) async {
      await tester.pumpWidget(_subject(textScale2: true));
      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('upgradePreviewSemantics')),
      );
      expect(semantics.properties.label, contains('Level 3 to 4'));
      expect(tester.takeException(), isNull);
    });
  });
}
