import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/candy_slider.dart';

Widget host(
  Widget child, {
  bool reduced = false,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Center(child: SizedBox(width: 300, child: child)),
      ),
    ),
  ),
);

void main() {
  tearDown(Get.reset);

  test('constructor rejects invalid public configuration in release too', () {
    for (final value in [double.nan, double.infinity, -0.1, 1.1]) {
      expect(
        () => CandySlider(value: value, onChanged: null),
        throwsArgumentError,
      );
    }
    for (final min in [double.nan, double.infinity, 1.0, 2.0]) {
      expect(
        () => CandySlider(value: 0.5, min: min, onChanged: null),
        throwsArgumentError,
      );
    }
    for (final max in [double.nan, double.infinity, 0.0, -1.0]) {
      expect(
        () => CandySlider(value: 0, max: max, onChanged: null),
        throwsArgumentError,
      );
    }
    for (final size in [double.nan, double.infinity, 0.0, -1.0]) {
      expect(
        () => CandySlider(value: 0, trackHeight: size, onChanged: null),
        throwsArgumentError,
      );
      expect(
        () => CandySlider(value: 0, thumbRadius: size, onChanged: null),
        throwsArgumentError,
      );
    }
    for (final divisions in [0, -1]) {
      expect(
        () => CandySlider(value: 0, divisions: divisions, onChanged: null),
        throwsArgumentError,
      );
    }
  });

  testWidgets('tap emits one start and one end with the updated value', (
    tester,
  ) async {
    var value = 0.0;
    final starts = <double>[];
    final ends = <double>[];
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => CandySlider(
            value: value,
            onChanged: (next) => setState(() => value = next),
            onChangeStart: starts.add,
            onChangeEnd: ends.add,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Slider));
    await tester.pump();
    expect(value, closeTo(0.5, 0.05));
    expect(starts, hasLength(1));
    expect(ends, [value]);
  });

  testWidgets('native drag clamps and end callback uses last emitted value', (
    tester,
  ) async {
    var value = 0.0;
    final ends = <double>[];
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => CandySlider(
            value: value,
            max: 100,
            onChanged: (next) => setState(() => value = next),
            onChangeEnd: ends.add,
          ),
        ),
      ),
    );
    await tester.drag(find.byType(Slider), const Offset(250, 0));
    await tester.pump();
    expect(value, 100);
    expect(ends, [100]);
  });

  testWidgets(
    'divisions snap to step values and disabled native slider has no callbacks',
    (tester) async {
      var value = 0.0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => CandySlider(
              value: value,
              max: 10,
              divisions: 2,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(Slider));
      await tester.pump();
      expect(value, 5);
      await tester.pumpWidget(host(CandySlider(value: 0.5, onChanged: null)));
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      await tester.drag(find.byType(Slider), const Offset(50, 0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'RTL tap at right edge selects minimum, left edge selects maximum',
    (tester) async {
      var value = 0.5;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => CandySlider(
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
          direction: TextDirection.rtl,
        ),
      );
      final rect = tester.getRect(find.byType(Slider));
      await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
      await tester.pump();
      expect(value, 0);
      await tester.tapAt(Offset(rect.left + 1, rect.center.dy));
      await tester.pump();
      expect(value, 1);
    },
  );

  testWidgets(
    'native semantics supplies exact values and increase/decrease actions',
    (tester) async {
      final handle = tester.ensureSemantics();
      var value = 5.0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => CandySlider(
              value: value,
              max: 10,
              divisions: 10,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(Slider));
      expect(node.value, '5.0');
      tester
          .renderObject<RenderBox>(find.byType(Slider))
          .owner!
          .semanticsOwner!
          .performAction(node.id, SemanticsAction.increase);
      await tester.pump();
      expect(value, 6);
      tester
          .renderObject<RenderBox>(find.byType(Slider))
          .owner!
          .semanticsOwner!
          .performAction(node.id, SemanticsAction.decrease);
      await tester.pump();
      expect(value, 5);
      handle.dispose();
    },
  );

  testWidgets('keyboard adjustment uses native focus handling', (tester) async {
    var value = 0.5;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => CandySlider(
            value: value,
            divisions: 10,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(value, closeTo(0.6, 0.001));
  });

  testWidgets(
    'haptics only emit at divisions or endpoints and respect disabled preference',
    (tester) async {
      final storage = StorageService(null);
      Get.put(storage);
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(host(CandySlider(value: 0.5, onChanged: (_) {})));
      final continuous = tester.widget<Slider>(find.byType(Slider));
      continuous.onChanged!(0.6);
      expect(calls, isEmpty);
      continuous.onChanged!(1);
      expect(calls, ['HapticFeedbackType.lightImpact']);
      continuous.onChanged!(1);
      expect(calls, hasLength(1));
      await storage.setBool(StorageKeys.hapticsEnabled, false);
      await tester.pumpWidget(
        host(CandySlider(value: 0.5, divisions: 10, onChanged: (_) {})),
      );
      tester.widget<Slider>(find.byType(Slider)).onChanged!(0.7);
      expect(calls, hasLength(1));
    },
  );

  for (final reduced in [false, true]) {
    testWidgets(
      'thumb uses activation animation; reduced motion=$reduced disables scale',
      (tester) async {
        await tester.pumpWidget(
          host(CandySlider(value: 0.5, onChanged: (_) {}), reduced: reduced),
        );
        final shape = tester
            .widget<SliderTheme>(find.byType(SliderTheme).first)
            .data
            .thumbShape!;
        final box = tester.renderObject<RenderBox>(find.byType(Slider));
        final scale = reduced ? 1.0 : 1.15;
        expect(
          (Canvas canvas) => shape.paint(
            TestRecordingPaintingContext(canvas),
            Offset.zero,
            activationAnimation: const AlwaysStoppedAnimation(1),
            enableAnimation: const AlwaysStoppedAnimation(1),
            isDiscrete: false,
            labelPainter: TextPainter(),
            parentBox: box,
            sliderTheme: SliderThemeData(
              thumbColor: Colors.white,
              disabledThumbColor: NeonTheme.cardAlt,
            ),
            textDirection: TextDirection.ltr,
            value: 0.5,
            textScaleFactor: 1,
            sizeWithOverflow: const Size(300, 100),
          ),
          paints
            ..circle(radius: 14 * scale + 2)
            ..circle(radius: 14 * scale)
            ..circle(radius: 14 * 0.75 * scale),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
