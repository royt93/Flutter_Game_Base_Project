import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/worlds.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/level_select_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// I81 — banner world hiện luật thời tiết.
///
/// Ca "không đè lên tên vùng" không phải phòng xa: **đã hỏng thật** ở lần build
/// đầu lên máy. Banner là `Stack` (để lớp hoạ tiết chạy nền sau chữ), nên thả
/// thêm một child vào đó là nó vẽ chồng ngay lên tên world — trên máy đọc ra
/// "World rCietrluss GTrove". Phải là `Column` riêng.
///
/// Screenshot không giữ lại được bất biến đó; so toạ độ thì có.
GameWorld get _ruledWorld =>
    kWorlds.firstWhere((w) => kWeatherRules[w.weather] != null);
GameWorld get _plainWorld =>
    kWorlds.firstWhere((w) => kWeatherRules[w.weather] == null);

Future<void> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
  Get.put(GameController(), permanent: true);

  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: const LevelSelectScreen(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 150));
}

Finder _ruleLine(GameWorld w) => find.byKey(Key('world_rule_${w.startId}'));

void main() {
  tearDown(Get.reset);

  testWidgets('world có luật: hiện dòng luật đã dịch', (tester) async {
    await _pump(tester);
    final w = _ruledWorld;
    final rule = kWeatherRules[w.weather]!;

    await tester.scrollUntilVisible(_ruleLine(w), 300);
    await tester.pump(const Duration(milliseconds: 120));

    expect(_ruleLine(w), findsOneWidget);
    // Nhiều world dùng CHUNG một luật (hai world đều là `spark`), nên tìm text
    // trần sẽ ra nhiều kết quả — giới hạn trong đúng banner của world này.
    expect(
      find.descendant(
        of: _ruleLine(w),
        matching: find.text(
          'weather_rule_banner'.trParams({'rule': rule.descKey.tr}),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('world không có luật: KHÔNG dựng dòng nào', (tester) async {
    await _pump(tester);
    expect(_ruleLine(_plainWorld), findsNothing);
  });

  testWidgets('dòng luật nằm DƯỚI tên vùng, không đè lên', (tester) async {
    await _pump(tester);
    final w = _ruledWorld;

    await tester.scrollUntilVisible(_ruleLine(w), 300);
    await tester.pump(const Duration(milliseconds: 120));

    final ruleRect = tester.getRect(_ruleLine(w));
    // `StrokeText` vẽ 2 lớp Text chồng nhau -> lấy lớp đầu, cùng vị trí.
    final nameRect = tester.getRect(find.text(w.nameKey.tr).first);

    expect(
      ruleRect.top,
      greaterThanOrEqualTo(nameRect.bottom),
      reason:
          'dòng luật chồng lên tên vùng — banner là Stack, phải bọc cả hai '
          'trong Column',
    );
    expect(ruleRect.overlaps(nameRect), isFalse);
  });

  testWidgets('dòng luật nằm gọn trong banner, không tràn ngang', (
    tester,
  ) async {
    await _pump(tester);
    final w = _ruledWorld;

    await tester.scrollUntilVisible(_ruleLine(w), 300);
    await tester.pump(const Duration(milliseconds: 120));

    final ruleRect = tester.getRect(_ruleLine(w));
    final screen = tester.getSize(find.byType(LevelSelectScreen));

    expect(ruleRect.left, greaterThanOrEqualTo(0));
    expect(ruleRect.right, lessThanOrEqualTo(screen.width));
    expect(tester.takeException(), isNull);
  });
}
