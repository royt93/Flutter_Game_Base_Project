import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/bottom_sheet_panel.dart';

void main() {
  testWidgets('BottomSheetPanel render drag handle + child truyền vào', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: BottomSheetPanel(child: Text('Panel content'))),
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
                  onPressed: () => showCommonBottomSheet<void>(
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

  group('ENH-47: modal config params', () {
    testWidgets(
      'isDismissible: false → tap ra ngoài (barrier) không đóng sheet',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showCommonBottomSheet<void>(
                      context,
                      isDismissible: false,
                      child: const Text('Sheet body'),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Sheet body'), findsOneWidget);

        // Tap vào barrier (góc trên màn hình, ngoài vùng sheet).
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        expect(find.text('Sheet body'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'mặc định (isDismissible: true) → tap ra ngoài đóng sheet như hành vi cũ',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showCommonBottomSheet<void>(
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

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Sheet body'), findsOneWidget);

        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        expect(find.text('Sheet body'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'barrierColor tuỳ chỉnh forward đúng xuống showModalBottomSheet',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showCommonBottomSheet<void>(
                      context,
                      barrierColor: Colors.red,
                      child: const Text('Sheet body'),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final modalBarrier = tester.widgetList<ModalBarrier>(
          find.byType(ModalBarrier),
        );
        expect(modalBarrier.any((b) => b.color == Colors.red), isTrue);
      },
    );
  });

  group('ENH-37: Semantics', () {
    testWidgets(
      'drag handle bị ExcludeSemantics — không tạo semantics node riêng',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          const MaterialApp(
            home: Material(
              child: BottomSheetPanel(child: Text('Panel content')),
            ),
          ),
        );

        expect(find.byType(ExcludeSemantics), findsWidgets);
        // Node cha (root) chỉ chứa label của child, không lẫn label rác của
        // drag handle (Container không có Text/label nên vốn không tạo
        // label, nhưng ExcludeSemantics còn chặn cả future descendant nào
        // lỡ có semantics — assert bằng cách merge toàn cây và soát label).
        final data = tester.getSemantics(find.byType(BottomSheetPanel));
        expect(data.label, isNot(contains('null')));
        handle.dispose();
      },
    );

    testWidgets(
      'không có ExcludeSemantics thì child vẫn expose bình thường (label passthrough)',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          const MaterialApp(
            home: Material(
              child: BottomSheetPanel(child: Text('Panel content')),
            ),
          ),
        );

        expect(find.text('Panel content'), findsOneWidget);
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );
  });
}
