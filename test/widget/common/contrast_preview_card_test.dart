import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

void main() {
  test('computes WCAG luminance ratios and defaults text thresholds', () {
    final blackWhite = ContrastPreviewCard(
      foreground: Colors.black,
      background: Colors.white,
      sampleText: 'Sample',
    );
    expect(blackWhite.contrastRatio, closeTo(21, 0.01));
    expect(blackWhite.effectiveThreshold, 4.5);
    expect(blackWhite.passes, isTrue);

    final identical = ContrastPreviewCard(
      foreground: Colors.black,
      background: Colors.black,
      sampleText: 'Sample',
    );
    expect(identical.contrastRatio, 1);
    expect(identical.passes, isFalse);

    final large = ContrastPreviewCard(
      foreground: const Color(0xFF777777),
      background: Colors.white,
      sampleText: 'Large sample',
      largeText: true,
    );
    expect(large.effectiveThreshold, 3);
    expect(large.passes, isTrue);
  });

  test('validates threshold and copy at runtime', () {
    ContrastPreviewCard make({
      String sample = 'Sample',
      double? threshold,
      String? semantic,
      String pass = 'Pass',
      String fail = 'Fail',
    }) => ContrastPreviewCard(
      foreground: Colors.black,
      background: Colors.white,
      sampleText: sample,
      threshold: threshold,
      semanticLabel: semantic,
      passLabel: pass,
      failLabel: fail,
    );
    expect(() => make(sample: ' '), throwsArgumentError);
    expect(() => make(threshold: 0), throwsArgumentError);
    expect(() => make(threshold: -1), throwsArgumentError);
    expect(() => make(threshold: double.nan), throwsArgumentError);
    expect(() => make(threshold: double.infinity), throwsArgumentError);
    expect(() => make(semantic: ' '), throwsArgumentError);
    expect(() => make(pass: ' '), throwsArgumentError);
    expect(() => make(fail: ' '), throwsArgumentError);
    expect(() => make(threshold: 7), returnsNormally);
  });

  testWidgets('shows normal and large text pass/fail states explicitly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ContrastPreviewCard(
                foreground: Colors.black,
                background: Colors.white,
                sampleText: 'Pass sample',
              ),
              ContrastPreviewCard(
                foreground: const Color(0xFFAAAAAA),
                background: Colors.white,
                sampleText: 'Fail sample',
              ),
              ContrastPreviewCard(
                foreground: const Color(0xFF777777),
                background: Colors.white,
                sampleText: 'Large text pass',
                largeText: true,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Pass'), findsWidgets);
    expect(find.text('Needs more contrast'), findsOneWidget);
    expect(find.text('Large text pass'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    expect(find.text('21.00:1'), findsOneWidget);
  });

  testWidgets('custom threshold and tap callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContrastPreviewCard(
            foreground: const Color(0xFF777777),
            background: Colors.white,
            sampleText: 'Sample',
            threshold: 4.4,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    expect(find.text('Pass'), findsOneWidget);
    expect(find.text('Threshold 4.4:1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('contrastPreviewTap')));
    expect(taps, 1);
  });

  testWidgets('semantics report contrast ratio and result', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContrastPreviewCard(
              foreground: Colors.black,
              background: Colors.white,
              sampleText: 'Readable text',
              onTap: () {},
            ),
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(ContrastPreviewCard));
      expect(node.label, contains('Pass'));
      expect(node.label, contains('21.00:1'));
      expect(node.label, contains('Readable text'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('320dp, text scale 2.0 and RTL keep status readable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            home: Scaffold(
              body: ContrastPreviewCard(
                foreground: Colors.white,
                background: Colors.white,
                sampleText: 'Cannot distinguish by color alone',
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Needs more contrast'), findsOneWidget);
    expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
