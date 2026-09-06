import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/badge_dot.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/currency_counter.dart';
import 'package:roy_casual_kit/presentation/widgets/common/icon_badge_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/streak_counter.dart';

/// ENH-09: none of the candy-style widgets had been rendered under a large
/// a11y text scale before. Pumps [child] under a phone-width viewport (not
/// the default oversized test window, which would hide real overflow bugs)
/// with `MediaQuery.textScaler` pinned to 2.0x and lets the caller assert on
/// `tester.takeException()` — both a generic exception and a
/// "RenderFlex overflowed" layout error surface there.
Future<void> _pumpAt2x(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2.0)),
          child: Material(child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('CommonButton (primary) không vỡ layout ở text scale 2.0x', (
    tester,
  ) async {
    await _pumpAt2x(
      tester,
      Center(
        child: CommonButton(label: 'Primary', width: 140, onTap: () {}),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'CommonButton (danger, label dài) không vỡ layout ở text scale 2.0x',
    (tester) async {
      await _pumpAt2x(
        tester,
        Center(
          child: CommonButton(
            label: 'Delete save file',
            width: 140,
            variant: CommonButtonVariant.danger,
            onTap: () {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('BadgeDot không vỡ layout ở text scale 2.0x', (tester) async {
    await _pumpAt2x(
      tester,
      const Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_none_rounded, size: 32),
          Positioned(top: -2, right: -2, child: BadgeDot()),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'IconBadgeButton với badgeCount lớn không vỡ layout ở text scale 2.0x',
    (tester) async {
      await _pumpAt2x(
        tester,
        IconBadgeButton(
          icon: Icons.mail_rounded,
          semanticLabel: 'Mail',
          badgeCount: 123,
          onTap: () {},
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  // Bonus coverage beyond the AC minimum: CurrencyCounter/StreakCounter both
  // lay out an Icon+Text in a plain `Row(mainAxisSize: MainAxisSize.min)`.
  //
  // FINDING (see ENH-09 report, not fixed here): a large standalone value —
  // e.g. `CurrencyCounter(value: 12345678)`, the showcase screen's own
  // second demo line — used to overflow (`FittedBox` fix applied to
  // `currency_counter.dart` for that case). But placed next to a
  // fixed-width sibling in a `mainAxisSize.min` Row (the showcase screen's
  // *first* CurrencyCounter demo: counter + "+25" button) it STILL
  // overflows once the value grows past ~6 digits (confirmed manually with
  // value: 999999 -> "RenderFlex overflowed by 36 pixels"), because an
  // inflexible Row child is laid out with an unbounded max width — the
  // child's own internal FittedBox never gets a width to shrink into. That
  // needs a `Flexible`/`Expanded` at the *call site* (outside this task's
  // file scope), not something fixable inside CurrencyCounter itself. The
  // case below stays within the demo's realistic value range (matches
  // `_coins` in widget_showcase_screen.dart, which only grows by +25/tap)
  // and passes; it is not a stand-in for the finding above.
  testWidgets(
    'CurrencyCounter cạnh CommonButton (giá trị thực tế) không vỡ layout ở text scale 2.0x',
    (tester) async {
      await _pumpAt2x(
        tester,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CurrencyCounter(value: 100),
            const SizedBox(width: 24),
            CommonButton(label: '+25', width: 90, onTap: () {}),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CurrencyCounter đứng riêng, giá trị lớn (12345678) không vỡ layout ở text scale 2.0x',
    (tester) async {
      // Same value as the showcase screen's standalone CurrencyCounter demo
      // (the one NOT next to a button) — used to overflow before the
      // Flexible+FittedBox fix in currency_counter.dart.
      await _pumpAt2x(tester, const CurrencyCounter(value: 12345678));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('StreakCounter không vỡ layout ở text scale 2.0x', (
    tester,
  ) async {
    await _pumpAt2x(tester, const StreakCounter(days: 365));

    expect(tester.takeException(), isNull);
  });
}
