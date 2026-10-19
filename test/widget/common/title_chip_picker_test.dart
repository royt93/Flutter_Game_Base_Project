import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

final _options = [
  TitleOption(id: 'explorer', label: 'Explorer'),
  TitleOption(id: 'streak', label: 'Streak Master'),
  TitleOption(
    id: 'legend',
    label: 'Legendary Champion of the Realm',
    locked: true,
    unlockHint: 'Reach level 50',
  ),
];

Widget subject({
  List<TitleOption>? options,
  String? selected = 'explorer',
  ValueChanged<String?>? onSelect,
  ValueChanged<String>? onLockedTap,
  bool reducedMotion = false,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  builder: (_, child) =>
      Directionality(textDirection: direction, child: child!),
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reducedMotion,
      textScaler: TextScaler.linear(scale),
    ),
    child: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TitleChipPicker(
            options: options ?? _options,
            selectedId: selected,
            onSelect: onSelect ?? (_) {},
            onLockedTap: onLockedTap,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  test('validates ids, labels, selected id and copy at runtime', () {
    TitleChipPicker make({
      List<TitleOption>? options,
      String? selected = 'explorer',
      String none = 'No title',
    }) => TitleChipPicker(
      options: options ?? _options,
      selectedId: selected,
      noneLabel: none,
      onSelect: (_) {},
    );
    expect(
      () => make(
        options: [TitleOption(id: ' ', label: 'A')],
        selected: null,
      ),
      throwsArgumentError,
    );
    expect(
      () => make(
        options: [TitleOption(id: 'a', label: ' ')],
        selected: null,
      ),
      throwsArgumentError,
    );
    expect(
      () => make(
        options: [
          TitleOption(id: 'a', label: 'A'),
          TitleOption(id: 'a', label: 'B'),
        ],
        selected: null,
      ),
      throwsArgumentError,
    );
    expect(() => make(selected: 'missing'), throwsArgumentError);
    expect(() => make(selected: 'legend'), throwsArgumentError);
    expect(() => make(selected: null, none: ' '), throwsArgumentError);
    expect(() => make(selected: null), returnsNormally);
  });

  testWidgets('renders no-selection, selected, locked and empty options', (
    tester,
  ) async {
    await tester.pumpWidget(subject(selected: null));
    expect(find.text('No title'), findsOneWidget);
    expect(find.byKey(const ValueKey('titleChip_none')), findsOneWidget);
    expect(find.byKey(const ValueKey('titleChip_explorer')), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

    await tester.pumpWidget(subject(options: [], selected: null));
    expect(find.text('No title'), findsOneWidget);
  });

  testWidgets('selects unlocked title and the none option', (tester) async {
    final selections = <String?>[];
    await tester.pumpWidget(
      subject(selected: 'explorer', onSelect: selections.add),
    );
    await tester.tap(find.byKey(const ValueKey('titleChip_streak')));
    await tester.tap(find.byKey(const ValueKey('titleChip_none')));
    expect(selections, ['streak', null]);
  });

  testWidgets('locked title routes only to onLockedTap', (tester) async {
    final selections = <String?>[];
    final locked = <String>[];
    await tester.pumpWidget(
      subject(
        selected: 'explorer',
        onSelect: selections.add,
        onLockedTap: locked.add,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('titleChip_legend')));
    expect(selections, isEmpty);
    expect(locked, ['legend']);
  });

  testWidgets('locked title without handler is inert', (tester) async {
    final selections = <String?>[];
    await tester.pumpWidget(
      subject(selected: 'explorer', onSelect: selections.add),
    );
    await tester.tap(find.byKey(const ValueKey('titleChip_legend')));
    expect(selections, isEmpty);
  });

  testWidgets('chips have minimum 48dp targets and semantics', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        subject(selected: 'explorer', onLockedTap: (_) {}),
      );
      for (final key in [
        'titleChip_none',
        'titleChip_explorer',
        'titleChip_legend',
      ]) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('titleChip_explorer')))
            .label,
        'Explorer, Equipped',
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('titleChip_legend')))
            .label,
        'Legendary Champion of the Realm, Locked, Reach level 50',
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('titleChip_streak')))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('long labels wrap and truncate to at most two lines', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        selected: 'long',
        options: [
          TitleOption(
            id: 'long',
            label:
                'An Extraordinarily Long Player Title That Has More Than Two Lines',
          ),
        ],
      ),
    );
    expect(find.byKey(const ValueKey('titleChip_long')), findsOneWidget);
    final text = tester.widget<Text>(find.textContaining('An Extraordinarily'));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('320dp, text scale 2.0 and RTL wrap without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      subject(scale: 2, direction: TextDirection.rtl, selected: 'explorer'),
    );
    expect(
      Directionality.of(tester.element(find.byType(TitleChipPicker))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection change respects reduced motion and unmounts cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(subject(selected: 'explorer', reducedMotion: true));
    await tester.pumpWidget(subject(selected: 'streak', reducedMotion: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
