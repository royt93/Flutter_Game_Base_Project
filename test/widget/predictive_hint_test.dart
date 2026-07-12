import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/game_screen_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('I4: rảnh tay 6s tự highlight nhóm gem lớn nhất còn lại', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    Get.put(GameController(), permanent: true).startLevel(1);

    await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    // Chờ intro animation dựng bàn xong (TimerComponent tắt `_animating`)
    // trước khi bắt đầu đếm giờ rảnh tay.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    final gsc = Get.find<GameScreenController>();
    final game = gsc.game;

    // Bàn xác định: mọi ô 1 màu riêng biệt (không nhóm nào >=2), trừ 1 nhóm
    // 3 ô liền kề màu 0 ở góc trên-trái — chắc chắn là nhóm lớn nhất.
    var counter = 1;
    game.colorGrid = List.generate(
      game.rows,
      (r) => List.generate(game.cols, (c) => counter++),
    );
    game.colorGrid[0][0] = 0;
    game.colorGrid[0][1] = 0;
    game.colorGrid[1][0] = 0;
    // Reset đồng hồ rảnh tay: thời gian idle tích luỹ từ lúc dựng bàn (trước
    // khi override colorGrid thủ công) không được tính vào ngưỡng 6s bên dưới.
    game.clearHint();

    expect(game.hintGroup, isEmpty);

    // Chưa đủ 6s rảnh tay → chưa trigger.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 900));
    }
    expect(game.hintGroup, isEmpty);

    // Vượt ngưỡng 6s (tổng ~9s rảnh tay) → tự động highlight nhóm lớn nhất.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 900));
    }
    expect(
      game.hintGroup,
      equals({const Point(0, 0), const Point(0, 1), const Point(1, 0)}),
    );

    // Tap bất kỳ đâu (kể cả ô trống hoặc không hợp lệ) → tắt gợi ý ngay.
    gsc.handleBoardTap(game.size / 2);
    expect(game.hintGroup, isEmpty);

    Get.reset();
  });
}
