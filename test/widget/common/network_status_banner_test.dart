import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
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

  testWidgets(
    'ENH-17: Reduce Motion bật → banner hiện/ẩn ngay lập tức (duration = 0)',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MaterialApp(
            home: Material(child: NetworkStatusBanner(connected: false)),
          ),
        ),
      );
      // 1 frame duy nhất — không pumpAndSettle/pump(250ms) chờ entrance.
      await tester.pump();

      expect(find.text('No internet connection'), findsOneWidget);
      expect(
        tester.widget<AnimatedSize>(find.byType(AnimatedSize)).duration,
        Duration.zero,
      );
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration,
        Duration.zero,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'IDEA-21: dùng curve tường minh (easeOut), không phải Curves.linear mặc định',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(child: NetworkStatusBanner(connected: false)),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<AnimatedSize>(find.byType(AnimatedSize)).curve,
        Curves.easeOut,
      );
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).curve,
        Curves.easeOut,
      );
      expect(tester.takeException(), isNull);
    },
  );

  group('ENH-37: Semantics', () {
    testWidgets('connected: false → liveRegion + label khớp offlineMessage', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: NetworkStatusBanner(
              connected: false,
              offlineMessage: 'Mất kết nối mạng',
            ),
          ),
        ),
      );
      await tester.pump();

      final labelFinder = find.bySemanticsLabel('Mất kết nối mạng');
      expect(labelFinder, findsOneWidget);
      final data = tester.getSemantics(labelFinder);
      expect(data.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('connected: true → không hiển thị banner/label nào (đã ẩn)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: NetworkStatusBanner(
              connected: true,
              offlineMessage: 'Mất kết nối mạng',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Mất kết nối mạng'), findsNothing);
      handle.dispose();
    });
  });

  group('ENH-49: color', () {
    Container bannerContainer(WidgetTester tester) => tester.widget<Container>(
      find.ancestor(
        of: find.text('No internet connection'),
        matching: find.byType(Container),
      ),
    );

    testWidgets('không truyền → giữ nguyên default cũ NeonTheme.red', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(child: NetworkStatusBanner(connected: false)),
        ),
      );
      await tester.pump();

      expect(bannerContainer(tester).color, NeonTheme.red);
    });

    testWidgets('truyền color tuỳ chỉnh → banner dùng đúng màu đó', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: NetworkStatusBanner(connected: false, color: Colors.teal),
          ),
        ),
      );
      await tester.pump();

      expect(bannerContainer(tester).color, Colors.teal);
      expect(bannerContainer(tester).color, isNot(NeonTheme.red));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'NetworkStatusBanner.stream cũng forward đúng color xuống banner',
      (tester) async {
        final controller = StreamController<bool>();
        addTearDown(controller.close);

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: NetworkStatusBanner.stream(
                connected: controller.stream,
                initialConnected: false,
                color: Colors.deepOrange,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(bannerContainer(tester).color, Colors.deepOrange);
      },
    );
  });
}
