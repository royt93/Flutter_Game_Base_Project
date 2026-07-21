import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/combo_text_styles.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/widgets/combo_text_style_picker_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget home) => GetMaterialApp(
  translations: AppTranslations(),
  locale: const Locale('en', 'US'),
  home: home,
);

// I54 Combo Text Style Picker: dialog hiện đủ 4 style, style chưa mở khoá mờ
// đi + hiện ngưỡng, tap style mở khoá thì đổi active + đóng dialog.
void main() {
  late GameController ctrl;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    ctrl = Get.put(GameController(), permanent: true);
  });

  tearDown(Get.reset);

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showComboTextStylePickerDialog(context, ctrl),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('hiện đủ 4 style, style chưa mở khoá hiện ngưỡng unlock', (
    tester,
  ) async {
    ctrl.maxComboEver.value = 0;
    await openDialog(tester);

    for (final style in kComboTextStyles) {
      expect(find.text(style.nameKey.tr), findsOneWidget);
    }
    // 3 style khoá (boldPop/retro/fire) hiện đúng ngưỡng của chúng.
    for (final style in kComboTextStyles.where(
      (s) => s.kind != ComboTextStyleKind.neon,
    )) {
      expect(find.text('${style.unlockThreshold}'), findsOneWidget);
    }
  });

  testWidgets('tap style đã mở khoá → set active + đóng dialog', (
    tester,
  ) async {
    ctrl.maxComboEver.value = 25; // đủ mở tất cả style
    await openDialog(tester);

    final retro = kComboTextStyles.firstWhere(
      (s) => s.kind == ComboTextStyleKind.retro,
    );
    await tester.tap(find.text(retro.nameKey.tr));
    await tester.pumpAndSettle();

    expect(ctrl.activeComboTextStyleKind.value, ComboTextStyleKind.retro);
    expect(find.text(retro.nameKey.tr), findsNothing); // dialog đã đóng
  });

  testWidgets('tap style chưa mở khoá → không đổi active, dialog vẫn mở', (
    tester,
  ) async {
    ctrl.maxComboEver.value = 0;
    await openDialog(tester);

    final fire = kComboTextStyles.firstWhere(
      (s) => s.kind == ComboTextStyleKind.fire,
    );
    await tester.tap(find.text(fire.nameKey.tr));
    await tester.pumpAndSettle();

    expect(ctrl.activeComboTextStyleKind.value, ComboTextStyleKind.neon);
    expect(find.text(fire.nameKey.tr), findsOneWidget); // vẫn mở
  });
}
