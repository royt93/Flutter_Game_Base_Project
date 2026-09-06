import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/loading_overlay.dart';

void main() {
  // LoadingOverlay.build() trả về Positioned.fill(...) trực tiếp nên PHẢI
  // được đặt trong 1 Stack thật, nếu không sẽ throw
  // "Positioned must be a direct child of Stack".
  testWidgets('LoadingOverlay render trong Stack không throw và hiện spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: Stack(children: [LoadingOverlay()])),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('LoadingOverlay hiện message khi được truyền', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: Stack(children: [LoadingOverlay(message: 'Loading...')]),
        ),
      ),
    );

    expect(find.text('Loading...'), findsOneWidget);
  });

  testWidgets('LoadingOverlay không hiện Text nào khi message == null', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: Stack(children: [LoadingOverlay()])),
      ),
    );

    expect(find.byType(Text), findsNothing);
  });

  testWidgets(
    'LoadingOverlay đặt ngoài Stack ném lỗi rõ ràng nhắc nhở bọc trong Stack',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(child: Center(child: LoadingOverlay())),
        ),
      );

      final exception = tester.takeException();
      expect(exception, isNotNull);
      expect(
        exception.toString(),
        contains('LoadingOverlay must be a direct child of a Stack'),
      );
    },
  );
}
