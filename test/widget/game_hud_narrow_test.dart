import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/locale_service.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// HUD lúc chơi trên máy hẹp.
///
/// Bug đã bắt được TRÊN MÁY THẬT (Galaxy S24 Ultra, 1080x2340 @ density 480 →
/// **360dp ngang**): dải sọc vàng-đen "OVERFLOWED BY 21 PIXELS" nằm ngay giữa
/// HUD. `long_locale_overflow_test` không thấy vì nó cố ý bỏ `GameScreen`.
///
/// Nguyên nhân: hàng HUD xếp 5 thứ cạnh nhau — nút thoát, cột điểm
/// (`Expanded`), chip xu, chip năng lượng, linh vật. Ở 360dp cột giữa chỉ còn
/// khoảng 86dp, trong khi badge màu may mắn là `Row(mainAxisSize.min)` nên bề
/// ngang cố định ~105dp. Điểm số cỡ 30 với 5 chữ số cũng vượt.
///
/// Cả hai giờ bọc `FittedBox(scaleDown)`.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  /// 360x780dp — đúng khung S24 Ultra ở mức phóng to người dùng đang đặt.
  const narrow = Size(1080, 2340);
  const pixelRatio = 3.0;

  Future<List<String>> renderHud(
    WidgetTester tester, {
    required Locale locale,
    required int score,
  }) async {
    tester.view.physicalSize = narrow;
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(Get.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = Get.put(StorageService(prefs), permanent: true);
    Get.put(LocaleService(store), permanent: true);
    final ctrl = Get.put(GameController(), permanent: true);
    ctrl.startLevel(1);

    final errors = <String>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exception.toString());

    await tester.pumpWidget(
      GetMaterialApp(
        locale: locale,
        fallbackLocale: const Locale('en', 'US'),
        translations: AppTranslations(),
        home: const GameScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    ctrl.score.value = score;
    await _pumpFrames(tester);
    // Trả handler NGAY, không qua `addTearDown`: nếu để tới lúc teardown thì
    // lỗi phát sinh trong quá trình dispose rơi vào handler của test và
    // framework báo "overrode FlutterError.onError but ... unexpected
    // additional errors" thay vì báo đúng lỗi tràn.
    FlutterError.onError = previousOnError;
    return errors;
  }

  for (final locale in const [
    Locale('en', 'US'),
    Locale('vi', 'VN'), // "Màu may mắn!" — chuỗi đã tràn trên máy
    Locale('de', 'DE'), // "Glücksfarbe!" + từ ghép dài
  ]) {
    testWidgets('HUD @360dp không tràn — ${locale.languageCode}', (
      tester,
    ) async {
      final errors = await renderHud(tester, locale: locale, score: 0);
      expect(errors, isEmpty, reason: errors.join('\n'));
    });
  }

  testWidgets('HUD @360dp không tràn với điểm 5 chữ số', (tester) async {
    // `fmtNum` chèn dấu phân cách nên "10.000" dài hơn 5 ký tự thường; ở cỡ
    // chữ 30 nó rộng hơn cột giữa.
    final errors = await renderHud(
      tester,
      locale: const Locale('vi', 'VN'),
      score: 99999,
    );
    expect(errors, isEmpty, reason: errors.join('\n'));
  });
}
