import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

List<BadgeShowcaseItem> _badges(int count) => [
  for (var i = 0; i < count; i++)
    BadgeShowcaseItem(
      id: 'badge_$i',
      label: 'Badge $i',
      icon: Icons.star_rounded,
    ),
];

Widget subject({
  int slots = 5,
  List<BadgeShowcaseItem> badges = const [],
  bool readOnly = false,
  ValueChanged<int>? onTap,
  bool reducedMotion = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: Scaffold(
      body: Center(
        child: BadgeShowcaseStrip(
          slotCount: slots,
          badges: badges,
          readOnly: readOnly,
          onSlotTap: onTap ?? (_) {},
        ),
      ),
    ),
  ),
);

void main() {
  test('validates slot count, badge count, id, label and unique IDs', () {
    BadgeShowcaseStrip make({
      int slots = 5,
      List<BadgeShowcaseItem> badges = const [],
    }) =>
        BadgeShowcaseStrip(slotCount: slots, badges: badges, onSlotTap: (_) {});
    expect(() => make(slots: 0), throwsArgumentError);
    expect(() => make(slots: 9), throwsArgumentError);
    expect(() => make(slots: 8), returnsNormally);
    expect(() => make(slots: 5, badges: _badges(6)), throwsArgumentError);
    expect(
      () => make(
        badges: [BadgeShowcaseItem(id: ' ', label: 'A')],
      ),
      throwsArgumentError,
    );
    expect(
      () => make(
        badges: [BadgeShowcaseItem(id: 'a', label: ' ')],
      ),
      throwsArgumentError,
    );
    expect(
      () => make(
        badges: [
          BadgeShowcaseItem(id: 'a', label: 'A'),
          BadgeShowcaseItem(id: 'a', label: 'B'),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => BadgeShowcaseItem(
        id: 'a',
        label: 'A',
        icon: Icons.star,
        child: const Text('A'),
      ),
      throwsArgumentError,
    );
  });

  testWidgets('zero, partial and full slots keep fixed slot count', (
    tester,
  ) async {
    for (final count in [0, 2, 5]) {
      await tester.pumpWidget(subject(slots: 5, badges: _badges(count)));
      expect(find.byKey(const ValueKey('badgeShowcaseList')), findsOneWidget);
      expect(find.byType(GestureDetector), findsNWidgets(5));
      expect(find.text('Badge 0'), count == 0 ? findsNothing : findsOneWidget);
      expect(
        find.text('Empty badge slot'),
        count == 5 ? findsNothing : findsWidgets,
      );
    }
  });

  testWidgets('empty and occupied slots route their exact index', (
    tester,
  ) async {
    final tapped = <int>[];
    await tester.pumpWidget(
      subject(slots: 4, badges: _badges(2), onTap: tapped.add),
    );
    await tester.tap(find.byKey(const ValueKey('badgeShowcaseSlot_1')));
    await tester.tap(find.byKey(const ValueKey('badgeShowcaseSlot_3')));
    expect(tapped, [1, 3]);
  });

  testWidgets('read-only keeps all positions but disables callbacks', (
    tester,
  ) async {
    final tapped = <int>[];
    await tester.pumpWidget(
      subject(slots: 4, badges: _badges(2), readOnly: true, onTap: tapped.add),
    );
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('badgeShowcaseSlot_$i')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('badgeShowcaseSlot_0')));
    await tester.tap(find.byKey(const ValueKey('badgeShowcaseSlot_3')));
    expect(tapped, isEmpty);
  });

  testWidgets('each slot has a >=48dp target and position-aware semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(subject(slots: 3, badges: _badges(1)));
      for (var i = 0; i < 3; i++) {
        expect(
          tester.getSize(find.byKey(ValueKey('badgeShowcaseSlot_$i'))).height,
          greaterThanOrEqualTo(48),
        );
        final node = tester.getSemantics(
          find.byKey(ValueKey('badgeShowcaseSlot_$i')),
        );
        expect(node.label, contains('${i + 1},'));
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      }
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('badgeShowcaseSlot_0')))
            .label,
        '1, Badge 0',
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('badgeShowcaseSlot_2')))
            .label,
        '3, Empty badge slot',
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets(
    'many slots are lazy and horizontal scrolling reveals later slots',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(subject(slots: 8, badges: _badges(8)));
      final list = find.byKey(const ValueKey('badgeShowcaseList'));
      expect(find.byKey(const ValueKey('badgeShowcaseSlot_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('badgeShowcaseSlot_7')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('badgeShowcaseSlot_7')),
        180,
        scrollable: find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.byKey(const ValueKey('badgeShowcaseSlot_7')), findsOneWidget);
    },
  );

  testWidgets('320dp and 2x text stay unclipped; RTL is applied', (
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
          child: Scaffold(
            body: BadgeShowcaseStrip(
              slotCount: 5,
              badges: [
                BadgeShowcaseItem(
                  id: 'long',
                  label: 'An extraordinarily long displayed badge name',
                ),
              ],
              onSlotTap: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(
      Directionality.of(tester.element(find.byType(BadgeShowcaseStrip))),
      TextDirection.rtl,
    );
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing badge content preserves slot layout and pulses once', (
    tester,
  ) async {
    await tester.pumpWidget(subject(slots: 3, badges: _badges(1)));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(subject(slots: 3, badges: _badges(2)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byKey(const ValueKey('badgeShowcaseSlot_2')), findsOneWidget);
  });

  testWidgets('reduced motion disables pulse; unmount disposes controller', (
    tester,
  ) async {
    await tester.pumpWidget(subject(slots: 3, badges: _badges(1)));
    await tester.pumpWidget(
      subject(slots: 3, badges: _badges(2), reducedMotion: true),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
