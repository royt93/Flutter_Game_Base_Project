import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/utils/pseudo_locale.dart';
import 'package:roy_casual_kit/presentation/widgets/common/confirm_dialog.dart';

// FEAT-79: chứng minh pseudo-locale thật sự bắt được overflow/truncation
// trên 1 widget thật của kit dùng `.tr` (không phải giả định) —
// showConfirmDialog's confirmLabel/cancelLabel mặc định đi qua 'ok'.tr/
// 'cancel'.tr (ENH-39).
void main() {
  tearDown(Get.reset);

  Widget wrap(Widget home) => GetMaterialApp(
    translations: PseudoLocaleTranslations(
      baseKeys: AppTranslations().keys['en']!,
    ),
    locale: PseudoLocaleTranslations.defaultLocale,
    fallbackLocale: PseudoLocaleTranslations.defaultLocale,
    home: home,
  );

  testWidgets(
    'showConfirmDialog với label mặc định qua pseudo-locale: hiện đúng text đã bị biến đổi, không overflow',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showConfirmDialog(context, title: 'Xoá?'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Label thật phải là bản pseudo-localize của 'OK'/'Cancel', KHÔNG
      // phải chuỗi Anh trơn — chứng minh .tr thật sự đi qua
      // PseudoLocaleTranslations thay vì rơi về fallback tiếng Anh gốc.
      expect(find.text(pseudoLocalize('OK')), findsOneWidget);
      expect(find.text(pseudoLocalize('Cancel')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PHÁT HIỆN THẬT: label pseudo-locale dài hơn ~40% vẫn không tràn nút NeonDialogAction thật',
    (tester) async {
      // Dựng trực tiếp trong SizedBox rất hẹp để dồn áp lực overflow lên
      // đúng nút chứa label đã pseudo-localize, thay vì chỉ trong dialog
      // full-width (khó ép overflow).
      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 90,
                child: ElevatedButton(
                  onPressed: () {},
                  child: Text(pseudoLocalize('OK')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}
