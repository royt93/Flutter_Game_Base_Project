import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

const _demoOptions = [
  AvatarFrameOption(id: 'classic', label: 'Classic Cyan', color: Colors.cyan),
  AvatarFrameOption(id: 'neon', label: 'Neon Purple', color: Colors.purple),
  AvatarFrameOption(
    id: 'gold',
    label: 'Golden Legend',
    color: Colors.amber,
    locked: true,
    lockHint: 'Reach level 50',
  ),
  AvatarFrameOption(
    id: 'fire',
    label: 'Fire Streak',
    color: Colors.deepOrange,
    locked: true,
  ),
];

Widget subject({
  List<AvatarFrameOption> options = _demoOptions,
  String? selectedId = 'classic',
  ValueChanged<String>? onSelect,
  ValueChanged<String>? onLockedTap,
  double scale = 1,
  bool reducedMotion = false,
  TextDirection direction = TextDirection.ltr,
  bool expand = false,
}) => MaterialApp(
  builder: (_, child) =>
      Directionality(textDirection: direction, child: child!),
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reducedMotion,
    ),
    child: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: expand
              ? SizedBox(
                  height: 400,
                  child: AvatarFrameSelector(
                    options: options,
                    selectedId: selectedId,
                    onSelect: onSelect ?? (_) {},
                    onLockedTap: onLockedTap,
                    previewChild: const Icon(Icons.person),
                    expand: true,
                  ),
                )
              : AvatarFrameSelector(
                  options: options,
                  selectedId: selectedId,
                  onSelect: onSelect ?? (_) {},
                  onLockedTap: onLockedTap,
                  previewChild: const Icon(Icons.person),
                ),
        ),
      ),
    ),
  ),
);

