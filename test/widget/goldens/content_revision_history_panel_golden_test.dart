import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance(
    'content_revision_history_panel_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);

  for (final state in ['empty', 'history', 'confirmation', 'busy']) {
    testWidgets('Content revision $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final variant in defaultGoldenMatrix()) {
        await tester.pumpWidget(const SizedBox.shrink());
        const target = ValueKey('revisionGolden');
        await runGoldenMatrix(
          tester,
          (_) => Padding(
            key: target,
            padding: const EdgeInsets.all(16),
            child: ContentRevisionHistoryPanel(
              revisions: state == 'empty'
                  ? []
                  : [
                      ContentRevisionSummary(
                        revision: 'previous-ref',
                        version: 7,
                        appliedAtText: 'Yesterday, 16:05',
                        label: 'Summer event',
                      ),
                      ContentRevisionSummary(
                        revision: 'current-ref',
                        version: 8,
                        appliedAtText: 'Today, 10:30',
                        label: 'Autumn event',
                      ),
                    ],
              currentRevision: state == 'empty' ? null : 'current-ref',
              busy: state == 'busy',
              onRollback: (_) async {},
            ),
          ),
          matrix: [variant],
        );
        if (state == 'confirmation') {
          final select = find.byKey(
            const ValueKey('contentRevisionSelect_previous-ref'),
          );
          await tester.ensureVisible(select);
          await tester.tap(select);
          await tester.pump();
          expect(find.textContaining('active content'), findsOneWidget);
          final handle = tester.ensureSemantics();
          try {
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
          } finally {
            handle.dispose();
          }
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(target),
          matchesGoldenFile(
            'goldens/content_revision_${state}_${variant.name}.png',
          ),
        );
      }
    });
  }
}
