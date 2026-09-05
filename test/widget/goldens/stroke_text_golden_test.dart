import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_base_game/core/neon_theme.dart';
import 'package:roy_base_game/presentation/widgets/stroke_text.dart';

void main() {
  testWidgets('StrokeText default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: Center(
            child: SizedBox(
              width: 200,
              height: 60,
              child: StrokeText('Preview', fontSize: 24),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(StrokeText),
      matchesGoldenFile('stroke_text_default.png'),
    );
  });

  testWidgets('StrokeText custom color/stroke', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: Center(
            child: SizedBox(
              width: 200,
              height: 60,
              child: StrokeText(
                'Settings',
                fontSize: 23,
                color: Colors.white,
                stroke: NeonTheme.purple,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(StrokeText),
      matchesGoldenFile('stroke_text_custom.png'),
    );
  });
}
