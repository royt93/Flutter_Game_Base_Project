import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/confirm_dialog.dart';

void main() {
  testWidgets(
    'showConfirmDialog complete future (false) khi route bị pop bằng back thay vì bấm nút',
    (tester) async {
      bool? result;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return ElevatedButton(
                onPressed: () async {
                  result = await showConfirmDialog(context, title: 'Xoá?');
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Xoá?'), findsOneWidget);

      // Giả lập back button/gesture: pop route trực tiếp qua Navigator,
      // KHÔNG đi qua onTap của action nào (mô phỏng đúng hành vi hardware
      // back trên Android).
      Navigator.of(capturedContext, rootNavigator: true).pop();
      await tester.pumpAndSettle();

      expect(result, false);
    },
  );

  testWidgets('showConfirmDialog trả về true khi bấm nút confirm', (
    tester,
  ) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await showConfirmDialog(
                  context,
                  title: 'Xoá?',
                  confirmLabel: 'Yes',
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    expect(result, true);
  });

  testWidgets('showConfirmDialog trả về false khi bấm nút cancel', (
    tester,
  ) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await showConfirmDialog(
                  context,
                  title: 'Xoá?',
                  cancelLabel: 'No',
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    expect(result, false);
  });
}
