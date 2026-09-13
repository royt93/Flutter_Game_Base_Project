import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/spotlight_overlay.dart';

void main() {
  Widget harness(GlobalKey targetKey, {VoidCallback? onDismiss}) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 200, left: 40),
                child: SizedBox(
                  key: targetKey,
                  width: 120,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Target'),
                  ),
                ),
              ),
            ),
            SpotlightOverlay(
              targetKey: targetKey,
              message: 'Nhấn vào đây để bắt đầu',
              title: 'Bước 1',
              holePadding: 12,
              onDismiss: onDismiss ?? () {},
            ),
          ],
        ),
      ),
    );
  }

  testWidgets(
    'SpotlightOverlay tính hole trùng khớp RenderBox thật của target (đã +holePadding)',
    (tester) async {
      final targetKey = GlobalKey();
      await tester.pumpWidget(harness(targetKey));
      await tester.pump();

      final targetRect = tester.getRect(find.byKey(targetKey));
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('spotlightOverlayPainter')),
                  )
                  .painter
              as SpotlightHolePainter;

      expect(painter.hole, targetRect.inflate(12));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SpotlightOverlay hiện title/message/nút dismiss, tap nút gọi onDismiss',
    (tester) async {
      final targetKey = GlobalKey();
      var dismissed = false;
      await tester.pumpWidget(
        harness(targetKey, onDismiss: () => dismissed = true),
      );
      await tester.pump();

      expect(find.text('Bước 1'), findsOneWidget);
      expect(find.text('Nhấn vào đây để bắt đầu'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pump();

      expect(dismissed, isTrue);
    },
  );

  testWidgets(
    'ENH-39: buttonLabel tuỳ chỉnh → hiện đúng chuỗi đó thay vì default "Got it"',
    (tester) async {
      final targetKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 200, left: 40),
                    child: SizedBox(
                      key: targetKey,
                      width: 120,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Text('Target'),
                      ),
                    ),
                  ),
                ),
                SpotlightOverlay(
                  targetKey: targetKey,
                  message: 'Nhấn vào đây để bắt đầu',
                  title: 'Bước 1',
                  buttonLabel: 'Đã hiểu',
                  onDismiss: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Got it'), findsNothing);
      expect(find.text('Đã hiểu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('SpotlightOverlay không crash khi targetKey chưa được mount', (
    tester,
  ) async {
    final targetKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpotlightOverlay(
            targetKey: targetKey,
            message: 'Không có target',
            onDismiss: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('spotlightOverlayPainter')),
                )
                .painter
            as SpotlightHolePainter;
    expect(painter.hole, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ENH-27: callout có entrance animation (scale+fade, easeOutBack, 250ms)',
    (tester) async {
      final targetKey = GlobalKey();
      await tester.pumpWidget(harness(targetKey));
      await tester.pump();

      final builders = tester.widgetList<TweenAnimationBuilder<double>>(
        find.byType(TweenAnimationBuilder<double>),
      );
      final calloutBuilder = builders.firstWhere(
        (b) => b.curve == Curves.easeOutBack,
      );
      expect(calloutBuilder.duration, const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ENH-27: scrim có fade-in riêng (AnimatedOpacity/TweenAnimationBuilder), không throw',
    (tester) async {
      final targetKey = GlobalKey();
      await tester.pumpWidget(harness(targetKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('spotlightOverlayPainter')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  group('ENH-38: RTL', () {
    Widget harness(GlobalKey targetKey, TextDirection dir) {
      return MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: dir,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 200, left: 40),
                    child: SizedBox(
                      key: targetKey,
                      width: 120,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Text('Target'),
                      ),
                    ),
                  ),
                ),
                SpotlightOverlay(
                  targetKey: targetKey,
                  message: 'Nhấn vào đây để bắt đầu',
                  title: 'Bước 1',
                  holePadding: 12,
                  onDismiss: () {},
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('LTR: nút dismiss nằm ở nửa bên phải của callout', (
      tester,
    ) async {
      final targetKey = GlobalKey();
      await tester.pumpWidget(harness(targetKey, TextDirection.ltr));
      await tester.pump();

      final calloutRect = tester.getRect(find.text('Bước 1'));
      final buttonRect = tester.getRect(find.text('Got it'));
      expect(buttonRect.center.dx, greaterThan(calloutRect.center.dx));
    });

    testWidgets(
      'RTL: cùng layout → nút dismiss nằm ở nửa bên TRÁI của callout (đảo ngược so với LTR)',
      (tester) async {
        final targetKey = GlobalKey();
        await tester.pumpWidget(harness(targetKey, TextDirection.rtl));
        await tester.pump();

        final calloutRect = tester.getRect(find.text('Bước 1'));
        final buttonRect = tester.getRect(find.text('Got it'));
        expect(buttonRect.center.dx, lessThan(calloutRect.center.dx));
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets(
    'ENH-27: Reduce Motion bật → entrance collapse (duration = 0), UI vẫn hiện đúng',
    (tester) async {
      final targetKey = GlobalKey();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: harness(targetKey),
        ),
      );
      await tester.pump();

      final builders = tester.widgetList<TweenAnimationBuilder<double>>(
        find.byType(TweenAnimationBuilder<double>),
      );
      expect(builders.every((b) => b.duration == Duration.zero), isTrue);
      expect(find.text('Bước 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  group('ENH-48: stepIndicator/onSkip', () {
    testWidgets(
      'không truyền stepIndicator/onSkip (dùng độc lập, không qua TutorialSequence) → không hiện gì thêm',
      (tester) async {
        final targetKey = GlobalKey();
        await tester.pumpWidget(harness(targetKey));
        await tester.pump();

        expect(find.textContaining('Step'), findsNothing);
        expect(find.text('Skip'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('truyền stepIndicator → hiện đúng caption đó phía trên title', (
      tester,
    ) async {
      final targetKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 200, left: 40),
                    child: SizedBox(
                      key: targetKey,
                      width: 120,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Text('Target'),
                      ),
                    ),
                  ),
                ),
                SpotlightOverlay(
                  targetKey: targetKey,
                  message: 'Nhấn vào đây để bắt đầu',
                  title: 'Bước 1',
                  stepIndicator: 'Step 1/3',
                  onDismiss: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Step 1/3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'truyền onSkip → hiện nút Skip, tap gọi đúng callback (không phải onDismiss)',
      (tester) async {
        final targetKey = GlobalKey();
        var dismissed = false;
        var skipped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 200, left: 40),
                      child: SizedBox(
                        key: targetKey,
                        width: 120,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {},
                          child: const Text('Target'),
                        ),
                      ),
                    ),
                  ),
                  SpotlightOverlay(
                    targetKey: targetKey,
                    message: 'Nhấn vào đây để bắt đầu',
                    title: 'Bước 1',
                    onDismiss: () => dismissed = true,
                    onSkip: () => skipped = true,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Skip'), findsOneWidget);

        await tester.tap(find.text('Skip'));
        await tester.pump();

        expect(skipped, isTrue);
        expect(dismissed, isFalse);
      },
    );

    testWidgets('skipLabel tuỳ chỉnh → hiện đúng chuỗi đó thay vì "Skip"', (
      tester,
    ) async {
      final targetKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 200, left: 40),
                    child: SizedBox(
                      key: targetKey,
                      width: 120,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Text('Target'),
                      ),
                    ),
                  ),
                ),
                SpotlightOverlay(
                  targetKey: targetKey,
                  message: 'Nhấn vào đây để bắt đầu',
                  onDismiss: () {},
                  onSkip: () {},
                  skipLabel: 'Bỏ qua',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Skip'), findsNothing);
      expect(find.text('Bỏ qua'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
