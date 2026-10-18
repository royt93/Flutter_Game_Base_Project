import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/clan_chat_preview_bar.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

void main() {
  final previous = installGoldenTolerance(
    'clan_chat_preview_bar_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);

  for (final state in ['normal', 'overflow', 'empty']) {
    testWidgets('ClanChatPreviewBar $state golden matrix', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await runGoldenMatrix(
        tester,
        (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: ClanChatPreviewBar(
            senderName: state == 'empty' ? null : 'Maya Rose',
            message: state == 'empty'
                ? null
                : 'Ready for the next team event? Join us!',
            timestampText: '2m ago',
            unreadCount: state == 'empty' ? 0 : (state == 'overflow' ? 120 : 3),
            onTap: () {},
          ),
        ),
        goldenBaseName: 'clan_chat_preview_bar_$state',
      );
    });
  }
}
