import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/expandable_panel.dart';
import '../../support/leak_ignores.dart';

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
    expect(find.text('Answer'), findsOneWidget);
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
  },
  experimentalLeakTesting: ignoringFailedInitState('ExpandablePanelState'),
  );

  group('screen reader', () {
    Future<List<SemanticsNode>> pumpPanel(
      WidgetTester tester, {
      String? semanticLabel,
      ValueChanged<bool>? onChanged,
      bool expanded = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpandablePanel(
              header: const Text('Gameplay settings'),
              content: const Text('Advanced options'),
              isExpanded: expanded,
              semanticLabel: semanticLabel,
              onExpansionChanged: onChanged,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      return tester.semantics.simulatedAccessibilityTraversal().toList();
    }

    SemanticsNode tappable(List<SemanticsNode> nodes) => nodes.firstWhere(
      (n) => n.getSemanticsData().hasAction(SemanticsAction.tap),
    );

    testWidgets('header without semanticLabel is announced by its text', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final nodes = await pumpPanel(tester);
      expect(tappable(nodes).label, 'Gameplay settings');
      expect(
        nodes.where(
          (n) =>
              n.label.trim().isEmpty &&
              n.getSemanticsData().hasAction(SemanticsAction.tap),
        ),
        isEmpty,
        reason: 'no unnamed button for the reader',
      );
      handle.dispose();
    });

    testWidgets('an explicit semanticLabel names the same button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final nodes = await pumpPanel(tester, semanticLabel: 'FAQ: settings');
      expect(tappable(nodes).label, contains('FAQ: settings'));
      expect(
        nodes.where((n) => n.getSemanticsData().hasAction(SemanticsAction.tap)),
        hasLength(1),
        reason: 'one button, not a duplicate tappable label',
      );
      handle.dispose();
    });

    testWidgets('the reader tap action toggles the panel', (tester) async {
      final handle = tester.ensureSemantics();
      final changes = <bool>[];
      final nodes = await pumpPanel(tester, onChanged: changes.add);
      tester.semantics.tap(find.semantics.byAction(SemanticsAction.tap).first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(changes, [true]);
      expect(nodes, isNotEmpty);
      handle.dispose();
    });

    testWidgets('expanded state is exposed on the button', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPanel(tester, expanded: true);
      final node = tester.getSemantics(
        find.byKey(const ValueKey('expandablePanelHeader')),
      );
      expect(
        node.getSemanticsData().flagsCollection.isExpanded.toBoolOrNull(),
        isTrue,
      );
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      handle.dispose();
    });
  });
}
