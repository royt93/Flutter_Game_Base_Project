import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/empty_state_placeholder.dart';

void main() {
  testWidgets('render icon + message với màu mặc định', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: EmptyStatePlaceholder(
            icon: Icons.emoji_events_outlined,
            message: 'No achievements yet',
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
    expect(find.text('No achievements yet'), findsOneWidget);

    final icon = tester.widget<Icon>(
      find.byIcon(Icons.emoji_events_outlined),
    );
    expect(icon.color, NeonTheme.purple);
  });

  testWidgets('màu tuỳ chỉnh áp dụng lên icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: EmptyStatePlaceholder(
            icon: Icons.leaderboard_outlined,
            message: 'Empty leaderboard',
            color: NeonTheme.cyan,
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(
      find.byIcon(Icons.leaderboard_outlined),
    );
    expect(icon.color, NeonTheme.cyan);
  });

  testWidgets('IDEA-26: icon badge có glow nhất quán với AvatarFrame', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: EmptyStatePlaceholder(
            icon: Icons.emoji_events_outlined,
            message: 'No achievements yet',
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.ancestor(
        of: find.byIcon(Icons.emoji_events_outlined),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration as BoxDecoration?;
    expect(decoration?.boxShadow, isNotNull);
    expect(decoration!.boxShadow!.isNotEmpty, true);
  });
}
