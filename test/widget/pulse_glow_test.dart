import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/neon_theme.dart';
import 'package:pop_star_blast/presentation/widgets/pulse_glow.dart';

void main() {
  testWidgets(
    'renders child inside the glowing container, breathes without crash',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PulseGlow(color: NeonTheme.gold, child: const Text('PLAY')),
        ),
      );
      await tester.pump();

      expect(find.text('PLAY'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull);
    },
  );
}
