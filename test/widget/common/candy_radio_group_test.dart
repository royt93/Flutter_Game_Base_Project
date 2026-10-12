import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/candy_radio_group.dart';

// ignore_for_file: deprecated_member_use

void main() {
  test('radio group rejects empty and duplicate options', () {
    expect(
      () => CandyRadioGroup<String>(
        options: const [],
        value: null,
        onChanged: (_) {},
      ),
      throwsArgumentError,
    );
    expect(
      () => CandyRadioGroup<String>(
        options: const [
          CandyRadioOption(value: 'same', label: 'One'),
          CandyRadioOption(value: 'same', label: 'Two'),
        ],
        value: 'same',
        onChanged: (_) {},
      ),
      throwsArgumentError,
    );
  });

  testWidgets(
    'radio selection emits tapped value and exposes selected semantics',
    (tester) async {
      String? selected = 'low';
      late StateSetter update;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MaterialApp(
              home: Scaffold(
                body: CandyRadioGroup<String>(
                  value: selected,
                  options: const [
                    CandyRadioOption(value: 'low', label: 'Low'),
                    CandyRadioOption(value: 'high', label: 'High'),
                  ],
                  onChanged: (value) => setState(() => selected = value),
                ),
              ),
            );
          },
        ),
      );

      final high = find.bySemanticsLabel('High');
      await tester.tap(find.text('High'));
      await tester.pump();
      expect(selected, 'high');
      expect(
        tester
            .getSemantics(high)
            .getSemanticsData()
            .hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      update(() => selected = 'low');
      await tester.pump();
      semantics.dispose();
    },
  );

  testWidgets('checkbox toggles boolean and exposes checked semantics', (
    tester,
  ) async {
    var value = false;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          home: Scaffold(
            body: CandyCheckboxTile(
              label: 'Hints',
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );
    final hints = find.bySemanticsLabel('Hints');
    expect(
      tester
          .getSemantics(hints)
          .getSemanticsData()
          .hasFlag(SemanticsFlag.hasCheckedState),
      isTrue,
    );
    expect(
      tester
          .getSemantics(hints)
          .getSemanticsData()
          .hasFlag(SemanticsFlag.isChecked),
      isFalse,
    );
    await tester.tap(hints);
    await tester.pump();
    expect(value, isTrue);
    expect(
      tester
          .getSemantics(hints)
          .getSemanticsData()
          .hasFlag(SemanticsFlag.isChecked),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Reduced Motion collapses selection animation duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: CandyCheckboxTile(
              label: 'Hints',
              value: true,
              onChanged: null,
            ),
          ),
        ),
      ),
    );
    final selected = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(selected.duration, Duration.zero);
    expect(tester.takeException(), isNull);
  });
}
