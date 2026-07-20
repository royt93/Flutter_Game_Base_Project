import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/burst_styles.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/widgets/burst_style_picker_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget home) => GetMaterialApp(
  translations: AppTranslations(),
  locale: const Locale('en', 'US'),
  home: home,
);

// I52 Pop Burst Style Picker: dialog hiện đủ 4 style, style chưa mở khoá mờ
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
            onPressed: () => showBurstStylePickerDialog(context, ctrl),
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
    ctrl.totalGemsPopped.value = 0;
    await openDialog(tester);

    for (final style in kBurstStyles) {
      expect(find.text(style.nameKey.tr), findsOneWidget);
    }
    // 3 style khoá (confetti/ripple/starburst) hiện đúng ngưỡng của chúng.
    for (final style in kBurstStyles.where(
      (s) => s.kind != BurstStyleKind.spark,
    )) {
      expect(find.text('${style.unlockThreshold}'), findsOneWidget);
    }
  });

  testWidgets('tap style đã mở khoá → set active + đóng dialog', (
    tester,
  ) async {
    ctrl.totalGemsPopped.value = 2000; // đủ mở spark/confetti/ripple
    await openDialog(tester);

    final ripple = kBurstStyles.firstWhere(
      (s) => s.kind == BurstStyleKind.ripple,
    );
    await tester.tap(find.text(ripple.nameKey.tr));
    await tester.pumpAndSettle();

    expect(ctrl.activeBurstStyleKind.value, BurstStyleKind.ripple);
    expect(find.text(ripple.nameKey.tr), findsNothing); // dialog đã đóng
  });

  testWidgets('tap style chưa mở khoá → không đổi active, dialog vẫn mở', (
    tester,
  ) async {
    ctrl.totalGemsPopped.value = 0;
    await openDialog(tester);

    final starburst = kBurstStyles.firstWhere(
      (s) => s.kind == BurstStyleKind.starburst,
    );
    await tester.tap(find.text(starburst.nameKey.tr));
    await tester.pumpAndSettle();

    expect(ctrl.activeBurstStyleKind.value, BurstStyleKind.spark);
    expect(find.text(starburst.nameKey.tr), findsOneWidget); // vẫn mở
  });
}
