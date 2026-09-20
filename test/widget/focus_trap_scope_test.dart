import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/focus_trap_scope.dart';

void main() {
  testWidgets('autofocus mặc định true: scope tự nhận primary focus ngay khi mount', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: FocusTrapScope(child: Text('X'))),
      ),
    );
    await tester.pump();

    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(
      FocusManager.instance.primaryFocus!.debugLabel,
      'FocusTrapScope',
    );
  });

  testWidgets('autofocus: false không tự nhận focus', (tester) async {
    final backgroundNode = FocusNode(debugLabel: 'background');
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Column(
            children: [
              Focus(focusNode: backgroundNode, child: const Text('bg')),
              const FocusTrapScope(autofocus: false, child: Text('X')),
            ],
          ),
        ),
      ),
    );
    backgroundNode.requestFocus();
    await tester.pump();
    await tester.pump();

    expect(backgroundNode.hasFocus, isTrue);
    backgroundNode.dispose();
  });

  testWidgets(
    'PHÁT HIỆN THẬT (đúng gap FEAT-53 đã ghi): dismount trap -> focus tự động '
    'trả lại đúng node đã focus TRƯỚC lúc trap mount, không rơi về root',
    (tester) async {
      final backgroundNode = FocusNode(debugLabel: 'background');
      var showTrap = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    Focus(focusNode: backgroundNode, child: const Text('background')),
                    if (showTrap)
                      FocusTrapScope(
                        child: Focus(
                          child: ElevatedButton(onPressed: () {}, child: const Text('trapped')),
                        ),
                      ),
                    ElevatedButton(
                      onPressed: () => setState(() => showTrap = !showTrap),
                      child: const Text('toggle'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      backgroundNode.requestFocus();
      await tester.pump();
      expect(backgroundNode.hasFocus, isTrue);

      await tester.tap(find.text('toggle'));
      await tester.pump();
      await tester.pump();

      // Trap mounted và autofocus vào nội dung của nó -> background KHÔNG
      // còn giữ focus nữa.
      expect(backgroundNode.hasFocus, isFalse);

      await tester.tap(find.text('toggle'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Trap unmount -> focus phải quay lại đúng backgroundNode.
      expect(backgroundNode.hasFocus, isTrue);
      backgroundNode.dispose();
    },
  );

  testWidgets('background node đã bị dispose lúc trap đóng -> không throw, chỉ bỏ qua', (
    tester,
  ) async {
    var showTrap = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  if (showTrap)
                    FocusTrapScope(
                      child: Focus(
                        child: ElevatedButton(onPressed: () {}, child: const Text('trapped')),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () => setState(() => showTrap = false),
                    child: const Text('close'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('close'));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('touch-only: tap bình thường vào nội dung trap vẫn hoạt động (không đổi hành vi)', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: FocusTrapScope(
            child: ElevatedButton(onPressed: () => tapped = true, child: const Text('X')),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('X'));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });
}
