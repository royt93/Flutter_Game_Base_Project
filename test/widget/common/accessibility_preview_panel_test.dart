import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

Widget _host({
  required Widget preview,
  List<GlobalKey> targets = const [],
  VoidCallback? onClose,
  double parentScale = 1.3,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(parentScale)),
    child: Scaffold(
      body: Center(
        child: SizedBox(
          height: 500,
          child: Column(
            children: [
              const Text('Outside'),
              Expanded(
                child: AccessibilityPreviewPanel(
                  preview: preview,
                  targets: targets,
                  onClose: onClose,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  test('validates targets, labels and max height at runtime', () {
    final duplicate = GlobalKey();
    expect(
      () => AccessibilityPreviewPanel(
        preview: const Text('Preview'),
        targets: [duplicate, duplicate],
      ),
      throwsArgumentError,
    );
    expect(
      () => AccessibilityPreviewPanel(
        preview: const Text('Preview'),
        closeLabel: ' ',
      ),
      throwsArgumentError,
    );
    expect(
      () => AccessibilityPreviewPanel(
        preview: const Text('Preview'),
        scaleLabel: ' ',
      ),
      throwsArgumentError,
    );
    expect(
      () => AccessibilityPreviewPanel(
        preview: const Text('Preview'),
        targetLabel: ' ',
      ),
      throwsArgumentError,
    );
    expect(
      () => AccessibilityPreviewPanel(
        preview: const Text('Preview'),
        maxHeight: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => AccessibilityPreviewPanel(
        preview: const Text('Preview'),
        maxHeight: double.infinity,
      ),
      throwsArgumentError,
    );
  });

  testWidgets('changes only preview MediaQuery text scaler', (tester) async {
    final previewTextKey = GlobalKey();
    await tester.pumpWidget(
      _host(
        preview: Center(child: Text('Preview text', key: previewTextKey)),
      ),
    );
    final outside = MediaQuery.textScalerOf(
      tester.element(find.text('Outside')),
    ).scale(1);
    final before = tester.getSize(find.text('Preview text'));
    await tester.tap(find.text('200%'));
    await tester.pump();
    final after = tester.getSize(find.text('Preview text'));
    expect(outside, 1.3);
    expect(after.height, greaterThan(before.height));
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(previewTextKey)),
      ).scale(1),
      2,
    );
    expect(
      MediaQuery.textScalerOf(tester.element(find.text('Outside'))).scale(1),
      1.3,
    );
  });

  testWidgets('target highlights follow GlobalKey position and update scale', (
    tester,
  ) async {
    final targetKey = GlobalKey();
    await tester.pumpWidget(
      _host(
        preview: Padding(
          padding: const EdgeInsets.all(24),
          child: Align(
            alignment: Alignment.topLeft,
            child: ElevatedButton(
              key: targetKey,
              onPressed: () {},
              child: const Text('Target'),
            ),
          ),
        ),
        targets: [targetKey],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('accessibilityTargetToggle')));
    await tester.pumpAndSettle();
    var highlights = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.key?.toString().contains('accessibilityTarget_') == true,
    );
    expect(highlights, findsOneWidget);
    final before = tester.getRect(highlights);
    await tester.tap(find.text('200%'));
    await tester.pumpAndSettle();
    highlights = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.key?.toString().contains('accessibilityTarget_') == true,
    );
    expect(highlights, findsOneWidget);
    expect(tester.getRect(highlights).top, greaterThanOrEqualTo(before.top));
  });

  testWidgets('target list empty draws no highlight', (tester) async {
    await tester.pumpWidget(_host(preview: const Text('No target')));
    await tester.tap(find.byKey(const ValueKey('accessibilityTargetToggle')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.key?.toString().contains('accessibilityTarget_') == true,
      ),
      findsNothing,
    );
  });

  testWidgets('close callback and semantics are available', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      var closes = 0;
      await tester.pumpWidget(
        _host(preview: const Text('Sample'), onClose: () => closes++),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Preview text size',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Show touch targets',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Close preview'));
      expect(closes, 1);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('320dp and 200% preview stay bounded without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _host(
        preview: const Column(
          children: [
            Text('First sample'),
            Text('Second sample'),
            Text('Third'),
          ],
        ),
        parentScale: 2,
      ),
    );
    await tester.tap(find.text('200%'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid scale/highlight changes unmount without ticker', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      _host(
        preview: SizedBox(key: key, width: 80, height: 40),
        targets: [key],
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.text(i.isEven ? '130%' : '200%'));
      await tester.tap(find.byKey(const ValueKey('accessibilityTargetToggle')));
      await tester.pump();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
