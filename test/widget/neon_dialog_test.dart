import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/neon_theme.dart';
import 'package:pop_star_blast/presentation/widgets/neon_dialog.dart';

void main() {
  testWidgets('panel render title/message/action, tap action gọi onTap', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: NeonDialog.panel(
              title: 'You Win!',
              color: NeonTheme.gold,
              message: 'Great job',
              icon: Icons.star_rounded,
              actions: [
                NeonDialogAction(
                  label: 'NEXT',
                  color: NeonTheme.gold,
                  onTap: () => tapped = true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('You Win!'), findsOneWidget);
    expect(find.text('Great job'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);

    await tester.tap(find.text('NEXT'));
    expect(tapped, isTrue);
  });

  testWidgets('overlay render panel trên barrier, tap barrier gọi onBarrier', (
    tester,
  ) async {
    var barrierTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            NeonDialog.overlay(
              onBarrier: () => barrierTapped = true,
              panel: NeonDialog.panel(
                title: 'Paused',
                color: NeonTheme.cyan,
                actions: const [],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Paused'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    expect(barrierTapped, isTrue);
  });
}
