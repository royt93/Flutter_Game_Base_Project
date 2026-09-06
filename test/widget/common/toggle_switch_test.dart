import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/toggle_switch.dart';

void main() {
  testWidgets('CandyToggleSwitch bấm vào thì gọi onChanged với giá trị đảo', (
    tester,
  ) async {
    bool? changedTo;

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CandyToggleSwitch(
            value: false,
            onChanged: (v) => changedTo = v,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CandyToggleSwitch));
    await tester.pump();

    expect(changedTo, true);
  });

  testWidgets(
    'CandyToggleSwitch value=true thì tap gọi onChanged với false',
    (tester) async {
      bool? changedTo;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CandyToggleSwitch(
              value: true,
              onChanged: (v) => changedTo = v,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CandyToggleSwitch));
      await tester.pump();

      expect(changedTo, false);
    },
  );

  testWidgets('CandyToggleSwitch phản ánh đúng state qua Semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CandyToggleSwitch(value: true, onChanged: (_) {}),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(CandyToggleSwitch));
    expect(semantics.flagsCollection.isToggled, true);
    expect(semantics.flagsCollection.isEnabled, true);
  });

  testWidgets('CandyToggleSwitch onChanged == null thì bị disable, tap không throw', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: CandyToggleSwitch(value: false, onChanged: null),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(CandyToggleSwitch));
    expect(semantics.flagsCollection.isEnabled, false);

    await tester.tap(find.byType(CandyToggleSwitch));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
