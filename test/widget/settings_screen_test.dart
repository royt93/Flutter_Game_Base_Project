import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/locale_service.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// T1: `Get.updateLocale()` (dùng bởi `LocaleService.change()`) gọi
// `engine.performReassemble()` nội bộ — đã tái hiện thực tế bằng test riêng
// rằng lệnh này ném lỗi `schedulerPhase == idle` ngay ở `pump()` kế tiếp,
// dù gọi qua `tester.tap()` hay gọi thẳng `LocaleService.change()` không qua
// tap. Đây là giới hạn của `AutomatedTestWidgetsFlutterBinding`, không phải
// lỗi riêng của app. Nên test dựng `SettingsScreen` với `locale` cố định
// ngay từ `GetMaterialApp` (đúng cách `main.dart` gán `locale:
// widget.initialLocale` khi khởi động) thay vì đổi locale runtime giữa test.
Future<void> _pumpSettings(WidgetTester tester, Locale locale) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = Get.put(StorageService(prefs), permanent: true);
  Get.put(GameController(), permanent: true);
  Get.put(LocaleService(store), permanent: true);

  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: locale,
      home: const SettingsScreen(),
    ),
  );
  // NeonBg có AnimationController.repeat() vô hạn — pumpAndSettle sẽ treo.
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('en_US: hiển thị đúng bản dịch, không lộ raw key', (
    tester,
  ) async {
    await _pumpSettings(tester, const Locale('en', 'US'));

    expect(tester.takeException(), isNull);
    // Title đi qua NeonAppBar -> StrokeText, vẽ 2 lớp (stroke + fill).
    expect(find.text('Settings'), findsNWidgets(2));
    // AudioManager không đăng ký trong test này nên switch Sound không
    // render (guard `if (audio != null)` trong SettingsScreen) — chỉ assert
    // các text luôn render.
    expect(find.text('Colorblind mode'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget);
    // Nút reset nằm cuối ListView, ngoài viewport mặc định của test —
    // scroll tới trước khi assert (ListView chỉ build widget trong viewport).
    await tester.dragUntilVisible(
      find.text('Reset progress'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('Reset progress'), findsOneWidget);
    // Raw key không được lộ ra khi đã có bản dịch.
    expect(find.text('settings'), findsNothing);
    expect(find.text('reset_progress'), findsNothing);
    Get.reset();
  });

  testWidgets('ja_JP: hiển thị đúng bản dịch, không lộ raw key', (
    tester,
  ) async {
    await _pumpSettings(tester, const Locale('ja', 'JP'));

    expect(tester.takeException(), isNull);
    expect(find.text('設定'), findsNWidgets(2));
    expect(find.text('色覚異常モード'), findsOneWidget);
    expect(find.text('言語'), findsOneWidget);
    // Tên ngôn ngữ trên chip luôn hiển thị theo tên bản ngữ, không đổi theo locale.
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('進行状況をリセット'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('進行状況をリセット'), findsOneWidget);
    expect(find.text('settings'), findsNothing);
    expect(find.text('reset_progress'), findsNothing);
    Get.reset();
  });

  // I18: toggle "Colorblind mode" phải lật cờ trên GameController và lưu
  // xuống SharedPreferences qua StorageKeys.colorblindMode.
  testWidgets('toggle colorblind mode: lật cờ + lưu persist', (tester) async {
    await _pumpSettings(tester, const Locale('en', 'US'));

    final gameCtrl = Get.find<GameController>();
    expect(gameCtrl.colorblindMode.value, isFalse);
    expect(StorageService.to.getBool(StorageKeys.colorblindMode), isFalse);

    await tester.tap(find.text('Colorblind mode'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(gameCtrl.colorblindMode.value, isTrue);
    expect(StorageService.to.getBool(StorageKeys.colorblindMode), isTrue);
    expect(tester.takeException(), isNull);
    Get.reset();
  });

  // I28: toggle "Record Replay" phải lưu cờ recordReplay xuống
  // SharedPreferences (đọc lại bởi PopStarGame.recordingEnabled khi vào ván
  // mới — xem replay_recording_test.dart) để bật/tắt ghi lại tap.
  testWidgets(
    'toggle record replay: lưu persist qua StorageKeys.recordReplay',
    (tester) async {
      await _pumpSettings(tester, const Locale('en', 'US'));
      expect(StorageService.to.getBool(StorageKeys.recordReplay), isFalse);

      await tester.tap(find.text('Record Replay'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(StorageService.to.getBool(StorageKeys.recordReplay), isTrue);
      expect(tester.takeException(), isNull);

      // Tap lại phải tắt được (không phải write-only 1 chiều).
      await tester.tap(find.text('Record Replay'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(StorageService.to.getBool(StorageKeys.recordReplay), isFalse);

      Get.reset();
    },
  );
}
