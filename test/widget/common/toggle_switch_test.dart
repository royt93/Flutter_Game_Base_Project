// `SemanticsData.hasFlag`/`SemanticsFlag` are deprecated in favor of
// `flagsCollection` — but `flagsCollection.isEnabled`'s return type changed
// (bool → Tristate) between CI's pinned Flutter (3.35.1) and newer SDKs, so
// `hasFlag` is the one API that actually compiles identically on both.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

  testWidgets('CandyToggleSwitch value=true thì tap gọi onChanged với false', (
    tester,
  ) async {
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
  });

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
    expect(semantics.getSemanticsData().hasFlag(SemanticsFlag.isToggled), isTrue);
    expect(semantics.getSemanticsData().hasFlag(SemanticsFlag.isEnabled), isTrue);
  });

  testWidgets(
    'CandyToggleSwitch onChanged == null thì bị disable, tap không throw',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: CandyToggleSwitch(value: false, onChanged: null),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(CandyToggleSwitch));
      expect(semantics.getSemanticsData().hasFlag(SemanticsFlag.isEnabled), isFalse);

      await tester.tap(find.byType(CandyToggleSwitch));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ENH-23: thumb (AnimatedAlign) dùng easeOutBack (nảy), track (AnimatedContainer) vẫn easeOut',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CandyToggleSwitch(value: false, onChanged: (_) {}),
          ),
        ),
      );

      expect(
        tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).curve,
        Curves.easeOutBack,
      );
      expect(
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).curve,
        Curves.easeOut,
      );
    },
  );

  testWidgets(
    'ENH-17: Reduce Motion bật → AnimatedContainer/AnimatedAlign duration = 0',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Material(
              child: CandyToggleSwitch(value: true, onChanged: (_) {}),
            ),
          ),
        ),
      );

      expect(
        tester
            .widget<AnimatedContainer>(find.byType(AnimatedContainer))
            .duration,
        Duration.zero,
      );
      expect(
        tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).duration,
        Duration.zero,
      );
      expect(tester.takeException(), isNull);
    },
  );

  group('ENH-37: Semantics', () {
    testWidgets(
      'semanticLabel truyền vào → label khớp, toggled đúng theo value',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: CandyToggleSwitch(
                value: true,
                onChanged: (_) {},
                semanticLabel: 'Haptics',
              ),
            ),
          ),
        );

        final data = tester.getSemantics(find.byType(CandyToggleSwitch));
        expect(data.label, 'Haptics');
        expect(
          data.getSemanticsData().hasFlag(SemanticsFlag.isToggled),
          isTrue,
        );
        handle.dispose();
      },
    );

    testWidgets('value false → toggled: false', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CandyToggleSwitch(
              value: false,
              onChanged: (_) {},
              semanticLabel: 'Dark mode',
            ),
          ),
        ),
      );

      final data = tester.getSemantics(find.byType(CandyToggleSwitch));
      expect(data.label, 'Dark mode');
      expect(
        data.getSemanticsData().hasFlag(SemanticsFlag.isToggled),
        isFalse,
      );
      handle.dispose();
    });
  });
}
