import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/candy_text_field.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Material(child: Padding(padding: const EdgeInsets.all(16), child: child)),
);

BoxDecoration _boxDecorationOf(WidgetTester tester) =>
    tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration
        as BoxDecoration;

void main() {
  testWidgets('nhập text cập nhật đúng controller', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_wrap(CandyTextField(controller: controller)));

    await tester.enterText(find.byType(TextFormField), 'Roy');
    expect(controller.text, 'Roy');
  });

  testWidgets('hintText hiển thị đúng khi controller rỗng', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      _wrap(CandyTextField(controller: controller, hintText: 'Player name')),
    );

    expect(find.text('Player name'), findsOneWidget);
  });

  testWidgets('prefixIcon hiển thị đúng khi truyền vào', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      _wrap(CandyTextField(controller: controller, prefixIcon: Icons.person)),
    );

    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('obscureText ẩn ký tự đúng (TextFormField.obscureText)', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      _wrap(CandyTextField(controller: controller, obscureText: true)),
    );

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.obscureText, isTrue);
  });

  testWidgets('keyboardType forward đúng xuống TextFormField', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      _wrap(
        CandyTextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
        ),
      ),
    );

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.keyboardType, TextInputType.emailAddress);
  });

  testWidgets('onChanged gọi đúng mỗi khi text đổi', (tester) async {
    final controller = TextEditingController();
    final values = <String>[];
    await tester.pumpWidget(
      _wrap(CandyTextField(controller: controller, onChanged: values.add)),
    );

    await tester.enterText(find.byType(TextFormField), 'hi');
    expect(values, ['hi']);
  });

  group('validator', () {
    testWidgets('validator hiện đúng lỗi khi input không hợp lệ', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrap(
          CandyTextField(
            controller: controller,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Không được để trống' : null,
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'a');
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();

      expect(find.text('Không được để trống'), findsOneWidget);
    });

    testWidgets('không có validator → không tự động validate, không lỗi', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_wrap(CandyTextField(controller: controller)));

      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('focus/blur đổi border + glow', () {
    testWidgets('focus → border đổi màu color, có glow shadow', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              CandyTextField(controller: controller, color: NeonTheme.red),
              // Widget thứ 2 để có thể unfocus field đầu tiên sau này.
              const TextField(),
            ],
          ),
        ),
      );

      final beforeDecoration = _boxDecorationOf(tester);
      expect((beforeDecoration.border as Border).top.color, NeonTheme.muted);

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();

      final focusedDecoration = _boxDecorationOf(tester);
      expect((focusedDecoration.border as Border).top.color, NeonTheme.red);
      expect(focusedDecoration.boxShadow, isNotNull);
      expect(focusedDecoration.boxShadow!.length, 3); // NeonTheme.glow's 3 layers
    });

    testWidgets('blur (mất focus) → border/glow trở lại trạng thái mặc định', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              CandyTextField(controller: controller),
              const TextField(key: Key('other')),
            ],
          ),
        ),
      );

      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      expect(
        (_boxDecorationOf(tester).border as Border).top.color,
        NeonTheme.cyan,
      );

      await tester.tap(find.byKey(const Key('other')));
      await tester.pumpAndSettle();

      final blurredDecoration = _boxDecorationOf(tester);
      expect((blurredDecoration.border as Border).top.color, NeonTheme.muted);
      expect(blurredDecoration.boxShadow!.length, 1); // NeonTheme.drop's 1 layer
    });
  });

  testWidgets('Reduce Motion bật → AnimatedContainer duration = 0', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _wrap(CandyTextField(controller: controller)),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(container.duration, Duration.zero);
  });

  testWidgets('dispose sạch, không leak FocusNode khi unmount', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_wrap(CandyTextField(controller: controller)));

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
