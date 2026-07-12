import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:pop_star_blast/presentation/screens/level_select_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    Get.put(GameController(), permanent: true);
  });

  tearDown(Get.reset);

  // pump cố định thay vì pumpAndSettle: node hiện tại (unlocked) có pulse
  // animation lặp vô hạn, pumpAndSettle không bao giờ thấy "đứng yên". Sau
  // tap cần 2 pump: 1 build route mới, 1 chạy hết animation chuyển màn.
  testWidgets('tap node mở khoá vào GameScreen', (tester) async {
    await tester.pumpWidget(GetMaterialApp(home: const LevelSelectScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('level_tile_1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GameScreen), findsOneWidget);
  });

  testWidgets('tap node khoá không vào game', (tester) async {
    await tester.pumpWidget(GetMaterialApp(home: const LevelSelectScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('level_tile_5')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GameScreen), findsNothing);
    expect(find.byType(LevelSelectScreen), findsOneWidget);
  });
}
