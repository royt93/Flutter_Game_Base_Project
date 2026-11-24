import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/card_flip_3d.dart';
import 'package:roy_casual_kit/presentation/widgets/common/currency_counter.dart';
import 'package:roy_casual_kit/presentation/widgets/common/expandable_panel.dart';
import 'package:roy_casual_kit/presentation/widgets/common/icon_badge_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/ribbon_badge.dart';
import 'package:roy_casual_kit/presentation/widgets/common/star_rating.dart';
import 'package:roy_casual_kit/presentation/widgets/common/streak_counter.dart';

/// ENH-117 regression tests: each widget that owns an AnimationController plus
/// a CurvedAnimation (or per-build curves) must release them when unmounted.
/// These fail under leak tracking if a `dispose()` is removed or a
/// `CurvedAnimation` is created per build again.
Widget _host(Widget child) => MaterialApp(home: Material(child: child));

Future<void> _mountThenUnmount(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(_host(child));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  testWidgets('CurrencyCounter releases its curve', (tester) async {
    await _mountThenUnmount(tester, const CurrencyCounter(value: 5));
  });

  testWidgets('CurrencyCounter keeps no curve after a value change', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const CurrencyCounter(value: 5)));
    await tester.pumpWidget(_host(const CurrencyCounter(value: 50)));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('StarRating releases per-star curves after rebuilds', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const StarRating(earned: 1, total: 3, animate: true)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(
      _host(const StarRating(earned: 3, total: 3, animate: true)),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('StreakCounter releases its curve', (tester) async {
    await _mountThenUnmount(tester, const StreakCounter(days: 3));
  });

  testWidgets('RibbonBadge releases its curve', (tester) async {
    await _mountThenUnmount(
      tester,
      const RibbonBadge(text: 'NEW', child: SizedBox(width: 40, height: 40)),
    );
  });

  testWidgets('IconBadgeButton releases its curve', (tester) async {
    await _mountThenUnmount(
      tester,
      IconBadgeButton(icon: Icons.mail, onTap: () {}),
    );
  });

  testWidgets('ExpandablePanel releases its curves', (tester) async {
    await _mountThenUnmount(
      tester,
      const ExpandablePanel(
        header: Text('Panel'),
        content: SizedBox(height: 20),
        isExpanded: true,
      ),
    );
  });

  testWidgets('CardFlip3D releases its curve', (tester) async {
    await _mountThenUnmount(
      tester,
      CardFlip3D(
        front: const SizedBox(width: 40, height: 40),
        back: const SizedBox(width: 40, height: 40),
      ),
    );
  });
}
