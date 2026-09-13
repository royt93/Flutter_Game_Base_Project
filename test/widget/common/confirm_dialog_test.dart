import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/presentation/widgets/common/confirm_dialog.dart';

void main() {
  tearDown(() => Get.reset());

  testWidgets(
    'showConfirmDialog complete future (false) khi route bị pop bằng back thay vì bấm nút',
    (tester) async {
      bool? result;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return ElevatedButton(
                onPressed: () async {
                  result = await showConfirmDialog(context, title: 'Xoá?');
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Xoá?'), findsOneWidget);

      // Giả lập back button/gesture: pop route trực tiếp qua Navigator,
      // KHÔNG đi qua onTap của action nào (mô phỏng đúng hành vi hardware
      // back trên Android).
      Navigator.of(capturedContext, rootNavigator: true).pop();
      await tester.pumpAndSettle();

      expect(result, false);
    },
  );

  testWidgets('showConfirmDialog trả về true khi bấm nút confirm', (
    tester,
  ) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await showConfirmDialog(
                  context,
                  title: 'Xoá?',
                  confirmLabel: 'Yes',
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    expect(result, true);
  });

  testWidgets('showConfirmDialog trả về false khi bấm nút cancel', (
    tester,
  ) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await showConfirmDialog(
                  context,
                  title: 'Xoá?',
                  cancelLabel: 'No',
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    expect(result, false);
  });

  group('ENH-39: default confirm/cancel label đi qua AppTranslations', () {
    Widget wrap(Widget child, Locale locale) => GetMaterialApp(
      translations: AppTranslations(),
      locale: locale,
      fallbackLocale: AppTranslations.fallback,
      home: child,
    );

    testWidgets("locale 'en' (mặc định) → nút hiện 'OK'/'Cancel'", (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showConfirmDialog(context, title: 'Delete?'),
              child: const Text('open'),
            ),
          ),
          const Locale('en'),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets(
      "locale 'vi' → không truyền confirmLabel/cancelLabel thì nút hiện đúng "
      "bản dịch ('Đồng ý'/'Huỷ'), không còn hardcode tiếng Anh",
      (tester) async {
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showConfirmDialog(context, title: 'Xoá?'),
                child: const Text('open'),
              ),
            ),
            const Locale('vi'),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('Đồng ý'), findsOneWidget);
        expect(find.text('Huỷ'), findsOneWidget);
        expect(find.text('OK'), findsNothing);
        expect(find.text('Cancel'), findsNothing);
      },
    );

    testWidgets(
      "locale 'vi' nhưng caller truyền confirmLabel/cancelLabel riêng → "
      "vẫn ưu tiên chuỗi caller truyền, không bị AppTranslations ghi đè",
      (tester) async {
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showConfirmDialog(
                  context,
                  title: 'Xoá?',
                  confirmLabel: 'Xác nhận',
                  cancelLabel: 'Bỏ qua',
                ),
                child: const Text('open'),
              ),
            ),
            const Locale('vi'),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('Xác nhận'), findsOneWidget);
        expect(find.text('Bỏ qua'), findsOneWidget);
        expect(find.text('Đồng ý'), findsNothing);
        expect(find.text('Huỷ'), findsNothing);
      },
    );
  });
}
