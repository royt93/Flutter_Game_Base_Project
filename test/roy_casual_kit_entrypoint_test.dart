import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

void main() {
  test('public entrypoint exposes core, game and widget APIs', () {
    expect(StorageKeys.themeDark, isNotEmpty);
    expect(NeonTheme.gemColors, isNotEmpty);
    expect(RoyGame, isNotNull);
    expect(CommonButton, isNotNull);
    expect(weightedRandomPick<int>([1], [1]), 1);
  });

  testWidgets('consumer can render a widget from the public entrypoint', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommonButton(label: 'Play', onTap: () {}),
        ),
      ),
    );

    expect(find.byType(CommonButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
