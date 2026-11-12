import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('ENH-105: chuỗi mặc định có thể ghi đè (localize ở consumer)', () {
    testWidgets('OutboxConflictSummaryPanel: emptyLabel + remoteLabel', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          OutboxConflictSummaryPanel(
            conflicts: const [],
            onResolve: (_, _) async {},
            emptyLabel: 'Không có thay đổi cần xem.',
          ),
        ),
      );
      expect(find.text('Không có thay đổi cần xem.'), findsOneWidget);
      expect(find.text('No queued changes need review.'), findsNothing);

      await tester.pumpWidget(
        host(
          OutboxConflictSummaryPanel(
            conflicts: [
              OutboxConflictSummary(
                reference: 'r1',
                localLabel: 'Local A',
                remoteLabel: 'B',
              ),
            ],
            onResolve: (_, _) async {},
            remoteLabel: 'Máy chủ',
          ),
        ),
      );
      expect(find.text('Máy chủ: B'), findsOneWidget);
      expect(find.text('Remote: B'), findsNothing);
    });

    testWidgets('SessionTimelineInspector: durationLabel', (tester) async {
      await tester.pumpWidget(
        host(
          SessionTimelineInspector(
            rows: const [],
            durationText: '12:30',
            durationLabel: 'Thời lượng',
          ),
        ),
      );
      expect(find.text('Thời lượng: 12:30'), findsOneWidget);
      expect(find.textContaining('Duration'), findsNothing);
    });

    testWidgets('SupportDiagnosticsCard: app/truncated/privacy/errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SupportDiagnosticsCard(
            summary: SupportDiagnosticsSummary(
              appVersion: '1.2.3',
              generatedAtText: '10:30',
              sections: const ['health'],
              truncated: true,
              errors: const {'logs': 'x'},
            ),
            onShare: () async {},
            appVersionLabel: 'Phiên bản',
            truncatedLabel: 'Một số mục đã bị lược bớt.',
            privacyNote: 'Chỉ chia sẻ sau khi xác nhận.',
            sectionErrorsLabel: (n) => '$n mục bị lỗi.',
          ),
        ),
      );
      expect(find.text('Phiên bản 1.2.3'), findsOneWidget);
      expect(find.text('Một số mục đã bị lược bớt.'), findsOneWidget);
      expect(find.text('Chỉ chia sẻ sau khi xác nhận.'), findsOneWidget);
      expect(find.text('1 mục bị lỗi.'), findsOneWidget);
    });

    test('blank override bị từ chối', () {
      expect(
        () => OutboxConflictSummaryPanel(
          conflicts: const [],
          onResolve: (_, _) async {},
          remoteLabel: ' ',
        ),
        throwsArgumentError,
      );
    });
  });
}
