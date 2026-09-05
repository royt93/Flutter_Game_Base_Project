import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_base_game/core/neon_theme.dart';
import 'package:roy_base_game/presentation/widgets/common/reward_popup.dart';

void main() {
  testWidgets('RewardPopup burst animation runs without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: RewardPopup(
              title: 'Level Complete!',
              message: 'Great job',
              icon: Icons.star_rounded,
              color: NeonTheme.gold,
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });
}
