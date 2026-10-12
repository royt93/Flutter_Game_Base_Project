import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/expandable_panel.dart';

void main() {
  testWidgets('toggle updates target state and callback once per change', (
    tester,
  ) async {
    var expanded = false;
    final changes = <bool>[];
    late StateSetter update;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            home: Scaffold(
              body: ExpandablePanel(
                header: const Text('FAQ'),
                content: const Text('Answer'),
                isExpanded: expanded,
                onExpansionChanged: (value) {
                  changes.add(value);
                  setState(() => expanded = value);
                },
              ),
            ),
          );
        },
      ),
    );
    expect(find.text('Answer'), findsNothing);
    await tester.tap(find.text('FAQ'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(expanded, isTrue);
    expect(changes, [true]);
    expect(find.byType(SizeTransition), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Answer'), findsOneWidget);
    await tester.tap(find.text('FAQ'));
    await tester.pumpAndSettle();
    expect(expanded, isFalse);
    expect(changes, [true, false]);
    expect(find.text('Answer'), findsOneWidget);
    expect(changes, [true, false]);
    expect(tester.takeException(), isNull);
    update(() {});
  });

  testWidgets('external expanded value animates without callback', (
    tester,
  ) async {
    var expanded = false;
    var callbacks = 0;
    late StateSetter update;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            home: Scaffold(
              body: ExpandablePanel(
                header: const Text('Details'),
                content: const Text('Body'),
                isExpanded: expanded,
                onExpansionChanged: (_) => callbacks++,
              ),
            ),
          );
        },
      ),
    );
    update(() => expanded = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Body'), findsOneWidget);
    expect(callbacks, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Reduced Motion expands immediately and lazy content stays absent closed',
    (tester) async {
      var expanded = false;
      late StateSetter update;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: MaterialApp(
                home: Scaffold(
                  body: ExpandablePanel(
                    header: const Text('Settings'),
                    content: const Text('Advanced'),
                    isExpanded: expanded,
                    onExpansionChanged: (value) =>
                        setState(() => expanded = value),
                  ),
                ),
              ),
            );
          },
        ),
      );
      expect(find.text('Advanced'), findsNothing);
      update(() => expanded = true);
      await tester.pump();
      expect(find.text('Advanced'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('non-positive duration is rejected', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExpandablePanel(
            header: Text('Bad'),
            content: Text('Bad content'),
            duration: Duration.zero,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isA<ArgumentError>());
  });
}
