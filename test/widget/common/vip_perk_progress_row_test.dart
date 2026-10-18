import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

const _perks = [
  VipPerk(icon: Icons.bolt_rounded, label: '+10% Coins'),
  VipPerk(icon: Icons.block_rounded, label: 'No Ads', isUnlocked: false),
];

Widget _subject({
  int currentTier = 2,
  int currentPoints = 300,
  int? nextTierPoints = 1000,
  String? tierLabel,
  List<VipPerk> perks = _perks,
  VoidCallback? onAction,
  bool disableAnimations = false,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: SingleChildScrollView(
        child: VipPerkProgressRow(
          currentTier: currentTier,
          currentPoints: currentPoints,
          nextTierPoints: nextTierPoints,
          tierLabel: tierLabel,
          perks: perks,
          onAction: onAction,
        ),
      ),
    ),
  ),
);

void main() {
  group('VipPerkProgressRow validation', () {
    test('rejects negative tier or points', () {
      expect(
        () => VipPerkProgressRow(currentTier: -1, currentPoints: 0),
        throwsArgumentError,
      );
      expect(
        () => VipPerkProgressRow(currentTier: 0, currentPoints: -5),
        throwsArgumentError,
      );
    });

    test('rejects non-positive nextTierPoints and empty labels', () {
      expect(
        () => VipPerkProgressRow(
          currentTier: 1,
          currentPoints: 0,
          nextTierPoints: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => VipPerkProgressRow(
          currentTier: 1,
          currentPoints: 0,
          tierLabel: '  ',
        ),
        throwsArgumentError,
      );
      expect(
        () => VipPerkProgressRow(
          currentTier: 1,
          currentPoints: 0,
          actionLabel: '',
        ),
        throwsArgumentError,
      );
    });

    test('progressFraction clamps and max tier is full', () {
      expect(
        VipPerkProgressRow(
          currentTier: 1,
          currentPoints: 250,
          nextTierPoints: 1000,
        ).progressFraction,
        0.25,
      );
      expect(
        VipPerkProgressRow(
          currentTier: 1,
          currentPoints: 5000,
          nextTierPoints: 1000,
        ).progressFraction,
        1.0,
      );
      final max = VipPerkProgressRow(currentTier: 5, currentPoints: 9000);
      expect(max.isMaxTier, isTrue);
      expect(max.progressFraction, 1.0);
    });
  });

  group('VipPerkProgressRow UI', () {
    testWidgets('shows tier, points and perks', (tester) async {
      await tester.pumpWidget(_subject());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('VIP 2'), findsOneWidget);
      expect(find.text('300 / 1,000 pts'), findsOneWidget);
      expect(find.text('Next Tier Progress'), findsOneWidget);
      expect(find.text('+10% Coins'), findsOneWidget);
      expect(find.text('No Ads'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('max tier shows MAX label', (tester) async {
      await tester.pumpWidget(
        _subject(currentTier: 5, currentPoints: 9000, nextTierPoints: null),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Maximum Tier Reached'), findsOneWidget);
      expect(find.text('9,000 pts (MAX)'), findsOneWidget);
    });

    testWidgets('custom tierLabel replaces default', (tester) async {
      await tester.pumpWidget(_subject(tierLabel: 'Gold Club'));
      expect(find.text('Gold Club'), findsOneWidget);
      expect(find.text('VIP 2'), findsNothing);
    });

    testWidgets('action button only when onAction is provided', (tester) async {
      await tester.pumpWidget(_subject());
      expect(find.byKey(const ValueKey('vipPerkActionBtn')), findsNothing);

      var tapped = 0;
      await tester.pumpWidget(_subject(onAction: () => tapped++));
      await tester.tap(find.byKey(const ValueKey('vipPerkActionBtn')));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('semantics reads tier, progress and perk count', (
      tester,
    ) async {
      await tester.pumpWidget(_subject());
      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('vipPerkProgressRowSemantics')),
      );
      expect(semantics.properties.label, contains('VIP 2'));
      expect(semantics.properties.label, contains('300 / 1,000 pts'));
      expect(semantics.properties.label, contains('2 perks'));
    });

    testWidgets('reduced motion renders final progress immediately', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(disableAnimations: true));
      await tester.pump();
      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, closeTo(0.3, 0.001));
    });

    testWidgets('rebuild mid-animation then unmount does not throw', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(currentPoints: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_subject(currentPoints: 900));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });
  });
}
