import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/replay_verification_result_card.dart';

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
  group('ReplayVerificationResultCard', () {
    test('validates status/count consistency and copy', () {
      expect(
        () => ReplayVerificationResultCard(
          status: ReplayVerificationStatus.matched,
          checkedOutcomeCount: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => ReplayVerificationResultCard(
          status: ReplayVerificationStatus.notChecked,
          checkedOutcomeCount: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => ReplayVerificationResultCard(
          status: ReplayVerificationStatus.diverged,
          checkedOutcomeCount: 3,
          divergenceIndex: 3,
        ),
        throwsArgumentError,
      );
      expect(
        () => ReplayVerificationResultCard(
          status: ReplayVerificationStatus.matched,
          checkedOutcomeCount: 1,
          divergenceIndex: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => ReplayVerificationResultCard(
          status: ReplayVerificationStatus.matched,
          checkedOutcomeCount: 1,
          rngStatus: ReplayRngCheckStatus.mismatched,
        ),
        throwsArgumentError,
      );
      expect(
        () => ReplayVerificationResultCard(
          status: ReplayVerificationStatus.notChecked,
          checkedOutcomeCount: 0,
          rngStatus: ReplayRngCheckStatus.notChecked,
          rngMismatchCount: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => ReplayVerificationResultCard(
          status: ReplayVerificationStatus.notChecked,
          checkedOutcomeCount: 0,
          title: ' ',
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative counts, index and blank optional copy', () {
      for (final build in <ReplayVerificationResultCard Function()>[
        () => ReplayVerificationResultCard(
          status: ReplayVerificationStatus.invalid,
          checkedOutcomeCount: -1,
        ),
        () => ReplayVerificationResultCard(
          status: ReplayVerificationStatus.notChecked,
          checkedOutcomeCount: 0,
          rngMismatchCount: -1,
        ),
        () => ReplayVerificationResultCard(
          status: ReplayVerificationStatus.diverged,
          checkedOutcomeCount: 2,
          divergenceIndex: -1,
        ),
        () => ReplayVerificationResultCard(
          status: ReplayVerificationStatus.diverged,
          checkedOutcomeCount: 0,
        ),
        () => ReplayVerificationResultCard(
          status: ReplayVerificationStatus.notChecked,
          checkedOutcomeCount: 0,
          summaryText: ' ',
        ),
      ]) {
        expect(build, throwsArgumentError);
      }
    });

    testWidgets('distinguishes unchecked, matched, diverged and invalid', (
      tester,
    ) async {
      for (final (status, count, label) in [
        (
          ReplayVerificationStatus.notChecked,
          0,
          'No replay comparison was checked.',
        ),
        (
          ReplayVerificationStatus.matched,
          4,
          'Checked recorded outcomes matched.',
        ),
        (
          ReplayVerificationStatus.diverged,
          4,
          'Checked recorded outcomes differed.',
        ),
        (ReplayVerificationStatus.invalid, 0, 'Replay could not be verified.'),
      ]) {
        await tester.pumpWidget(
          _host(
            ReplayVerificationResultCard(
              status: status,
              checkedOutcomeCount: count,
              divergenceIndex: status == ReplayVerificationStatus.diverged
                  ? 2
                  : null,
            ),
          ),
        );
        expect(find.text(label), findsOneWidget);
        expect(
          find.text(
            'Only checked outcomes are summarized. This is not proof of fair play.',
          ),
          findsOneWidget,
        );
        if (status == ReplayVerificationStatus.diverged) {
          expect(find.text('Compared outcome index: 2'), findsOneWidget);
        }
      }
    });

    testWidgets('reports RNG check skipped separately from matched', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ReplayVerificationResultCard(
            status: ReplayVerificationStatus.matched,
            checkedOutcomeCount: 2,
          ),
        ),
      );
      expect(find.text('Randomness check was not run.'), findsOneWidget);
      expect(find.text('Checked randomness state matched.'), findsNothing);

      await tester.pumpWidget(
        _host(
          ReplayVerificationResultCard(
            status: ReplayVerificationStatus.matched,
            checkedOutcomeCount: 2,
            rngStatus: ReplayRngCheckStatus.matched,
          ),
        ),
      );
      expect(find.text('Checked randomness state matched.'), findsOneWidget);
      expect(find.text('Randomness check was not run.'), findsNothing);

      await tester.pumpWidget(
        _host(
          ReplayVerificationResultCard(
            status: ReplayVerificationStatus.diverged,
            checkedOutcomeCount: 1,
            rngStatus: ReplayRngCheckStatus.mismatched,
            rngMismatchCount: 3,
          ),
        ),
      );
      expect(find.text('Randomness state differed: 3'), findsOneWidget);
    });

    testWidgets('verify callback never changes caller-owned status', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ReplayVerificationResultCard(
            status: ReplayVerificationStatus.notChecked,
            checkedOutcomeCount: 0,
            onVerifyAgain: () async {},
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('replayVerificationVerifyAgain')),
      );
      await tester.pumpAndSettle();
      expect(find.text('No replay comparison was checked.'), findsOneWidget);
      expect(find.text('Checked recorded outcomes matched.'), findsNothing);
    });

    testWidgets('locks concurrent action and hides exception text', (
      tester,
    ) async {
      final done = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        _host(
          ReplayVerificationResultCard(
            status: ReplayVerificationStatus.notChecked,
            checkedOutcomeCount: 0,
            onVerifyAgain: () {
              calls++;
              return done.future;
            },
          ),
        ),
      );
      final action = find.byKey(
        const ValueKey('replayVerificationVerifyAgain'),
      );
      await tester.tap(action);
      await tester.pump();
      expect(tester.widget<CommonButton>(action).onTap, isNull);
      await tester.tap(action);
      await tester.pump();
      expect(calls, 1);
      done.completeError(StateError('private capsule secret payload'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Verification failed. Try again.'), findsOneWidget);
      expect(find.textContaining('capsule secret'), findsNothing);
    });

    testWidgets('updated result ignores late failure but retains lock', (
      tester,
    ) async {
      final done = Completer<void>();
      var calls = 0;
      Widget build(ReplayVerificationStatus status) => _host(
        ReplayVerificationResultCard(
          status: status,
          checkedOutcomeCount: status == ReplayVerificationStatus.matched
              ? 2
              : 0,
          onVerifyAgain: () {
            calls++;
            return done.future;
          },
        ),
      );
      await tester.pumpWidget(build(ReplayVerificationStatus.notChecked));
      final action = find.byKey(
        const ValueKey('replayVerificationVerifyAgain'),
      );
      await tester.tap(action);
      await tester.pump();
      await tester.pumpWidget(build(ReplayVerificationStatus.matched));
      expect(tester.widget<CommonButton>(action).onTap, isNull);
      done.completeError(StateError('stale failure'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Verification failed. Try again.'), findsNothing);
      expect(find.text('Checked recorded outcomes matched.'), findsOneWidget);
      expect(tester.widget<CommonButton>(action).onTap, isNotNull);
    });

    testWidgets(
      'summary-only update clears error and external busy disables action',
      (tester) async {
        Widget build(String summary, {bool busy = false}) => _host(
          ReplayVerificationResultCard(
            status: ReplayVerificationStatus.notChecked,
            checkedOutcomeCount: 0,
            summaryText: summary,
            busy: busy,
            onVerifyAgain: () async => throw StateError('private failure'),
          ),
        );
        final action = find.byKey(
          const ValueKey('replayVerificationVerifyAgain'),
        );
        await tester.pumpWidget(build('Previous check'));
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text('Verification failed. Try again.'), findsOneWidget);
        await tester.pumpWidget(build('New check'));
        expect(find.text('Verification failed. Try again.'), findsNothing);
        await tester.pumpWidget(build('New check', busy: true));
        expect(tester.widget<CommonButton>(action).onTap, isNull);
      },
    );

    testWidgets('unmount during verify ignores late failure', (tester) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        _host(
          ReplayVerificationResultCard(
            status: ReplayVerificationStatus.notChecked,
            checkedOutcomeCount: 0,
            onVerifyAgain: () => done.future,
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('replayVerificationVerifyAgain')),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      done.completeError(StateError('late error'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits 320dp at 200% RTL with labeled action', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            ReplayVerificationResultCard(
              status: ReplayVerificationStatus.diverged,
              checkedOutcomeCount: 8,
              divergenceIndex: 7,
              rngStatus: ReplayRngCheckStatus.mismatched,
              rngMismatchCount: 2,
              summaryText: 'Only caller-approved summary text.',
              onVerifyAgain: () async {},
            ),
            rtl: true,
            scale: 2,
          ),
        );
        final action = find.byKey(
          const ValueKey('replayVerificationVerifyAgain'),
        );
        await tester.ensureVisible(action);
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSemantics(action)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });
  });
}
