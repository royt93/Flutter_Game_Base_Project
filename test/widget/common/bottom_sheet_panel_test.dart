import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/bottom_sheet_panel.dart';

void main() {
  testWidgets('BottomSheetPanel render drag handle + child truyền vào', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: BottomSheetPanel(child: Text('Panel content')),
        ),
      ),
    );

    expect(find.text('Panel content'), findsOneWidget);
    // Drag handle: Container 44x5 canh giữa phía trên child.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxWidth == 44 &&
            w.constraints?.maxHeight == 5,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'showCommonBottomSheet mở BottomSheetPanel bọc child qua showModalBottomSheet',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () =>
                      showCommonBottomSheet<void>(
                        context,
                        child: const Text('Sheet body'),
                      ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sheet body'), findsNothing);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Sheet body'), findsOneWidget);
      expect(find.byType(BottomSheetPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
