import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/energy_bar.dart';

Widget _wrap(Widget child) => MaterialApp(home: Material(child: child));

void main() {
  testWidgets('renders maxEnergy pips, currentEnergy of them filled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const EnergyBar(
          currentEnergy: 3,
          maxEnergy: 5,
          timeUntilNextEnergy: Duration(minutes: 12),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite), findsNWidgets(3));
    expect(find.byIcon(Icons.favorite_border), findsNWidgets(2));
  });

  testWidgets('shows ∞ and no countdown when hasInfiniteLives', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const EnergyBar(
          currentEnergy: 5,
          maxEnergy: 5,
          timeUntilNextEnergy: Duration.zero,
          hasInfiniteLives: true,
        ),
      ),
    );

    expect(find.text('∞'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.textContaining(':'), findsNothing);
  });

  testWidgets('no countdown text when energy is already full', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const EnergyBar(
          currentEnergy: 5,
          maxEnergy: 5,
          timeUntilNextEnergy: Duration.zero,
        ),
      ),
    );

    expect(find.textContaining(':'), findsNothing);
  });

  testWidgets('shows a countdown that ticks down over a couple of seconds', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const EnergyBar(
          currentEnergy: 3,
          maxEnergy: 5,
          timeUntilNextEnergy: Duration(minutes: 1, seconds: 5),
        ),
      ),
    );

    expect(find.text('01:05'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('01:03'), findsOneWidget);
  });

  testWidgets('reduced motion still shows the countdown text', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _wrap(
          const EnergyBar(
            currentEnergy: 3,
            maxEnergy: 5,
            timeUntilNextEnergy: Duration(seconds: 42),
          ),
        ),
      ),
    );

    expect(find.text('00:42'), findsOneWidget);
  });
}
