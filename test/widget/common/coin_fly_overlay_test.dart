import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/coin_fly_overlay.dart';

void main() {
  group('pure trajectory/scale math (no widget involved)', () {
    test('coinArcOffsetAt: t=0 is exactly from, t=1 is exactly to', () {
      const from = Offset(10, 500);
      const to = Offset(300, 50);
      expect(coinArcOffsetAt(from, to, 0, arcHeight: 80), from);
      expect(coinArcOffsetAt(from, to, 1, arcHeight: 80), to);
    });

    test(
      'IDEA-22: coinArcOffsetAt: quỹ đạo cong lên trên so với đường thẳng '
      'Offset.lerp thuần (arcHeight > 0)',
      () {
        const from = Offset(10, 500);
        const to = Offset(300, 50);
        final straight = Offset.lerp(from, to, 0.5)!;
        final arced = coinArcOffsetAt(from, to, 0.5, arcHeight: 80);

        expect(arced, isNot(straight));
        // dy nhỏ hơn (cong lên trên, trục y hướng xuống trong Flutter).
        expect(arced.dy, lessThan(straight.dy));
      },
    );

    test('coinArcOffsetAt: arcHeight = 0 trùng với đường thẳng Offset.lerp', () {
      const from = Offset(10, 500);
      const to = Offset(300, 50);
      final straight = Offset.lerp(from, to, 0.5)!;
      final arced = coinArcOffsetAt(from, to, 0.5, arcHeight: 0);
      expect(arced.dx, closeTo(straight.dx, 0.001));
      expect(arced.dy, closeTo(straight.dy, 0.001));
    });

    test(
      'IDEA-22: coinScaleAt: bắt đầu 1.0, đỉnh pop 1.2 giữa hành trình, '
      'squash 0.9 lúc đáp',
      () {
        expect(coinScaleAt(0), 1.0);
        expect(coinScaleAt(0.5), closeTo(1.2, 0.001));
        expect(coinScaleAt(1), closeTo(0.9, 0.001));
      },
    );
  });

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

  testWidgets(
    'ENH-17: Reduce Motion bật → coin bay tới đích ngay lập tức, onArrive/onDone gọi ngay',
    (tester) async {
      var arrivedCount = 0;
      var doneCount = 0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: CoinFlyOverlay(
                from: const Offset(0, 0),
                to: const Offset(100, 100),
                coinCount: 4,
                duration: const Duration(milliseconds: 550),
                stagger: const Duration(milliseconds: 70),
                onArrive: () => arrivedCount++,
                onDone: () => doneCount++,
              ),
            ),
          ),
        ),
      );

      // 1 frame duy nhất — không cần chờ nhiều bước như bản animate đầy đủ.
      await tester.pump();

      expect(arrivedCount, 4);
      expect(doneCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'IDEA-22: giữa hành trình, coin có scale pop (khác 1.0) và vị trí lệch '
    'khỏi đường thẳng Offset.lerp thuần',
    (tester) async {
      const from = Offset(0, 400);
      const to = Offset(300, 0);
      const coinSize = 22.0; // giá trị mặc định của CoinFlyOverlay.coinSize.
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CoinFlyOverlay(
              from: from,
              to: to,
              coinCount: 1,
              duration: const Duration(milliseconds: 300),
              stagger: Duration.zero,
            ),
          ),
        ),
      );

      // ~ giữa hành trình.
      await tester.pump(const Duration(milliseconds: 150));

      final scale = tester
          .widget<Transform>(find.byType(Transform))
          .transform
          .storage[0];
      expect(scale, isNot(1.0));

      // dx của bezier trùng đường thẳng khi control point nằm đúng giữa
      // theo trục x (chỉ lệch theo y, arcHeight kéo control point lên) —
      // nên chỉ `top` (dy) mới thực sự chứng minh quỹ đạo cong.
      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      final straightMidTop = Offset.lerp(from, to, 0.5)!.dy - coinSize / 2;
      expect(positioned.top, isNot(closeTo(straightMidTop, 0.01)));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'IDEA-22: Reduce Motion bật → bỏ qua quỹ đạo cong và scale pop giữa chừng',
    (tester) async {
      const from = Offset(0, 400);
      const to = Offset(300, 0);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: CoinFlyOverlay(
                from: from,
                to: to,
                coinCount: 4,
                duration: const Duration(milliseconds: 300),
                stagger: const Duration(milliseconds: 40),
              ),
            ),
          ),
        ),
      );

      // reducedMotion collapse toàn bộ timeline về 1 frame — không có
      // "giữa chừng" để kiểm tra scale/cong, chỉ cần đảm bảo build() không
      // ném lỗi khi _reducedMotion bỏ qua nhánh coinArcOffsetAt/coinScaleAt.
      await tester.pump();

      final scale = tester
          .widgetList<Transform>(find.byType(Transform))
          .first
          .transform
          .storage[0];
      expect(scale, 1.0);
      expect(tester.takeException(), isNull);
    },
  );
}
