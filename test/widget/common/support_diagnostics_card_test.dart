import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

SupportDiagnosticsSummary summary({
  bool truncated = false,
  Map<String, String> errors = const {},
  List<String> sections = const ['health', 'logs'],
}) => SupportDiagnosticsSummary(
  appVersion: '1.2.3',
  generatedAtText: '10:30 UTC',
  sections: sections,
  truncated: truncated,
  errors: errors,
);

Widget subject({
  SupportDiagnosticsSummary? data,
  Future<void> Function()? onShare,
  Widget? preview,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  builder: (_, child) =>
      Directionality(textDirection: direction, child: child!),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SupportDiagnosticsCard(
            summary: data ?? summary(),
            onShare: onShare ?? () async {},
            preview: preview,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  test('validates typed summary fields, max size and labels', () {
    expect(
      () => SupportDiagnosticsSummary(
        appVersion: ' ',
        generatedAtText: 'now',
        sections: const [],
      ),
      throwsArgumentError,
    );
    expect(
      () => SupportDiagnosticsSummary(
        appVersion: '1',
        generatedAtText: ' ',
        sections: const [],
      ),
      throwsArgumentError,
    );
    expect(
      () => SupportDiagnosticsSummary(
        appVersion: '1',
        generatedAtText: 'now',
        sections: const [' '],
      ),
      throwsArgumentError,
    );
    expect(
      () => SupportDiagnosticsCard(
        summary: summary(),
        onShare: () async {},
        confirmLabel: ' ',
      ),
      throwsArgumentError,
    );
  });

  testWidgets('shows summary sections, truncation and safe error count only', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        data: summary(
          truncated: true,
          errors: const {'logs': 'secret exception text'},
        ),
      ),
    );
    expect(find.text('App 1.2.3'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('diagnosticsSection_health')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('diagnosticsSection_logs')),
      findsOneWidget,
    );
    expect(find.textContaining('omitted'), findsOneWidget);
    expect(find.text('1 section(s) could not be included.'), findsOneWidget);
    expect(find.text('secret exception text'), findsNothing);
  });

  testWidgets('share callback requires confirmation and busy blocks repeats', (
    tester,
  ) async {
    var calls = 0;
    final completer = Completer<void>();
    await tester.pumpWidget(
      subject(
        onShare: () {
          calls++;
          return completer.future;
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('diagnosticsShareButton')));
    await tester.pump();
    expect(calls, 0);
    expect(find.textContaining('shares the listed'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is CommonButton && widget.label == 'Confirm share',
      ),
    );
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is CommonButton && widget.label == 'Confirm share',
      ),
      warnIfMissed: false,
    );
    expect(calls, 1);
    completer.complete();
    await tester.pump();
    expect(find.textContaining('shares the listed'), findsNothing);
  });

  testWidgets('share errors show generic copy and allow retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      subject(
        onShare: () async {
          calls++;
          if (calls == 1) throw Exception('secret-token=123');
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('diagnosticsShareButton')));
    await tester.pump();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is CommonButton && widget.label == 'Confirm share',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Share failed. You can try again.'), findsOneWidget);
    expect(find.textContaining('secret-token'), findsNothing);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is CommonButton && widget.label == 'Confirm share',
      ),
    );
    await tester.pump();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview opens and closes without calling share', (tester) async {
    var shares = 0;
    await tester.pumpWidget(
      subject(
        preview: const Text('Safe redacted preview'),
        onShare: () async => shares++,
      ),
    );
    await tester.tap(find.text('Preview'));
    await tester.pump();
    expect(find.text('Safe redacted preview'), findsOneWidget);
    expect(shares, 0);
    await tester.tap(find.text('Close preview'));
    await tester.pump();
    expect(find.text('Safe redacted preview'), findsNothing);
  });

  testWidgets(
    'semantics announce title/version/section count and share action',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(subject());
        final node = tester.getSemantics(find.byType(SupportDiagnosticsCard));
        expect(node.label, contains('Support diagnostics'));
        expect(node.label, contains('version 1.2.3'));
        expect(node.label, contains('2 sections'));
        expect(
          tester
              .getSemantics(
                find.byKey(const ValueKey('diagnosticsShareButton')),
              )
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets('320dp, 2x text and RTL do not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      subject(
        scale: 2,
        direction: TextDirection.rtl,
        preview: const Text('Preview'),
      ),
    );
    expect(
      Directionality.of(tester.element(find.byType(SupportDiagnosticsCard))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirm and preview overlays can be toggled then unmounted', (
    tester,
  ) async {
    await tester.pumpWidget(subject(preview: const Text('preview')));
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const ValueKey('diagnosticsShareButton')));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.tap(find.text('Preview'));
      await tester.pump();
      await tester.tap(find.text('Close preview'));
      await tester.pump();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
