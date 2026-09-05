import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_app_bar.dart';

void main() {
  testWidgets('NeonAppBar with actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SizedBox(
            width: 360,
            height: 60,
            child: NeonAppBar(
              title: 'Settings',
              color: NeonTheme.purple,
              onBack: () {},
              actions: [Icon(Icons.info_rounded, color: NeonTheme.gold)],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(NeonAppBar),
      matchesGoldenFile('neon_app_bar.png'),
    );
  });
}
