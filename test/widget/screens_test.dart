import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:neon_jewels/presentation/screens/home_screen.dart';
import 'package:neon_jewels/presentation/screens/level_select_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
  });
  tearDown(Get.reset);

  testWidgets('HomeScreen hiển thị tiêu đề & nút chơi', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('NEON'), findsOneWidget);
    expect(find.text('JEWELS'), findsOneWidget);
    expect(find.text('CHƠI NGAY'), findsOneWidget);
  });

  testWidgets('LevelSelectScreen render đủ tile level', (tester) async {
    Get.put(GameController());
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(const GetMaterialApp(home: LevelSelectScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('CHỌN MÀN'), findsOneWidget);
    // level 1 luôn mở khóa → có số '1'
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('LevelSelectScreen khóa level chưa unlock (hiện icon khóa)', (tester) async {
    Get.put(GameController());
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(const GetMaterialApp(home: LevelSelectScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    // mặc định chỉ mở khóa level 1 → level 2..5 bị khóa
    expect(find.byIcon(Icons.lock), findsWidgets);
  });
}
