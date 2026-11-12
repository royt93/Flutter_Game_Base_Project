// FEAT-200: viewport sweep — pumps a widget at small/landscape/tablet sizes
// and fails on overflow or when the target leaves the viewport. Separate from
// golden_matrix.dart so it never multiplies golden files.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ViewportCase {
  const ViewportCase(this.name, this.size);
  final String name;
  final Size size;
}

const defaultViewports = [
  ViewportCase('320x480', Size(320, 480)),
  ViewportCase('360x640', Size(360, 640)),
  ViewportCase('568x320-landscape', Size(568, 320)),
  ViewportCase('640x320-landscape', Size(640, 320)),
  ViewportCase('768x1024-tablet', Size(768, 1024)),
];

/// Pumps [build] at each viewport (text scale [textScale]) and checks no
/// exception and, when [targetFinder] is given, that its rect horizontally
/// fits the viewport. Vertical overflow is allowed only when the widget
/// scrolls (an exception would have been thrown otherwise).
Future<void> runViewportSweep(
  WidgetTester tester,
  Widget Function() build, {
  Finder? targetFinder,
  List<ViewportCase> viewports = defaultViewports,
  double textScale = 1.0,
}) async {
  addTearDown(tester.view.reset);
  for (final v in viewports) {
    tester.view.physicalSize = v.size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: v.size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: build()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      tester.takeException(),
      isNull,
      reason: 'overflow/exception at ${v.name}',
    );
    if (targetFinder != null) {
      final rect = tester.getRect(targetFinder.first);
      expect(
        rect.left,
        greaterThanOrEqualTo(-0.5),
        reason: 'left edge at ${v.name}',
      );
      expect(
        rect.right,
        lessThanOrEqualTo(v.size.width + 0.5),
        reason: 'right edge at ${v.name}',
      );
    }
  }
}