void main() {
  test('validates ids, labels, selectedId and height at runtime', () {
    AvatarFrameSelector make({
      List<AvatarFrameOption> options = _demoOptions,
      String? selected = 'classic',
      double height = 300,
    }) => AvatarFrameSelector(
      options: options,
      selectedId: selected,
      onSelect: (_) {},
      previewChild: const SizedBox.shrink(),
      maxGridHeight: height,
    );

    expect(
      () => make(
        options: const [
          AvatarFrameOption(id: ' ', label: 'a', color: Colors.blue),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => make(
        options: const [
          AvatarFrameOption(id: 'a', label: ' ', color: Colors.blue),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => make(
        options: const [
          AvatarFrameOption(id: 'a', label: 'a', color: Colors.blue),
          AvatarFrameOption(id: 'a', label: 'b', color: Colors.blue),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => make(
        options: const [
          AvatarFrameOption(
            id: 'a',
            label: 'a',
            color: Colors.blue,
            lockHint: ' ',
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect(() => make(selected: 'missing'), throwsArgumentError);
    expect(() => make(selected: 'gold'), throwsArgumentError); // locked
    expect(() => make(selected: null), returnsNormally);
    expect(() => make(height: 0), throwsArgumentError);
    expect(() => make(height: -10), throwsArgumentError);
    expect(() => make(height: double.infinity), throwsArgumentError);
  });

  testWidgets('empty state displays caller copy', (tester) async {
    await tester.pumpWidget(subject(options: const [], selectedId: null));
    expect(find.text('No frames available'), findsOneWidget);
    expect(find.byKey(const ValueKey('avatarFrameGrid')), findsNothing);
  });

  testWidgets('renders all options and indicates selected/locked marks', (
    tester,
  ) async {
    await tester.pumpWidget(subject(selectedId: 'classic'));
    expect(find.text('Classic Cyan'), findsOneWidget);
    expect(find.text('Neon Purple'), findsOneWidget);
    expect(find.text('Golden Legend'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('avatarFrameSelectedMark')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('avatarFrameLockMark')), findsNWidgets(2));
  });

  testWidgets('tapping unlocked unselected routes to onSelect', (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(
      subject(selectedId: 'classic', onSelect: selected.add),
    );
    await tester.tap(find.byKey(const ValueKey('avatarFrameOption_neon')));
    expect(selected, ['neon']);
  });

  testWidgets('tapping already selected does not route to onSelect', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      subject(selectedId: 'classic', onSelect: selected.add),
    );
    await tester.tap(find.byKey(const ValueKey('avatarFrameOption_classic')));
    expect(selected, isEmpty);
  });

  testWidgets('tapping locked calls onLockedTap and never onSelect', (
    tester,
  ) async {
    final selected = <String>[];
    final locked = <String>[];
    await tester.pumpWidget(
      subject(
        selectedId: 'classic',
        onSelect: selected.add,
        onLockedTap: locked.add,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('avatarFrameOption_gold')));
    expect(selected, isEmpty);
    expect(locked, ['gold']);
  });

  testWidgets('locked without onLockedTap is inert', (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(
      subject(selectedId: 'classic', onSelect: selected.add, onLockedTap: null),
    );
    await tester.tap(find.byKey(const ValueKey('avatarFrameOption_gold')));
    expect(selected, isEmpty);
  });

  testWidgets('target size is at least 48dp on both dimensions', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    final size = tester.getSize(
      find.byKey(const ValueKey('avatarFrameOption_classic')),
    );
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('100 options build lazily in a grid', (tester) async {
    final many = [
      for (var i = 0; i < 100; i++)
        AvatarFrameOption(
          id: 'frame_$i',
          label: 'Frame $i',
          color: Colors.blue,
        ),
    ];
    await tester.pumpWidget(subject(options: many, selectedId: 'frame_0'));
    expect(
      find.byKey(const ValueKey('avatarFrameOption_frame_0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('avatarFrameOption_frame_99')),
      findsNothing,
    );
    await tester.drag(
      find.byKey(const ValueKey('avatarFrameGrid')),
      const Offset(0, -5000),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('avatarFrameOption_frame_0')),
      findsNothing,
    );
  });

  testWidgets('semantics announce name, in-use, and locked hint', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        subject(selectedId: 'classic', onLockedTap: (_) {}),
      );
      String labelOf(String id) => tester
          .getSemantics(find.byKey(ValueKey('avatarFrameOption_$id')))
          .label;
      expect(labelOf('classic'), 'Classic Cyan, In use');
      expect(labelOf('neon'), 'Neon Purple');
      expect(labelOf('gold'), 'Golden Legend, Locked, Reach level 50');
      expect(labelOf('fire'), 'Fire Streak, Locked');
    } finally {
      handle.dispose();
    }
  });

  testWidgets('320dp, 2x text and RTL do not overflow or clip labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(subject(scale: 2, direction: TextDirection.rtl));
    expect(
      Directionality.of(tester.element(find.byType(AvatarFrameSelector))),
      TextDirection.rtl,
    );
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.maxLines, 2);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selected change mid-scroll preserves position and fires no callback',
    (tester) async {
      final many = [
        for (var i = 0; i < 60; i++)
          AvatarFrameOption(
            id: 'frame_$i',
            label: 'Frame $i',
            color: Colors.blue,
          ),
      ];
      final selected = <String>[];
      await tester.pumpWidget(
        subject(options: many, selectedId: 'frame_0', onSelect: selected.add),
      );
      final grid = find.byKey(const ValueKey('avatarFrameGrid'));
      await tester.drag(grid, const Offset(0, -600));
      await tester.pump();
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: grid, matching: find.byType(Scrollable)),
      );
      final before = scrollable.position.pixels;
      await tester.pumpWidget(
        subject(options: many, selectedId: 'frame_50', onSelect: selected.add),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(scrollable.position.pixels, before);
      expect(selected, isEmpty);
    },
  );

  testWidgets('selected (bold) two-line labels never overflow their cell', (
    tester,
  ) async {
    const long = [
      AvatarFrameOption(
        id: 'a',
        label: 'Golden Legend Edition Extra Long Name',
        color: Colors.amber,
      ),
      AvatarFrameOption(
        id: 'b',
        label: 'Neon Purple Deluxe Collector Frame',
        color: Colors.purple,
      ),
    ];
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final selected in ['a', 'b']) {
        await tester.pumpWidget(
          subject(options: long, selectedId: selected, scale: scale),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester.takeException(),
          isNull,
          reason: 'scale $scale selected $selected',
        );
      }
    }
  });

  testWidgets('selection pulses once; mount and reduced motion do not', (
    tester,
  ) async {
    await tester.pumpWidget(subject(selectedId: 'classic'));
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(subject(selectedId: 'neon'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(subject(selectedId: null, reducedMotion: true));
    await tester.pumpWidget(
      subject(selectedId: 'classic', reducedMotion: true),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('unmount mid-pulse disposes the controller cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(subject(selectedId: 'classic'));
    await tester.pumpWidget(subject(selectedId: 'neon'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
