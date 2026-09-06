import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';

void main() {
  testWidgets('CommonButton bấm vào nút variant primary gọi onTap', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CommonButton(label: 'Play', onTap: () => tapped = true),
        ),
      ),
    );

    // Dùng byType thay vì find.text vì StrokeText vẽ 2 lớp Text chồng nhau
    // (stroke + fill) cho cùng 1 label -> find.text sẽ ambiguous.
    await tester.tap(find.byType(CommonButton));
    await tester.pump();

    expect(tapped, true);
  });

  for (final variant in CommonButtonVariant.values) {
    testWidgets('CommonButton render variant $variant không throw', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CommonButton(
              label: variant == CommonButtonVariant.icon ? null : 'Label',
              icon: variant == CommonButtonVariant.icon
                  ? Icons.settings
                  : null,
              variant: variant,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('CommonButton onTap == null thì bị disable, tap không throw', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(child: CommonButton(label: 'Disabled', onTap: null)),
      ),
    );

    final semantics = tester.getSemantics(find.byType(CommonButton));
    expect(semantics.flagsCollection.isEnabled, false);

    await tester.tap(find.byType(CommonButton));
    await tester.pump();
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('CommonButton semanticLabel tuỳ chỉnh được ưu tiên cao nhất', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    // Variant secondary vẽ label bằng 1 Text thường (không phải StrokeText 2
    // lớp) nên semantics label dễ assert hơn.
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CommonButton(
            label: 'Play',
            semanticLabel: 'Start the game',
            variant: CommonButtonVariant.secondary,
            onTap: () {},
          ),
        ),
      ),
    );

    final label = tester.getSemantics(find.byType(CommonButton)).label;
    // semanticLabel phải là dòng đầu (ưu tiên cao nhất trong fallback chain),
    // bất kể child Text('Play') có bị merge vào cùng node semantics hay không.
    expect(label.split('\n').first, 'Start the game');
    handle.dispose();
  });

  testWidgets(
    'CommonButton không có semanticLabel thì fallback dùng label',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CommonButton(
              label: 'Play',
              variant: CommonButtonVariant.secondary,
              onTap: () {},
            ),
          ),
        ),
      );

      final label = tester.getSemantics(find.byType(CommonButton)).label;
      expect(label.split('\n').first, 'Play');
      handle.dispose();
    },
  );

  testWidgets(
    'CommonButton icon variant, không label/semanticLabel thì fallback dùng icon.toString()',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CommonButton(
              icon: Icons.settings,
              variant: CommonButtonVariant.icon,
              onTap: () {},
            ),
          ),
        ),
      );

      final label = tester.getSemantics(find.byType(CommonButton)).label;
      expect(label, Icons.settings.toString());
      handle.dispose();
    },
  );
}
