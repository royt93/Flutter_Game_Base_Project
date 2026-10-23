import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/experiment_variant_assignment_card.dart';
import 'package:roy_casual_kit/presentation/widgets/common/onboarding_flow_queue_card.dart';

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

OnboardingFlowRow _flow(
  String id, {
  bool seen = false,
  bool next = false,
  int priority = 0,
  String? label,
}) => OnboardingFlowRow(
  flowId: id,
  label: label ?? 'Flow ${id.replaceAll('internal_', '')}',
  priority: priority,
  version: 1,
  isSeen: seen,
  isNext: next,
);

ExperimentVariantRow _exp({
  String key = 'shop',
  String assigned = 'control',
  bool overridden = false,
}) => ExperimentVariantRow(
  experimentKey: key,
  label: 'Shop layout',
  assignedVariant: assigned,
  availableVariants: ['control', 'wide'],
  isOverridden: overridden,
);

void main() {
  group('OnboardingFlowQueueCard', () {
    test('validates rows and copy', () {
      expect(() => _flow(' '), throwsArgumentError);
      expect(
        () => OnboardingFlowRow(
          flowId: 'a',
          label: ' ',
          priority: 0,
          version: 1,
          isSeen: false,
        ),
        throwsArgumentError,
      );
      expect(
        () => OnboardingFlowRow(
          flowId: 'a',
          label: 'A',
          priority: 0,
          version: 0,
          isSeen: false,
        ),
        throwsArgumentError,
      );
      expect(() => _flow('a', seen: true, next: true), throwsArgumentError);
      expect(
        () => OnboardingFlowQueueCard(rows: [], maxVisibleRows: 0),
        throwsArgumentError,
      );
      expect(
        () => OnboardingFlowQueueCard(rows: [], title: ' '),
        throwsArgumentError,
      );
      expect(
        () => OnboardingFlowQueueCard(
          rows: [_flow('a', next: true), _flow('b', next: true)],
        ),
        throwsArgumentError,
      );
      expect(
        () => OnboardingFlowQueueCard(rows: [_flow('a'), _flow('a')]),
        throwsArgumentError,
      );
    });

    test('copies input rows', () {
      final mutable = [_flow('a')];
      final card = OnboardingFlowQueueCard(rows: mutable);
      mutable.clear();
      expect(card.rows, hasLength(1));
      expect(() => card.rows.add(_flow('b')), throwsUnsupportedError);
    });

    testWidgets('empty state', (tester) async {
      await tester.pumpWidget(_host(OnboardingFlowQueueCard(rows: [])));
      expect(find.text('No onboarding flows registered.'), findsOneWidget);
    });

    testWidgets('shows seen, next and pending without exposing flow ids', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          OnboardingFlowQueueCard(
            rows: [
              _flow('internal_seen', seen: true),
              _flow('internal_next', next: true, priority: 5),
              _flow('internal_later'),
            ],
          ),
        ),
      );
      expect(find.text('Seen'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Not seen yet'), findsOneWidget);
      expect(find.text('Priority: 5 · Version: 1'), findsOneWidget);
      expect(find.textContaining('internal_'), findsNothing);
    });

    testWidgets('caps rows and reports hidden count', (tester) async {
      await tester.pumpWidget(
        _host(
          OnboardingFlowQueueCard(
            rows: [for (var i = 0; i < 5; i++) _flow('f$i')],
            maxVisibleRows: 2,
          ),
        ),
      );
      expect(find.text('More flows hidden: 3'), findsOneWidget);
      expect(find.text('Flow f1'), findsOneWidget);
      expect(find.text('Flow f2'), findsNothing);
    });

    testWidgets('mark seen only for next row; callback gets flow id', (
      tester,
    ) async {
      final ids = <String>[];
      await tester.pumpWidget(
        _host(
          OnboardingFlowQueueCard(
            rows: [_flow('a', seen: true), _flow('b', next: true), _flow('c')],
            onMarkSeen: (id) async => ids.add(id),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('onboardingMarkSeen_a')), findsNothing);
      expect(find.byKey(const ValueKey('onboardingMarkSeen_c')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('onboardingMarkSeen_b')));
      await tester.pumpAndSettle();
      expect(ids, ['b']);
      expect(find.text('Seen'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('no next flow means no mark-seen action', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(
          OnboardingFlowQueueCard(
            rows: [_flow('a'), _flow('b', seen: true)],
            onMarkSeen: (_) async => calls++,
          ),
        ),
      );
      expect(find.byType(CommonButton), findsNothing);
      expect(calls, 0);
    });

    testWidgets('in-flight lock and generic failure copy', (tester) async {
      final done = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        _host(
          OnboardingFlowQueueCard(
            rows: [_flow('a', next: true), _flow('b')],
            onMarkSeen: (_) {
              calls++;
              return done.future;
            },
          ),
        ),
      );
      final first = find.byKey(const ValueKey('onboardingMarkSeen_a'));
      final second = find.byKey(const ValueKey('onboardingMarkSeen_b'));
      await tester.tap(first);
      await tester.pump();
      expect(tester.widget<CommonButton>(first).onTap, isNull);
      expect(second, findsNothing);
      expect(tester.widget<CommonButton>(first).loading, isTrue);
      await tester.tap(first, warnIfMissed: false);
      expect(calls, 1);
      done.completeError(StateError('private flow storage key'));
      await tester.pumpAndSettle();
      expect(find.text('Action failed. Try again.'), findsOneWidget);
      expect(find.textContaining('storage key'), findsNothing);
    });

    testWidgets('new rows ignore a late error but keep lock until done', (
      tester,
    ) async {
      final done = Completer<void>();
      Widget build(List<OnboardingFlowRow> rows) => _host(
        OnboardingFlowQueueCard(rows: rows, onMarkSeen: (_) => done.future),
      );
      await tester.pumpWidget(build([_flow('a', next: true), _flow('b')]));
      await tester.tap(find.byKey(const ValueKey('onboardingMarkSeen_a')));
      await tester.pump();
      await tester.pumpWidget(
        build([_flow('a', seen: true), _flow('b', next: true)]),
      );
      final actionB = find.byKey(const ValueKey('onboardingMarkSeen_b'));
      expect(tester.widget<CommonButton>(actionB).onTap, isNull);
      expect(tester.widget<CommonButton>(actionB).loading, isFalse);
      done.completeError(StateError('late'));
      await tester.pumpAndSettle();
      expect(find.text('Action failed. Try again.'), findsNothing);
      expect(tester.widget<CommonButton>(actionB).onTap, isNotNull);
    });

    testWidgets('unmount during action is safe', (tester) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        _host(
          OnboardingFlowQueueCard(
            rows: [_flow('a', next: true)],
            onMarkSeen: (_) => done.future,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('onboardingMarkSeen_a')));
      await tester.pumpWidget(const SizedBox.shrink());
      done.completeError(StateError('late'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits 320dp at 200% RTL with accessible action', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            OnboardingFlowQueueCard(
              rows: [_flow('a', next: true)],
              onMarkSeen: (_) async {},
            ),
            rtl: true,
            scale: 2,
          ),
        );
        final action = find.byKey(const ValueKey('onboardingMarkSeen_a'));
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

  group('ExperimentVariantAssignmentCard', () {
    test('validates rows and copy', () {
      expect(() => _exp(key: ' '), throwsArgumentError);
      expect(
        () => ExperimentVariantRow(
          experimentKey: 'k',
          label: ' ',
          assignedVariant: 'a',
          availableVariants: ['a'],
        ),
        throwsArgumentError,
      );
      expect(
        () => ExperimentVariantRow(
          experimentKey: 'k',
          label: 'K',
          assignedVariant: 'a',
          availableVariants: [],
        ),
        throwsArgumentError,
      );
      expect(
        () => ExperimentVariantRow(
          experimentKey: 'k',
          label: 'K',
          assignedVariant: 'missing',
          availableVariants: ['a', 'b'],
        ),
        throwsArgumentError,
      );
      expect(
        () => ExperimentVariantRow(
          experimentKey: 'k',
          label: 'K',
          assignedVariant: 'a',
          availableVariants: ['a', 'a'],
        ),
        throwsArgumentError,
      );
      expect(
        () => ExperimentVariantAssignmentCard(rows: [_exp(), _exp()]),
        throwsArgumentError,
      );
      expect(
        () => ExperimentVariantAssignmentCard(rows: [], title: ' '),
        throwsArgumentError,
      );
    });

    test('copies input lists', () {
      final variants = ['a', 'b'];
      final row = ExperimentVariantRow(
        experimentKey: 'k',
        label: 'K',
        assignedVariant: 'a',
        availableVariants: variants,
      );
      variants.clear();
      expect(row.availableVariants, ['a', 'b']);
      expect(() => row.availableVariants.add('c'), throwsUnsupportedError);
    });

    testWidgets('empty state', (tester) async {
      await tester.pumpWidget(_host(ExperimentVariantAssignmentCard(rows: [])));
      expect(find.text('No experiments registered.'), findsOneWidget);
    });

    testWidgets('read-only by default; shows assignment, never the key', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(ExperimentVariantAssignmentCard(rows: [_exp(key: 'secret_key')])),
      );
      expect(find.text('Assigned variant: control'), findsOneWidget);
      expect(find.byType(CommonButton), findsNothing);
      expect(find.textContaining('secret_key'), findsNothing);
      expect(find.text('Overridden for testing'), findsNothing);
    });

    testWidgets('override choices exclude the assigned variant', (
      tester,
    ) async {
      final calls = <(String, String?)>[];
      await tester.pumpWidget(
        _host(
          ExperimentVariantAssignmentCard(
            rows: [_exp()],
            onSelectOverride: (k, v) async => calls.add((k, v)),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('experimentOverride_shop_control')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CommonButton>(
              find.byKey(const ValueKey('experimentOverride_shop_control')),
            )
            .onTap,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey('experimentOverride_shop_wide')),
      );
      await tester.pumpAndSettle();
      expect(calls, [('shop', 'wide')]);
      expect(find.text('Assigned variant: control'), findsOneWidget);
    });

    testWidgets('overridden row shows badge and clear action', (tester) async {
      final calls = <(String, String?)>[];
      await tester.pumpWidget(
        _host(
          ExperimentVariantAssignmentCard(
            rows: [_exp(assigned: 'wide', overridden: true)],
            onSelectOverride: (k, v) async => calls.add((k, v)),
          ),
        ),
      );
      expect(find.text('Overridden for testing'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('experimentClear_shop')));
      await tester.pumpAndSettle();
      expect(calls, [('shop', null)]);
    });

    testWidgets('in-flight lock and generic failure copy', (tester) async {
      final done = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        _host(
          ExperimentVariantAssignmentCard(
            rows: [_exp()],
            onSelectOverride: (_, _) {
              calls++;
              return done.future;
            },
          ),
        ),
      );
      final action = find.byKey(const ValueKey('experimentOverride_shop_wide'));
      await tester.tap(action);
      await tester.pump();
      expect(tester.widget<CommonButton>(action).onTap, isNull);
      await tester.tap(action, warnIfMissed: false);
      expect(calls, 1);
      done.completeError(StateError('private anonymous id'));
      await tester.pumpAndSettle();
      expect(find.text('Action failed. Try again.'), findsOneWidget);
      expect(find.textContaining('anonymous id'), findsNothing);
    });

    testWidgets('changed rows ignore a late error', (tester) async {
      final done = Completer<void>();
      Widget build(ExperimentVariantRow row) => _host(
        ExperimentVariantAssignmentCard(
          rows: [row],
          onSelectOverride: (_, _) => done.future,
        ),
      );
      await tester.pumpWidget(build(_exp()));
      await tester.tap(
        find.byKey(const ValueKey('experimentOverride_shop_wide')),
      );
      await tester.pump();
      await tester.pumpWidget(build(_exp(assigned: 'wide', overridden: true)));
      done.completeError(StateError('late'));
      await tester.pumpAndSettle();
      expect(find.text('Action failed. Try again.'), findsNothing);
    });

    testWidgets('unmount during action is safe', (tester) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        _host(
          ExperimentVariantAssignmentCard(
            rows: [_exp()],
            onSelectOverride: (_, _) => done.future,
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('experimentOverride_shop_wide')),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      done.completeError(StateError('late'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits 320dp at 200% RTL with accessible action', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            ExperimentVariantAssignmentCard(
              rows: [_exp()],
              onSelectOverride: (_, _) async {},
            ),
            rtl: true,
            scale: 2,
          ),
        );
        final action = find.byKey(
          const ValueKey('experimentOverride_shop_wide'),
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
