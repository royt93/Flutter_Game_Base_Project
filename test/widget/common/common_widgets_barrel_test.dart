import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: unused_import
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

/// IDEA-71: this file imports ONLY the `common_widgets.dart` barrel (plus
/// Flutter/flutter_test themselves) — no `example/` import anywhere. If the
/// barrel ever accidentally pulled in something that only resolves inside
/// `example/`'s own dependency graph, this file would fail to even compile,
/// catching the regression before any widget-level test does.
void main() {
  testWidgets('common_widgets.dart barrel compiles and resolves standalone', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    expect(tester.takeException(), isNull);
  });
}
