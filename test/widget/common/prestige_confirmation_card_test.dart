import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/prestige_confirmation_card.dart';

void main() {
  const testRewards = [
    PrestigeReward(
      icon: Icons.flash_on_rounded,
      label: 'Permanent Speed',
      amount: '+25%',
    ),
    PrestigeReward(
      icon: Icons.stars_rounded,
      label: 'Prestige Star',
      amount: 'x1',
    ),
  ];

  Widget buildSubject({
    int currentLevel = 50,
    String requiredPrestigeValue = 'Level 50',
    double currentMultiplier = 1.0,
    double nextMultiplier = 1.5,
    List<PrestigeReward> rewards = testRewards,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool showActions = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: PrestigeConfirmationCard(
              currentLevel: currentLevel,
              requiredPrestigeValue: requiredPrestigeValue,
              currentMultiplier: currentMultiplier,
              nextMultiplier: nextMultiplier,
              rewards: rewards,
              onConfirm: onConfirm ?? () {},
              onCancel: onCancel ?? () {},
              showActions: showActions,
            ),
          ),
        ),
      ),
    );
  }

  group('PrestigeConfirmationCard validation', () {
    test('ném ArgumentError khi currentLevel âm', () {
      expect(
        () => PrestigeConfirmationCard(
          currentLevel: -1,
          requiredPrestigeValue: 'Level 50',
          currentMultiplier: 1.0,
          nextMultiplier: 2.0,
          rewards: testRewards,
          onConfirm: () {},
          onCancel: () {},
        ),
        throwsArgumentError,
      );
    });

    test('ném ArgumentError khi currentMultiplier <= 0 hoặc không hữu hạn', () {
      expect(
        () => PrestigeConfirmationCard(
          currentLevel: 10,
          requiredPrestigeValue: 'Level 50',
          currentMultiplier: 0.0,
          nextMultiplier: 2.0,
          rewards: testRewards,
          onConfirm: () {},
          onCancel: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => PrestigeConfirmationCard(
          currentLevel: 10,
          requiredPrestigeValue: 'Level 50',
          currentMultiplier: double.nan,
          nextMultiplier: 2.0,
          rewards: testRewards,
          onConfirm: () {},
          onCancel: () {},
        ),
        throwsArgumentError,
      );
    });

    test('ném ArgumentError khi nextMultiplier <= currentMultiplier', () {
      expect(
        () => PrestigeConfirmationCard(
          currentLevel: 10,
          requiredPrestigeValue: 'Level 50',
          currentMultiplier: 2.0,
          nextMultiplier: 1.5,
          rewards: testRewards,
          onConfirm: () {},
          onCancel: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => PrestigeConfirmationCard(
          currentLevel: 10,
          requiredPrestigeValue: 'Level 50',
          currentMultiplier: 2.0,
          nextMultiplier: 2.0,
          rewards: testRewards,
          onConfirm: () {},
          onCancel: () {},
        ),
        throwsArgumentError,
      );
    });

    test('ném ArgumentError khi requiredPrestigeValue rỗng', () {
      expect(
        () => PrestigeConfirmationCard(
          currentLevel: 10,
          requiredPrestigeValue: '   ',
          currentMultiplier: 1.0,
          nextMultiplier: 2.0,
          rewards: testRewards,
          onConfirm: () {},
          onCancel: () {},
        ),
        throwsArgumentError,
      );
    });

    test('ném ArgumentError khi rewards rỗng', () {
      expect(
        () => PrestigeConfirmationCard(
          currentLevel: 10,
          requiredPrestigeValue: 'Level 50',
          currentMultiplier: 1.0,
          nextMultiplier: 2.0,
          rewards: const [],
          onConfirm: () {},
          onCancel: () {},
        ),
        throwsArgumentError,
      );
    });

    test('ném ArgumentError khi title hoặc labels rỗng', () {
      expect(
        () => PrestigeConfirmationCard(
          currentLevel: 10,
          requiredPrestigeValue: 'Level 50',
          currentMultiplier: 1.0,
          nextMultiplier: 2.0,
          rewards: testRewards,
          title: '   ',
          onConfirm: () {},
          onCancel: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => PrestigeConfirmationCard(
          currentLevel: 10,
          requiredPrestigeValue: 'Level 50',
          currentMultiplier: 1.0,
          nextMultiplier: 2.0,
          rewards: testRewards,
          confirmLabel: '',
          onConfirm: () {},
          onCancel: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => PrestigeConfirmationCard(
          currentLevel: 10,
          requiredPrestigeValue: 'Level 50',
          currentMultiplier: 1.0,
          nextMultiplier: 2.0,
          rewards: testRewards,
          cancelLabel: ' ',
          onConfirm: () {},
          onCancel: () {},
        ),
        throwsArgumentError,
      );
    });
  });

  group('PrestigeConfirmationCard rendering & actions', () {
    testWidgets('hiển thị level reset, current/next multiplier và rewards', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          currentLevel: 75,
          currentMultiplier: 1.2,
          nextMultiplier: 2.0,
        ),
      );

      expect(
        find.text('Requires Level 50 · Level 75 resets to 1'),
        findsOneWidget,
      );
      expect(find.text('1.2x'), findsOneWidget);
      expect(find.text('2.0x'), findsOneWidget);
      expect(find.text('+0.8x'), findsOneWidget);
      expect(find.text('Permanent Speed'), findsOneWidget);
      expect(find.text('+25%'), findsOneWidget);
      expect(find.text('Prestige Star'), findsOneWidget);
      expect(find.text('x1'), findsOneWidget);
      expect(find.byKey(const ValueKey('prestigeConfirmBtn')), findsOneWidget);
    });

    testWidgets('tap confirm gọi onConfirm', (tester) async {
      var confirmed = false;
      await tester.pumpWidget(buildSubject(onConfirm: () => confirmed = true));

      await tester.tap(find.byKey(const ValueKey('prestigeConfirmBtn')));
      await tester.pump();

      expect(confirmed, isTrue);
    });

    testWidgets('tap cancel gọi onCancel khi được cung cấp', (tester) async {
      var canceled = false;
      await tester.pumpWidget(buildSubject(onCancel: () => canceled = true));

      await tester.tap(find.byKey(const ValueKey('prestigeCancelBtn')));
      await tester.pump();

      expect(canceled, isTrue);
    });

    testWidgets('semantics bao gồm thông tin chi tiết về level và multiplier', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          currentLevel: 40,
          currentMultiplier: 1.5,
          nextMultiplier: 2.5,
        ),
      );

      final semanticsFinder = find.byKey(
        const ValueKey('prestigeConfirmationSemantics'),
      );
      expect(semanticsFinder, findsOneWidget);
      final semanticsWidget = tester.widget<Semantics>(semanticsFinder);
      expect(
        semanticsWidget.properties.label,
        contains('Requirement: Level 50. Current Level 40 will reset to 1'),
      );
      expect(
        semanticsWidget.properties.label,
        contains('from 1.5x to 2.5x (+1.0x)'),
      );
    });

    testWidgets(
      'static .show mở dialog overlay và gọi callback khi tương tác',
      (tester) async {
        var confirmed = false;
        var canceled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    PrestigeConfirmationCard.show(
                      context,
                      currentLevel: 60,
                      requiredPrestigeValue: 'Level 50',
                      currentMultiplier: 2.0,
                      nextMultiplier: 3.5,
                      rewards: testRewards,
                      onConfirm: () => confirmed = true,
                      onCancel: () => canceled = true,
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Prestige Confirmation'), findsOneWidget);
        expect(
          find.text('Requires Level 50 · Level 60 resets to 1'),
          findsOneWidget,
        );

        // Confirm button inside NeonDialog actions
        await tester.tap(find.text('Prestige Now'));
        await tester.pumpAndSettle();

        expect(confirmed, isTrue);
        expect(canceled, isFalse);
        expect(find.text('Prestige Confirmation'), findsNothing);
      },
    );

    testWidgets('hỗ trợ Reduced Motion mượt mà', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: buildSubject(),
        ),
      );

      expect(find.byType(PrestigeConfirmationCard), findsOneWidget);
      expect(find.text('Permanent Rewards'), findsOneWidget);
    });

    testWidgets('unmount giữa entrance không gọi action hoặc rò ticker', (
      tester,
    ) async {
      var confirmed = false;
      var canceled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => PrestigeConfirmationCard.show(
                  context,
                  currentLevel: 60,
                  requiredPrestigeValue: 'Level 50',
                  currentMultiplier: 2,
                  nextMultiplier: 3,
                  rewards: testRewards,
                  onConfirm: () => confirmed = true,
                  onCancel: () => canceled = true,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));

      expect(confirmed, isFalse);
      expect(canceled, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('background/resume không tự xác nhận prestige', (tester) async {
      var confirmed = false;
      await tester.pumpWidget(buildSubject(onConfirm: () => confirmed = true));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 100));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 100));

      expect(confirmed, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
