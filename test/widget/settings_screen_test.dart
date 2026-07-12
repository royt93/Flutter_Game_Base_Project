import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/locale_service.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('render đủ danh sách ngôn ngữ, không lỗi', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = Get.put(StorageService(prefs), permanent: true);
    Get.put(GameController(), permanent: true);
    Get.put(LocaleService(store), permanent: true);

    await tester.pumpWidget(GetMaterialApp(home: const SettingsScreen()));
    // NeonBg có AnimationController.repeat() vô hạn — pumpAndSettle sẽ treo.
    await tester.pump(const Duration(milliseconds: 100));

    // Không tap đổi ngôn ngữ ở đây: Get.updateLocale gọi
    // engine.performReassemble() nội bộ, không tương thích với
    // AutomatedTestWidgetsFlutterBinding (ném lỗi schedulerPhase == idle
    // ngay trong tap, không liên quan pump theo sau).
    expect(tester.takeException(), isNull);
    // Title đi qua NeonAppBar -> StrokeText, vẽ 2 lớp (stroke + fill).
    expect(find.text('Settings'), findsNWidgets(2));
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget);
    Get.reset();
  });
}
