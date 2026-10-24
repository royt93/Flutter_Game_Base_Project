import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

Widget _host(Widget child, {bool rtl = false, double scale = 1}) => MaterialApp(
  builder: (context, c) => Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: c!,
    ),
  ),
  home: Scaffold(body: child),
);

void main() {
  group('EventSchemaAuditSnapshot', () {
    test('validates aggregate counters', () {
      expect(
        () => EventSchemaAuditSnapshot(
          totalValidations: -1,
          rejectedCount: 0,
          redactedCount: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => EventSchemaAuditSnapshot(
          totalValidations: 2,
          rejectedCount: 3,
          redactedCount: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => EventSchemaAuditSnapshot(
          totalValidations: 2,
          rejectedCount: 0,
          redactedCount: 3,
        ),
        throwsArgumentError,
      );
      expect(
        () => EventSchemaAuditSnapshot(
          totalValidations: 2,
          rejectedCount: 2,
          redactedCount: 1,
        ),
        throwsArgumentError,
      );
    });

    test('identifies an empty history', () {
      expect(
        EventSchemaAuditSnapshot(
          totalValidations: 0,
          rejectedCount: 0,
          redactedCount: 0,
        ).isEmpty,
        isTrue,
      );
    });
  });

  group('EventSchemaAuditCard', () {
    test('validates copy', () {
      expect(
        () => EventSchemaAuditCard(
          snapshot: EventSchemaAuditSnapshot(
            totalValidations: 1,
            rejectedCount: 0,
            redactedCount: 0,
          ),
          title: ' ',
        ),
        throwsArgumentError,
      );
      expect(
        () => EventSchemaAuditCard(
          snapshot: EventSchemaAuditSnapshot(
            totalValidations: 1,
            rejectedCount: 0,
            redactedCount: 0,
          ),
          deliveryNote: '',
        ),
        throwsArgumentError,
      );
    });

    testWidgets('empty state never claims analytics delivery', (tester) async {
      await tester.pumpWidget(
        _host(
          EventSchemaAuditCard(
            snapshot: EventSchemaAuditSnapshot(
              totalValidations: 0,
              rejectedCount: 0,
              redactedCount: 0,
            ),
          ),
        ),
      );
      expect(find.text('No schema validations yet.'), findsOneWidget);
      expect(
        find.text('Schema validation does not confirm analytics delivery.'),
        findsOneWidget,
      );
    });

    testWidgets('shows accepted, rejected and redacted aggregate counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          EventSchemaAuditCard(
            snapshot: EventSchemaAuditSnapshot(
              totalValidations: 12,
              rejectedCount: 3,
              redactedCount: 2,
            ),
          ),
        ),
      );
      expect(find.text('Accepted validations: 9'), findsOneWidget);
      expect(find.text('Rejected validations: 3'), findsOneWidget);
      expect(find.text('Validations with redacted fields: 2'), findsOneWidget);
      expect(find.byType(Icon), findsNWidgets(3));
      expect(
        find.text('Schema validation does not confirm analytics delivery.'),
        findsOneWidget,
      );
    });

    testWidgets('never renders schema or parameter diagnostics', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          EventSchemaAuditCard(
            snapshot: EventSchemaAuditSnapshot(
              totalValidations: 1,
              rejectedCount: 1,
              redactedCount: 0,
            ),
          ),
        ),
      );
      expect(find.textContaining('event_name'), findsNothing);
      expect(find.textContaining('email'), findsNothing);
      expect(find.textContaining('private-value'), findsNothing);
      expect(find.textContaining('unknown event'), findsNothing);
    });

    testWidgets('fits 320dp at 200% RTL', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            EventSchemaAuditCard(
              snapshot: EventSchemaAuditSnapshot(
                totalValidations: 12,
                rejectedCount: 3,
                redactedCount: 2,
              ),
            ),
            rtl: true,
            scale: 2,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSemantics(find.text('Rejected validations: 3'))
              .getSemanticsData()
              .label,
          contains('Rejected validations: 3'),
        );
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });
  });
}
