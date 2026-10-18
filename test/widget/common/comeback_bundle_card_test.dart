import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

final _rewards = [
  MilestoneReward(
    icon: Icons.diamond_rounded,
    label: 'Gems',
    amountLabel: 'x100',
  ),
  MilestoneReward(
    icon: Icons.favorite_rounded,
    label: 'Lives',
    amountLabel: 'x5',
  ),
];

Widget _subject({
  String title = 'Welcome Back Bundle',
  String body = 'A special bundle to celebrate your return.',
  String absenceLabel = '7 days away',
  List<MilestoneReward>? rewards,
  String? expiryLabel = 'Available for 23h',
  bool isExpired = false,
  VoidCallback? onClaim,
  VoidCallback? onViewOffer,
  bool disableAnimations = false,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: SingleChildScrollView(
        child: ComebackBundleCard(
          title: title,
          body: body,
          absenceLabel: absenceLabel,
          rewards: rewards ?? _rewards,
          expiryLabel: expiryLabel,
          isExpired: isExpired,
          onClaim: onClaim ?? () {},
          onViewOffer: onViewOffer,
        ),
      ),
    ),
  ),
);

void main() {
  group('ComebackBundleCard validation', () {
    test('rejects empty title/body/absence/action labels', () {
      expect(
        () => ComebackBundleCard(
          title: ' ',
          body: 'Body',
          absenceLabel: '7 days',
          rewards: _rewards,
          onClaim: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => ComebackBundleCard(
          title: 'Title',
          body: ' ',
          absenceLabel: '7 days',
          rewards: _rewards,
          onClaim: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => ComebackBundleCard(
          title: 'Title',
          body: 'Body',
          absenceLabel: ' ',
          rewards: _rewards,
          onClaim: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => ComebackBundleCard(
          title: 'Title',
          body: 'Body',
          absenceLabel: '7 days',
          rewards: _rewards,
          claimLabel: ' ',
          onClaim: () {},
        ),
        throwsArgumentError,
      );
    });
  });

  group('ComebackBundleCard UI', () {
    testWidgets('shows caller rewards, absence and expiry', (tester) async {
      await tester.pumpWidget(_subject());
      expect(find.text('Welcome back after 7 days away'), findsOneWidget);
      expect(find.text('Gems x100'), findsOneWidget);
      expect(find.text('Lives x5'), findsOneWidget);
      expect(find.text('Available for 23h'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('comebackBundleClaimBtn')),
        findsOneWidget,
      );
    });

    testWidgets('Claim and View Offer call separate caller callbacks', (
      tester,
    ) async {
      var claimed = 0;
      var viewed = 0;
      await tester.pumpWidget(
        _subject(onClaim: () => claimed++, onViewOffer: () => viewed++),
      );

      await tester.tap(find.byKey(const ValueKey('comebackBundleViewBtn')));
      await tester.tap(find.byKey(const ValueKey('comebackBundleClaimBtn')));
      expect(viewed, 1);
      expect(claimed, 1);
    });

    testWidgets('expired disables view and claim, shows Expired', (
      tester,
    ) async {
      await tester.pumpWidget(
        _subject(isExpired: true, onClaim: () {}, onViewOffer: () {}),
      );
      final claim = tester.widget<CommonButton>(
        find.byKey(const ValueKey('comebackBundleClaimBtn')),
      );
      final view = tester.widget<CommonButton>(
        find.byKey(const ValueKey('comebackBundleViewBtn')),
      );
      expect(claim.label, 'Expired');
      expect(claim.onTap, isNull);
      expect(view.onTap, isNull);
      expect(find.text('Expired'), findsWidgets);
    });

    testWidgets('semantics announces comeback, rewards, expiry and expired', (
      tester,
    ) async {
      await tester.pumpWidget(_subject(isExpired: true));
      final semantics = tester.widget<Semantics>(
        find.byKey(const ValueKey('comebackBundleSemantics')),
      );
      expect(
        semantics.properties.label,
        contains('Welcome back after 7 days away'),
      );
      expect(semantics.properties.label, contains('2 rewards'));
      expect(semantics.properties.label, contains('Available for 23h'));
      expect(semantics.properties.label, contains('Expired'));
    });

    testWidgets('no overflow at textScale 2.0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const SizedBox.shrink(),
        ),
      );
      await tester.pumpWidget(_subject());
      expect(tester.takeException(), isNull);
    });
  });
}
