import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/contrast_audit.dart';

void _noop() {}

Future<List<RenderedTextContrastIssue>> _auditWidget(
  WidgetTester tester,
  Widget child,
  Finder scope,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: NeonTheme.card,
        body: Center(child: SingleChildScrollView(child: child)),
      ),
    ),
  );
  return auditRenderedTextContrast(
    tester,
    scope,
    defaultBackground: NeonTheme.card,
  );
}

void main() {
  tearDown(() => NeonTheme.dark = false);

  group('BUG-120..124: confirmed widget text contrast', () {
    final cases = <String, (Widget Function() build, List<String> labels)>{
      'StreakRepairDialog': (
        () => StreakRepairDialog(
          streakDays: 14,
          onRepair: () {},
          onSkip: () {},
        ),
        ['Your 14-day streak is frozen! Repair it to continue where you left off.'],
      ),
      'PrestigeConfirmationCard': (
        () => PrestigeConfirmationCard(
          currentLevel: 50,
          requiredPrestigeValue: 'Level 50',
          currentMultiplier: 1,
          nextMultiplier: 1.5,
          rewards: const [
            PrestigeReward(
              icon: Icons.flash_on_rounded,
              label: 'Permanent Speed',
              amount: '+25%',
            ),
          ],
          onConfirm: () {},
          onCancel: () {},
        ),
        ['Reset your current level to unlock permanent boosts!', 'Current', 'After Prestige'],
      ),
      'RewardPopup': (
        () => const RewardPopup(
          title: 'Reward',
          message: 'You earned 100 gems',
          enableParticles: false,
        ),
        ['You earned 100 gems'],
      ),
      'SupportDiagnosticsCard': (
        () => SupportDiagnosticsCard(
          summary: SupportDiagnosticsSummary(
            appVersion: '1.2.3',
            generatedAtText: '10:30 UTC',
            sections: const ['health', 'logs'],
          ),
          onShare: () async {},
        ),
        ['Logs and diagnostic details are shared only after confirmation.'],
      ),
      'GameOverCardTemplate': (
        () => const GameOverCardTemplate(
          title: 'Game Over',
          message: 'Better luck next time',
          primaryActionLabel: 'Retry',
          onPrimaryAction: _noop,
        ),
        ['Better luck next time'],
      ),
    };

    for (final dark in [false, true]) {
      for (final entry in cases.entries) {
        testWidgets('dark=$dark: ${entry.key}', (tester) async {
          NeonTheme.dark = dark;
          final issues = await _auditWidget(
            tester,
            entry.value.$1(),
            find.byType(Scaffold),
          );
          for (final label in entry.value.$2) {
            expect(find.text(label), findsOneWidget, reason: entry.key);
            expect(
              issues.where((issue) => issue.text == label),
              isEmpty,
              reason: '$label $issues',
            );
          }
        });
      }
    }
  });

  group('FEAT-205 contrast_audit harness', () {
    testWidgets('phát hiện text độ tương phản thấp trên nền phẳng pha alpha', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.white,
            body: ColoredBox(
              color: Color(0x1FFF9800), // orange 12%
              child: Text('Warning', style: TextStyle(color: Colors.orange)),
            ),
          ),
        ),
      );

      final issues = auditRenderedTextContrast(
        tester,
        find.byType(Scaffold),
        defaultBackground: Colors.white,
      );
      expect(issues, hasLength(1), reason: '$issues');
      expect(issues.single.text, 'Warning');
      expect(issues.single.ratio, lessThan(4.5));
    });

    testWidgets('resolve màu chữ kế thừa từ DefaultTextStyle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.white,
            body: DefaultTextStyle(
              style: TextStyle(color: Colors.orange),
              child: ColoredBox(
                color: Color(0x1FFF9800),
                child: Text('Inherited warning'),
              ),
            ),
          ),
        ),
      );

      final issues = auditRenderedTextContrast(
        tester,
        find.byType(Scaffold),
        defaultBackground: Colors.white,
      );
      expect(issues, hasLength(1), reason: '$issues');
      expect(issues.single.text, 'Inherited warning');
    });

    testWidgets('audits individual RichText span colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.white,
            body: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.black),
                children: [
                  TextSpan(text: 'Good '),
                  TextSpan(
                    text: 'bad',
                    style: TextStyle(color: Colors.orange),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final issues = auditRenderedTextContrast(
        tester,
        find.byType(Scaffold),
        defaultBackground: Colors.white,
      );
      expect(issues, hasLength(1), reason: '$issues');
      expect(issues.single.text, 'bad');
    });

    testWidgets('bỏ qua text trên nền gradient (không thể tính bằng alpha blend phẳng)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple, Colors.deepPurple],
                ),
              ),
              child: const Text('Button', style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      );

      final issues = auditRenderedTextContrast(
        tester,
        find.byType(Scaffold),
        defaultBackground: Colors.white,
      );
      expect(issues, isEmpty, reason: '$issues');
    });

    for (final dark in [false, true]) {
      testWidgets('dark=$dark: audit real PrestigeConfirmationCard', (
        tester,
      ) async {
        NeonTheme.dark = dark;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: NeonTheme.card,
              body: Center(
                child: SingleChildScrollView(
                  child: PrestigeConfirmationCard(
                    currentLevel: 50,
                    requiredPrestigeValue: 'Level 50',
                    currentMultiplier: 1,
                    nextMultiplier: 1.5,
                    rewards: const [
                      PrestigeReward(
                        icon: Icons.flash_on_rounded,
                        label: 'Permanent Speed',
                        amount: '+25%',
                      ),
                    ],
                    onConfirm: () {},
                    onCancel: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        final issues = auditRenderedTextContrast(
          tester,
          find.byType(PrestigeConfirmationCard),
          defaultBackground: NeonTheme.card,
        );
        if (dark) {
          expect(issues, isEmpty, reason: '$issues');
        } else {
          expect(
            issues.where(
              (issue) =>
                  issue.text == 'Current' ||
                  issue.text == 'After Prestige' ||
                  issue.text == 'Reset your current level to unlock permanent boosts!',
            ),
            isEmpty,
            reason: '$issues',
          );
        }
      });

      testWidgets('dark=$dark: bắt lại lỗi cũ ENH-104 nếu hoàn nguyên dùng Colors.orange', (
        tester,
      ) async {
        NeonTheme.dark = dark;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: NeonTheme.card,
              body: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Requires Level 50',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange, // Lỗi cũ trước ENH-104
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final issues = auditRenderedTextContrast(
          tester,
          find.byType(Scaffold),
          defaultBackground: NeonTheme.card,
        );
        if (!dark) {
          // Ở light theme: Colors.orange trên tint orange chỉ đạt ~1.96:1 (< 3.0:1)
          expect(issues, hasLength(1), reason: '$issues');
          expect(issues.single.ratio, lessThan(3.0));
        } else {
          // Ở dark theme: nền navy tối nên Colors.orange đạt tương phản cao
          expect(issues, isEmpty, reason: '$issues');
        }
      });
    }
  });
}
