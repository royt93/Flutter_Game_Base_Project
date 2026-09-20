import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/adaptive_game_hud.dart';

/// pumpWidget's default test root imposes TIGHT constraints matching
/// `tester.view.physicalSize` — an inner SizedBox can never override that,
/// so the view itself must be resized to actually change what
/// AdaptiveGameHud's LayoutBuilder sees.
Future<void> _pump(
  WidgetTester tester,
  Widget hud, {
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  TextDirection textDirection = TextDirection.ltr,
  Size size = const Size(400, 800),
  double textScaleFactor = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        padding: padding,
        viewInsets: viewInsets,
        textScaler: TextScaler.linear(textScaleFactor),
      ),
      child: Directionality(textDirection: textDirection, child: hud),
    ),
  );
}

void main() {
  group('AdaptiveGameHud: safe area/cutout', () {
    testWidgets(
      'topStart/topCenter/topEnd nằm dưới đúng safe-area padding.top, không đè lên notch',
      (tester) async {
        await _pump(
          tester,
          const AdaptiveGameHud(
            slots: {
              HudSlot.topStart: SizedBox(
                key: Key('topStart'),
                width: 40,
                height: 20,
              ),
              HudSlot.topCenter: SizedBox(
                key: Key('topCenter'),
                width: 40,
                height: 20,
              ),
              HudSlot.topEnd: SizedBox(
                key: Key('topEnd'),
                width: 40,
                height: 20,
              ),
            },
          ),
          padding: const EdgeInsets.only(top: 44), // notch/status bar
        );

        for (final key in ['topStart', 'topCenter', 'topEnd']) {
          final topLeft = tester.getTopLeft(find.byKey(Key(key)));
          expect(
            topLeft.dy,
            greaterThanOrEqualTo(44),
            reason: '$key phải nằm dưới notch (padding.top=44)',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'bottom nằm trên đúng safe-area padding.bottom, không đè lên home indicator',
      (tester) async {
        await _pump(
          tester,
          const AdaptiveGameHud(
            slots: {
              HudSlot.bottom: SizedBox(
                key: Key('bottom'),
                width: 100,
                height: 20,
              ),
            },
          ),
          padding: const EdgeInsets.only(bottom: 34),
          size: const Size(400, 800),
        );

        final bottomLeft = tester.getBottomLeft(
          find.byKey(const Key('bottom')),
        );
        expect(800 - bottomLeft.dy, greaterThanOrEqualTo(34));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('AdaptiveGameHud: keyboard inset', () {
    testWidgets(
      'bottom di chuyển lên khi bàn phím mở (viewInsets.bottom > 0)',
      (tester) async {
        await _pump(
          tester,
          const AdaptiveGameHud(
            slots: {
              HudSlot.bottom: SizedBox(
                key: Key('bottom'),
                width: 100,
                height: 20,
              ),
            },
          ),
          size: const Size(400, 800),
        );
        final withoutKeyboard = tester.getBottomLeft(
          find.byKey(const Key('bottom')),
        );

        await _pump(
          tester,
          const AdaptiveGameHud(
            slots: {
              HudSlot.bottom: SizedBox(
                key: Key('bottom'),
                width: 100,
                height: 20,
              ),
            },
          ),
          viewInsets: const EdgeInsets.only(bottom: 300),
          size: const Size(400, 800),
        );
        final withKeyboard = tester.getBottomLeft(
          find.byKey(const Key('bottom')),
        );

        expect(withKeyboard.dy, lessThan(withoutKeyboard.dy));
        expect(800 - withKeyboard.dy, greaterThanOrEqualTo(300));
      },
    );
  });

  group('AdaptiveGameHud: breakpoint compact/expanded', () {
    testWidgets('width < compactBreakpointWidth: side bị ẩn', (tester) async {
      await _pump(
        tester,
        const AdaptiveGameHud(
          slots: {
            HudSlot.side: SizedBox(key: Key('side'), width: 40, height: 40),
          },
          compactBreakpointWidth: 600,
        ),
        size: const Size(400, 800), // portrait phone, dưới breakpoint
      );

      expect(find.byKey(const Key('side')), findsNothing);
    });

    testWidgets('width >= compactBreakpointWidth: side hiện đúng vị trí', (
      tester,
    ) async {
      await _pump(
        tester,
        const AdaptiveGameHud(
          slots: {
            HudSlot.side: SizedBox(key: Key('side'), width: 40, height: 40),
          },
          compactBreakpointWidth: 600,
        ),
        size: const Size(800, 400), // landscape/tablet, trên breakpoint
      );

      expect(find.byKey(const Key('side')), findsOneWidget);
    });

    testWidgets(
      'cùng 1 device xoay portrait -> landscape: side chuyển ẩn -> hiện deterministic',
      (tester) async {
        await _pump(
          tester,
          const AdaptiveGameHud(
            slots: {
              HudSlot.side: SizedBox(key: Key('side'), width: 40, height: 40),
            },
            compactBreakpointWidth: 600,
          ),
          size: const Size(400, 800),
        );
        expect(find.byKey(const Key('side')), findsNothing);

        await _pump(
          tester,
          const AdaptiveGameHud(
            slots: {
              HudSlot.side: SizedBox(key: Key('side'), width: 40, height: 40),
            },
            compactBreakpointWidth: 600,
          ),
          size: const Size(800, 400),
        );
        expect(find.byKey(const Key('side')), findsOneWidget);
      },
    );

    testWidgets('breakpointOf(context) trong slot đọc đúng giá trị hiện tại', (
      tester,
    ) async {
      HudBreakpoint? readInside;
      await _pump(
        tester,
        AdaptiveGameHud(
          slots: {
            HudSlot.topCenter: Builder(
              builder: (context) {
                readInside = AdaptiveGameHud.breakpointOf(context);
                return const SizedBox();
              },
            ),
          },
          compactBreakpointWidth: 600,
        ),
        size: const Size(800, 400),
      );

      expect(readInside, HudBreakpoint.expanded);
    });
  });

  group('AdaptiveGameHud: RTL', () {
    testWidgets('topStart/topEnd đổi vị trí vật lý đúng khi RTL', (
      tester,
    ) async {
      await _pump(
        tester,
        const AdaptiveGameHud(
          slots: {
            HudSlot.topStart: SizedBox(
              key: Key('topStart'),
              width: 40,
              height: 20,
            ),
            HudSlot.topEnd: SizedBox(key: Key('topEnd'), width: 40, height: 20),
          },
        ),
        size: const Size(400, 800),
      );
      final startLtr = tester.getTopLeft(find.byKey(const Key('topStart'))).dx;
      final endLtr = tester.getTopLeft(find.byKey(const Key('topEnd'))).dx;
      expect(startLtr, lessThan(endLtr)); // start bên trái trong LTR

      await _pump(
        tester,
        const AdaptiveGameHud(
          slots: {
            HudSlot.topStart: SizedBox(
              key: Key('topStart'),
              width: 40,
              height: 20,
            ),
            HudSlot.topEnd: SizedBox(key: Key('topEnd'), width: 40, height: 20),
          },
        ),
        textDirection: TextDirection.rtl,
        size: const Size(400, 800),
      );
      final startRtl = tester.getTopLeft(find.byKey(const Key('topStart'))).dx;
      final endRtl = tester.getTopLeft(find.byKey(const Key('topEnd'))).dx;
      expect(startRtl, greaterThan(endRtl)); // start bên phải trong RTL
    });

    testWidgets('side slot cũng đổi cạnh đúng khi RTL (neo end)', (
      tester,
    ) async {
      await _pump(
        tester,
        const AdaptiveGameHud(
          slots: {
            HudSlot.side: SizedBox(key: Key('side'), width: 40, height: 40),
          },
          compactBreakpointWidth: 0,
        ),
        size: const Size(800, 400),
      );
      final ltrX = tester.getTopLeft(find.byKey(const Key('side'))).dx;

      await _pump(
        tester,
        const AdaptiveGameHud(
          slots: {
            HudSlot.side: SizedBox(key: Key('side'), width: 40, height: 40),
          },
          compactBreakpointWidth: 0,
        ),
        textDirection: TextDirection.rtl,
        size: const Size(800, 400),
      );
      final rtlX = tester.getTopLeft(find.byKey(const Key('side'))).dx;

      // LTR: side neo end = bên phải (x lớn). RTL: side neo end = bên trái (x nhỏ).
      expect(ltrX, greaterThan(rtlX));
    });
  });

  group('AdaptiveGameHud: text scale không overflow', () {
    testWidgets(
      'textScaleFactor lớn (2.0) với text dài trong slot: không overflow/throw',
      (tester) async {
        await _pump(
          tester,
          const AdaptiveGameHud(
            slots: {
              HudSlot.topCenter: SizedBox(
                width: 200,
                child: Text(
                  'Điểm số rất dài để kiểm tra overflow',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            },
          ),
          textScaleFactor: 2.0,
          size: const Size(400, 800),
        );

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('AdaptiveGameHud: overlay', () {
    testWidgets('overlay phủ toàn bộ HUD khi có nội dung', (tester) async {
      await _pump(
        tester,
        const AdaptiveGameHud(
          slots: {
            HudSlot.overlay: ColoredBox(
              key: Key('overlay'),
              color: Color(0xFF000000),
            ),
          },
        ),
        size: const Size(400, 800),
      );

      final size = tester.getSize(find.byKey(const Key('overlay')));
      expect(size, const Size(400, 800));
    });

    testWidgets(
      'không có overlay: không dựng widget overlay nào (tránh chặn input)',
      (tester) async {
        await _pump(
          tester,
          const AdaptiveGameHud(),
          size: const Size(400, 800),
        );

        expect(find.byType(ColoredBox), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('AdaptiveGameHud: debugShowBounds', () {
    testWidgets('debugShowBounds=true bọc slot bằng DecoratedBox có border', (
      tester,
    ) async {
      await _pump(
        tester,
        const AdaptiveGameHud(
          debugShowBounds: true,
          slots: {
            HudSlot.topCenter: SizedBox(
              key: Key('content'),
              width: 40,
              height: 20,
            ),
          },
        ),
        size: const Size(400, 800),
      );

      expect(find.byType(DecoratedBox), findsWidgets);
    });

    testWidgets(
      'debugShowBounds=false (mặc định): không có DecoratedBox nào được thêm',
      (tester) async {
        await _pump(
          tester,
          const AdaptiveGameHud(
            slots: {
              HudSlot.topCenter: SizedBox(
                key: Key('content'),
                width: 40,
                height: 20,
              ),
            },
          ),
          size: const Size(400, 800),
        );

        expect(find.byType(DecoratedBox), findsNothing);
      },
    );
  });

  group('AdaptiveGameHud: Flame viewport bounds', () {
    testWidgets(
      'flameViewportBounds nhỏ hơn toàn màn hình: top/bottom slot tránh đè lên playfield',
      (tester) async {
        await _pump(
          tester,
          const AdaptiveGameHud(
            slots: {
              HudSlot.topCenter: SizedBox(
                key: Key('top'),
                width: 40,
                height: 20,
              ),
              HudSlot.bottom: SizedBox(
                key: Key('bottom'),
                width: 40,
                height: 20,
              ),
            },
            // Letterbox: playfield chỉ chiếm y=[100, 700] trong tổng 800.
            flameViewportBounds: Rect.fromLTRB(0, 100, 400, 700),
          ),
          size: const Size(400, 800),
        );

        final topPos = tester.getTopLeft(find.byKey(const Key('top')));
        final bottomPos = tester.getBottomLeft(find.byKey(const Key('bottom')));

        expect(topPos.dy, greaterThanOrEqualTo(100));
        expect(800 - bottomPos.dy, greaterThanOrEqualTo(100));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'flameViewportBounds null (mặc định): top/bottom chỉ dùng safe-area padding, không lệch thêm',
      (tester) async {
        await _pump(
          tester,
          const AdaptiveGameHud(
            slots: {
              HudSlot.topCenter: SizedBox(
                key: Key('top'),
                width: 40,
                height: 20,
              ),
            },
          ),
          size: const Size(400, 800),
        );

        final topPos = tester.getTopLeft(find.byKey(const Key('top')));
        expect(
          topPos.dy,
          8,
        ); // chỉ _edgeGap, không có safe padding lẫn viewport
      },
    );
  });

  group('AdaptiveGameHud: không rebuild toàn HUD khi 1 slot reactive đổi', () {
    testWidgets(
      'ValueListenableBuilder trong 1 slot rebuild độc lập, AdaptiveGameHud.build không chạy lại',
      (tester) async {
        final notifier = ValueNotifier<int>(0);
        var hudBuildCount = 0;

        Widget buildHud() => AdaptiveGameHud(
          slots: {
            HudSlot.topCenter: Builder(
              builder: (context) {
                hudBuildCount++;
                return ValueListenableBuilder<int>(
                  valueListenable: notifier,
                  builder: (context, value, _) => Text('$value'),
                );
              },
            ),
          },
        );

        await _pump(tester, buildHud(), size: const Size(400, 800));
        expect(hudBuildCount, 1);
        expect(find.text('0'), findsOneWidget);

        notifier.value = 1;
        await tester.pump();

        expect(find.text('1'), findsOneWidget);
        // Builder bên trong slot KHÔNG được build lại — chỉ
        // ValueListenableBuilder's builder chạy lại, chứng minh
        // AdaptiveGameHud không ép rebuild toàn bộ subtree của slot.
        expect(hudBuildCount, 1);
      },
    );
  });
}
