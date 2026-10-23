import 'dart:async';
import 'dart:ui' show SemanticsAction;

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

const _erase = ValueKey('dataRightsErase');
const _eraseConfirm = ValueKey('dataRightsEraseConfirm');
const _eraseCancel = ValueKey('dataRightsEraseCancel');
const _export = ValueKey('dataRightsExport');

void main() {
  group('PlayerDataRightsPanel', () {
    test('rejects blank copy at runtime', () {
      expect(
        () => PlayerDataRightsPanel(
          onExport: () async {},
          onErase: () async {},
          title: ' ',
        ),
        throwsArgumentError,
      );
    });

    testWidgets('erase needs confirmation; cancel never calls back', (
      tester,
    ) async {
      var erased = 0;
      await tester.pumpWidget(
        _host(
          PlayerDataRightsPanel(
            onExport: () async {},
            onErase: () async => erased++,
          ),
        ),
      );
      await tester.tap(find.byKey(_erase));
      await tester.pump();
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(erased, 0);
      await tester.tap(find.byKey(_eraseCancel));
      await tester.pump();
      expect(erased, 0);
      expect(find.byKey(_eraseConfirm), findsNothing);

      await tester.tap(find.byKey(_erase));
      await tester.pump();
      await tester.tap(find.byKey(_eraseConfirm));
      await tester.pumpAndSettle();
      expect(erased, 1);
      expect(find.text('Your device data was erased.'), findsOneWidget);
      expect(find.byKey(_eraseConfirm), findsNothing);
    });

    testWidgets('export runs without confirmation and reports success', (
      tester,
    ) async {
      var exported = 0;
      await tester.pumpWidget(
        _host(
          PlayerDataRightsPanel(
            onExport: () async => exported++,
            onErase: () async {},
          ),
        ),
      );
      await tester.tap(find.byKey(_export));
      await tester.pumpAndSettle();
      expect(exported, 1);
      expect(find.text('Your data export is ready.'), findsOneWidget);
    });

    testWidgets('failure uses generic copy and never shows error text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PlayerDataRightsPanel(
            onExport: () async => throw StateError('secret user blob'),
            onErase: () async => throw StateError('secret path /data/x'),
          ),
        ),
      );
      await tester.tap(find.byKey(_export));
      await tester.pumpAndSettle();
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('secret'), findsNothing);

      await tester.tap(find.byKey(_erase));
      await tester.pump();
      await tester.tap(find.byKey(_eraseConfirm));
      await tester.pumpAndSettle();
      expect(find.textContaining('secret'), findsNothing);
      expect(find.byKey(_eraseConfirm), findsNothing);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'in-flight erase blocks every action; busy prop clears confirm',
      (tester) async {
        final done = Completer<void>();
        var erased = 0;
        Widget build(bool busy) => _host(
          PlayerDataRightsPanel(
            busy: busy,
            onExport: () async {},
            onErase: () {
              erased++;
              return done.future;
            },
          ),
        );
        await tester.pumpWidget(build(false));
        await tester.tap(find.byKey(_erase));
        await tester.pump();
        await tester.tap(find.byKey(_eraseConfirm));
        await tester.pump();
        expect(erased, 1);
        expect(tester.widget<CommonButton>(find.byKey(_export)).onTap, isNull);
        expect(tester.widget<CommonButton>(find.byKey(_erase)).onTap, isNull);
        done.complete();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_erase));
        await tester.pump();
        expect(find.byKey(_eraseConfirm), findsOneWidget);
        await tester.pumpWidget(build(true));
        expect(find.byKey(_eraseConfirm), findsNothing);
        expect(tester.widget<CommonButton>(find.byKey(_erase)).onTap, isNull);
      },
    );

    testWidgets('unmount during erase ignores late failure', (tester) async {
      final done = Completer<void>();
      await tester.pumpWidget(
        _host(
          PlayerDataRightsPanel(
            onExport: () async {},
            onErase: () => done.future,
          ),
        ),
      );
      await tester.tap(find.byKey(_erase));
      await tester.pump();
      await tester.tap(find.byKey(_eraseConfirm));
      await tester.pumpWidget(const SizedBox.shrink());
      done.completeError(StateError('late'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits 320dp at 200% RTL with labeled targets', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _host(
            PlayerDataRightsPanel(onExport: () async {}, onErase: () async {}),
            rtl: true,
            scale: 2,
          ),
        );
        await tester.tap(find.byKey(_erase));
        await tester.pump();
        await tester.ensureVisible(find.byKey(_eraseConfirm));
        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSemantics(find.byKey(_eraseConfirm))
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

  group('PrestigeReadinessCard', () {
    test('validates inputs', () {
      for (final bad in [
        () => PrestigeReadinessCard(
          current: 0,
          threshold: 0,
          multiplierText: 'x1',
          onPrestige: () {},
        ),
        () => PrestigeReadinessCard(
          current: -1,
          threshold: 10,
          multiplierText: 'x1',
          onPrestige: () {},
        ),
        () => PrestigeReadinessCard(
          current: 0,
          threshold: 10,
          multiplierText: ' ',
          onPrestige: () {},
        ),
      ]) {
        expect(bad, throwsArgumentError);
      }
    });

    testWidgets('disabled below threshold, enabled at and above it', (
      tester,
    ) async {
      var taps = 0;
      Widget build(int current, {bool busy = false}) => _host(
        PrestigeReadinessCard(
          current: current,
          threshold: 1000,
          multiplierText: 'Multiplier x1.0',
          busy: busy,
          onPrestige: () => taps++,
        ),
      );
      const action = ValueKey('prestigeReadinessAction');
      await tester.pumpWidget(build(999));
      expect(tester.widget<CommonButton>(find.byKey(action)).onTap, isNull);
      expect(find.text('Keep earning to prestige'), findsWidgets);
      expect(find.text('999 / 1,000'), findsOneWidget);

      await tester.pumpWidget(build(1000));
      await tester.tap(find.byKey(action));
      expect(taps, 1);
      expect(find.text('Prestige now'), findsWidgets);

      await tester.pumpWidget(build(5000));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        1.0,
      );

      await tester.pumpWidget(build(1000, busy: true));
      expect(tester.widget<CommonButton>(find.byKey(action)).onTap, isNull);
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
            PrestigeReadinessCard(
              current: 1000,
              threshold: 1000,
              multiplierText: 'Multiplier x1.5',
              onPrestige: () {},
            ),
            rtl: true,
            scale: 2,
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        handle.dispose();
      }
    });
  });

  group('CooldownActionButton', () {
    test('validates inputs', () {
      expect(
        () => CooldownActionButton(
          label: ' ',
          remaining: Duration.zero,
          onTap: () {},
        ),
        throwsArgumentError,
      );
      expect(
        () => CooldownActionButton(
          label: 'Go',
          remaining: const Duration(seconds: -1),
          onTap: () {},
        ),
        throwsArgumentError,
      );
    });

    testWidgets('ready button taps; waiting disables it and shows chip', (
      tester,
    ) async {
      var taps = 0;
      const button = ValueKey('cooldownActionButton');
      await tester.pumpWidget(
        _host(
          CooldownActionButton(
            label: 'Claim',
            remaining: Duration.zero,
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('cooldownActionChip')), findsNothing);
      await tester.tap(find.byKey(button));
      expect(taps, 1);

      await tester.pumpWidget(
        _host(
          CooldownActionButton(
            label: 'Claim',
            remaining: const Duration(seconds: 5),
            onTap: () => taps++,
          ),
        ),
      );
      expect(tester.widget<CommonButton>(find.byKey(button)).onTap, isNull);
      expect(find.byKey(const ValueKey('cooldownActionChip')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('onReady fires once when countdown ends; busy blocks taps', (
      tester,
    ) async {
      var ready = 0;
      await tester.pumpWidget(
        _host(
          CooldownActionButton(
            label: 'Claim',
            remaining: const Duration(seconds: 2),
            onTap: () {},
            onReady: () => ready++,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(ready, 1);
      await tester.pumpWidget(
        _host(
          CooldownActionButton(
            label: 'Claim',
            remaining: Duration.zero,
            busy: true,
            onTap: () {},
          ),
        ),
      );
      expect(
        tester
            .widget<CommonButton>(
              find.byKey(const ValueKey('cooldownActionButton')),
            )
            .onTap,
        isNull,
      );
    });
  });
}
