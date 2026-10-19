import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/haptic_choreographer.dart';
import 'package:roy_casual_kit/core/haptics.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';

final _options = [
  HapticPatternOption(
    id: 'soft',
    label: 'Soft',
    pattern: HapticPattern([const HapticPulse(level: HapticLevel.light)]),
  ),
  HapticPatternOption(
    id: 'reward',
    label: 'Reward',
    pattern: HapticPattern.reward,
  ),
  HapticPatternOption(
    id: 'error',
    label: 'Error',
    pattern: HapticPattern.error,
  ),
];

Widget subject({
  List<HapticPatternOption>? options,
  String? selected = 'soft',
  ValueChanged<String?>? onSelect,
  ValueChanged<HapticPattern>? onPreview,
  bool enabled = true,
  bool busy = false,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  builder: (_, child) =>
      Directionality(textDirection: direction, child: child!),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: HapticPatternPicker(
            options: options ?? _options,
            selectedId: selected,
            onSelect: onSelect ?? (_) {},
            onPreview: onPreview ?? (_) {},
            hapticsEnabled: enabled,
            busy: busy,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  test('validates option count, ids, labels, selection and copy', () {
    HapticPatternOption option(String id, String label) =>
        HapticPatternOption(id: id, label: label, pattern: HapticPattern.combo);
    HapticPatternPicker make({
      List<HapticPatternOption>? options,
      String? selected = 'a',
      String preview = 'Preview',
    }) => HapticPatternPicker(
      options: options ?? [option('a', 'A')],
      selectedId: selected,
      onSelect: (_) {},
      onPreview: (_) {},
      previewLabel: preview,
    );
    expect(() => make(options: []), throwsArgumentError);
    expect(
      () => make(
        options: [
          option('1', '1'),
          option('2', '2'),
          option('3', '3'),
          option('4', '4'),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => make(options: [option(' ', 'A')], selected: null),
      throwsArgumentError,
    );
    expect(() => make(options: [option('a', ' ')]), throwsArgumentError);
    expect(
      () => make(options: [option('a', 'A'), option('a', 'B')]),
      throwsArgumentError,
    );
    expect(() => make(selected: 'missing'), throwsArgumentError);
    expect(() => make(preview: ' '), throwsArgumentError);
    expect(() => make(selected: null), returnsNormally);
  });

  testWidgets('selects an option and previews its exact pattern once', (
    tester,
  ) async {
    final selected = <String?>[];
    final previews = <HapticPattern>[];
    await tester.pumpWidget(
      subject(onSelect: selected.add, onPreview: previews.add),
    );
    await tester.tap(find.byKey(const ValueKey('hapticOption_reward')));
    await tester.tap(find.byKey(const ValueKey('hapticPreview_reward')));
    expect(selected, ['reward']);
    expect(previews, [HapticPattern.reward]);
    expect(previews.single, same(_options[1].pattern));
  });

  testWidgets('off option selects null but never previews', (tester) async {
    final selected = <String?>[];
    final previews = <HapticPattern>[];
    await tester.pumpWidget(
      subject(onSelect: selected.add, onPreview: previews.add),
    );
    await tester.tap(find.byKey(const ValueKey('hapticOption_off')));
    await tester.tap(find.byKey(const ValueKey('hapticPreview_off')));
    expect(selected, [null]);
    expect(previews, isEmpty);
  });

  testWidgets(
    'disabled preference and busy state block preview and selection',
    (tester) async {
      final selected = <String?>[];
      final previews = <HapticPattern>[];
      await tester.pumpWidget(
        subject(
          enabled: false,
          onSelect: selected.add,
          onPreview: previews.add,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('hapticPreview_soft')));
      expect(previews, isEmpty);
      expect(find.text('Haptics off'), findsWidgets);

      await tester.pumpWidget(
        subject(busy: true, onSelect: selected.add, onPreview: previews.add),
      );
      await tester.tap(find.byKey(const ValueKey('hapticOption_reward')));
      await tester.tap(find.byKey(const ValueKey('hapticPreview_reward')));
      expect(selected, isEmpty);
      expect(previews, isEmpty);
      expect(find.text('Playing'), findsWidgets);
    },
  );

  testWidgets('each pattern has 48dp selection and preview targets', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    for (final key in ['hapticOption_soft', 'hapticPreview_soft']) {
      final size = tester.getSize(find.byKey(ValueKey(key)));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('semantics expose selected, disabled and preview actions', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(subject(selected: 'soft'));
      final selected = tester.getSemantics(
        find.byKey(const ValueKey('hapticOption_soft')),
      );
      expect(selected.label, 'Soft, selected');
      expect(
        selected.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      final preview = tester.getSemantics(
        find.byKey(const ValueKey('hapticPreview_soft')),
      );
      expect(preview.label, 'Haptic pattern Soft, Preview');
      expect(preview.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      await tester.pumpWidget(subject(enabled: false));
      final disabled = tester.getSemantics(
        find.byKey(const ValueKey('hapticPreview_soft')),
      );
      expect(disabled.label, 'Haptic pattern Soft, Haptics off');
      expect(
        disabled.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('320dp, 2x text and RTL wrap controls without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(subject(scale: 2, direction: TextDirection.rtl));
    expect(
      Directionality.of(tester.element(find.byType(HapticPatternPicker))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('HapticChoreographer obeys disabled and soft-mode settings', (
    tester,
  ) async {
    final storage = Get.put(StorageService(null));
    final calls = <HapticLevel>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          final type = call.arguments as String;
          calls.add(switch (type) {
            'HapticFeedbackType.lightImpact' => HapticLevel.light,
            'HapticFeedbackType.mediumImpact' => HapticLevel.medium,
            _ => HapticLevel.heavy,
          });
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      Get.reset();
    });

    await storage.setBool(StorageKeys.hapticsEnabled, false);
    final disabled = HapticChoreographer();
    disabled.play(HapticPattern([const HapticPulse(level: HapticLevel.heavy)]));
    disabled.cancel();
    expect(calls, isEmpty);

    await storage.setBool(StorageKeys.hapticsEnabled, true);
    await storage.setBool(StorageKeys.hapticSoftMode, true);
    final soft = HapticChoreographer();
    soft.play(HapticPattern([const HapticPulse(level: HapticLevel.heavy)]));
    soft.cancel();
    expect(calls, [HapticLevel.medium]);
  });
}
