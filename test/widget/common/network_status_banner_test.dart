import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/network_status_banner.dart';

void main() {
  testWidgets('connected: false hiện banner offline', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: NetworkStatusBanner(connected: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No internet connection'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected: true ẩn banner', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: NetworkStatusBanner(connected: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No internet connection'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'toggle connected false -> true animate ẩn và không giữ lại AnimationController',
    (tester) async {
      var connected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Material(
              child: Column(
                children: [
                  NetworkStatusBanner(connected: connected),
                  TextButton(
                    onPressed: () => setState(() => connected = true),
                    child: const Text('go online'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No internet connection'), findsOneWidget);

      await tester.tap(find.text('go online'));
      await tester.pump();

      // pumpAndSettle() phải kết thúc (không timeout) — implicit
      // AnimatedSize/AnimatedOpacity dừng tick khi đạt giá trị đích, không
      // như NeonBg's permanent Ticker. Nếu có AnimationController bị giữ lại
      // đang chạy vô hạn, lệnh này sẽ timeout và ném lỗi.
      await tester.pumpAndSettle();

      expect(find.text('No internet connection'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('NetworkStatusBanner.stream phản ứng theo Stream<bool>', (
    tester,
  ) async {
    final controller = StreamController<bool>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: NetworkStatusBanner.stream(
            connected: controller.stream,
            initialConnected: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No internet connection'), findsNothing);

    controller.add(false);
    await tester.pumpAndSettle();
    expect(find.text('No internet connection'), findsOneWidget);
    expect(tester.takeException(), isNull);

    controller.add(true);
    await tester.pumpAndSettle();
    expect(find.text('No internet connection'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
