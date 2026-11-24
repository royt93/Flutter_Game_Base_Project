import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';
import '../../support/leak_ignores.dart';

// ENH-85: invariants must survive a release build (assert is stripped).
// These widgets keep a const constructor, so the check runs when they build.
void main() {
  Future<void> expectArgumentError(WidgetTester tester, Widget w) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));
    expect(tester.takeException(), isA<ArgumentError>());
  }

  testWidgets('PaginatedDotsIndicator rejects count <= 0', (tester) async {
    await expectArgumentError(
      tester,
      const PaginatedDotsIndicator(count: 0, currentIndex: 0),
    );
  });

  testWidgets('GameOverCardTemplate rejects a lone secondary action', (
    tester,
  ) async {
    await expectArgumentError(
      tester,
      GameOverCardTemplate(
        title: 'Over',
        primaryActionLabel: 'Retry',
        onPrimaryAction: () {},
        secondaryActionLabel: 'Home',
      ),
    );
    await expectArgumentError(
      tester,
      GameOverCardTemplate(
        title: 'Over',
        primaryActionLabel: 'Retry',
        onPrimaryAction: () {},
        onSecondaryAction: () {},
      ),
    );
  });

  testWidgets('CommonButton rejects a text variant with no label', (
    tester,
  ) async {
    await expectArgumentError(tester, CommonButton(onTap: () {}));
  });

  testWidgets('CommonButton rejects an icon variant with no icon', (
    tester,
  ) async {
    await expectArgumentError(
      tester,
      CommonButton(variant: CommonButtonVariant.icon, onTap: () {}),
    );
  });

  testWidgets('CoinFlyOverlay rejects coinCount <= 0', (tester) async {
    await expectArgumentError(
      tester,
      const CoinFlyOverlay(
        from: Offset.zero,
        to: Offset(100, 100),
        coinCount: 0,
      ),
    );
  },
  experimentalLeakTesting: ignoringFailedInitState('_CoinFlyOverlayState'),
  );
}
