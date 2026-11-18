import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance('wave23_widgets_golden_test.dart');
  tearDownAll(() => goldenFileComparator = previous);

  Widget build(String state) => switch (state) {
    'rights' || 'rights_confirm' => PlayerDataRightsPanel(
      onExport: () async {},
      onErase: () async {},
    ),
    'rights_busy' => PlayerDataRightsPanel(
      busy: true,
      onExport: () async {},
      onErase: () async {},
    ),
    'prestige_locked' => PrestigeReadinessCard(
      current: 420,
      threshold: 1000,
      multiplierText: 'Multiplier x1.3',
      onPrestige: () {},
    ),
    'prestige_ready' => PrestigeReadinessCard(
      current: 1500,
      threshold: 1000,
      multiplierText: 'Multiplier x1.3',
      onPrestige: () {},
    ),
    'cooldown_ready' => CooldownActionButton(
      label: 'Claim booster',
      remaining: Duration.zero,
      onTap: () {},
    ),
    _ => CooldownActionButton(
      label: 'Claim booster',
      remaining: const Duration(minutes: 5),
      onTap: () {},
    ),
  };

  for (final state in [
    'rights',
    'rights_confirm',
    'rights_busy',
    'prestige_locked',
    'prestige_ready',
    'cooldown_ready',
    'cooldown_waiting',
  ]) {
    testWidgets('Wave 23 $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final variant in defaultGoldenMatrix()) {
        await tester.pumpWidget(const SizedBox.shrink());
        const target = ValueKey('wave23Golden');
        await runGoldenMatrix(
          tester,
          (_) => Padding(
            key: target,
            padding: const EdgeInsets.all(16),
            child: build(state),
          ),
          matrix: [variant],
        );
        if (state == 'rights_confirm') {
          final erase = find.byKey(const ValueKey('dataRightsErase'));
          await tester.ensureVisible(erase);
          await tester.tap(erase);
          await tester.pump();
          expect(find.textContaining('cannot be undone'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(target),
          matchesGoldenFile('goldens/wave23_${state}_${variant.name}.png'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}
