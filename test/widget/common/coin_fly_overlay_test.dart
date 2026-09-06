import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/coin_fly_overlay.dart';

void main() {
  testWidgets(
    'CoinFlyOverlay.show flies coinCount coins to the target, calling '
    'onArrive once per coin, then self-removes',
    (tester) async {
      final targetKey = GlobalKey();
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return Scaffold(
                body: Align(
                  alignment: Alignment.topRight,
                  child: SizedBox(key: targetKey, width: 40, height: 40),
                ),
              );
            },
          ),
        ),
      );

      var arrivedCount = 0;
      CoinFlyOverlay.show(
        ctx,
        from: const Offset(10, 500),
        targetKey: targetKey,
        coinCount: 3,
        duration: const Duration(milliseconds: 200),
        stagger: const Duration(milliseconds: 50),
        onArrive: () => arrivedCount++,
      );

      // 1 frame để OverlayEntry được insert + controller đầu tiên forward().
      await tester.pump();
      expect(find.byType(CoinFlyOverlay), findsOneWidget);
      expect(find.byIcon(Icons.monetization_on), findsNWidgets(3));
      expect(arrivedCount, 0);

      // Timeline dùng chung: duration=200ms + stagger*2=100ms → tổng
      // 300ms. Coin cuối "đến đích" đúng ở mốc 300ms.
      for (var i = 0; i < 7; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      expect(arrivedCount, 3);
      expect(find.byType(CoinFlyOverlay), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CoinFlyOverlay (widget trần) gọi onDone đúng 1 lần sau coin cuối đến '
    'đích, dispose sạch mọi AnimationController',
    (tester) async {
      var arrivedCount = 0;
      var doneCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CoinFlyOverlay(
              from: const Offset(0, 0),
              to: const Offset(100, 100),
              coinCount: 4,
              duration: const Duration(milliseconds: 150),
              stagger: const Duration(milliseconds: 30),
              onArrive: () => arrivedCount++,
              onDone: () => doneCount++,
            ),
          ),
        ),
      );

      for (var i = 0; i < 7; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(arrivedCount, 4);
      expect(doneCount, 1);
      expect(tester.takeException(), isNull);

      // Unmount ngay sau khi xong — controller phải dispose sạch, không ném
      // lỗi "used after being disposed".
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Unmount CoinFlyOverlay giữa chừng animation không leak '
    'AnimationController',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CoinFlyOverlay(
              from: const Offset(0, 0),
              to: const Offset(200, 200),
              coinCount: 5,
              duration: const Duration(milliseconds: 500),
              stagger: const Duration(milliseconds: 60),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Unmount giữa chừng (chưa hết duration, vài coin còn chưa start
      // forward()) — dispose() phải chạy sạch cho mọi controller kể cả cái
      // chưa từng forward().
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CoinFlyOverlay.show no-ops khi targetKey chưa attach vào render object',
    (tester) async {
      final targetKey = GlobalKey();
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      CoinFlyOverlay.show(ctx, from: Offset.zero, targetKey: targetKey);
      await tester.pump();

      expect(find.byType(CoinFlyOverlay), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
