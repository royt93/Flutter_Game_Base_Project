import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/game_screen_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bơm nhiều frame nhỏ để game loop chạy hết effect + TimerComponent animation.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  testWidgets(
    'I76b Frost Rush: comboMeterFraction cập nhật theo game.comboTimerFraction '
    '(regression cho bug _startComboMeterPoll chỉ chạy ở comboRush, khiến '
    'thanh combo meter của Frost Rush đứng yên dù có combo)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs), permanent: true);
      final gameCtrl = Get.put(GameController(), permanent: true);
      gameCtrl.startSideMode(GameMode.frostRush);

      await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await _pumpFrames(tester, frames: 20); // A6: chờ hết intro rơi ô

      final gsc = Get.find<GameScreenController>();
      // Ép bàn về toàn 1 màu để chắc chắn có nhóm nổ được, tránh phụ thuộc RNG
      // và Ice Tile ép đặt của Frost Rush.
      gsc.game.colorGrid = List.generate(
        gsc.game.rows,
        (_) => List.generate(gsc.game.cols, (_) => 0),
      );
      gsc.game.lockGrid = List.generate(
        gsc.game.rows,
        (_) => List.generate(gsc.game.cols, (_) => 0),
      );

      expect(gsc.comboMeterFraction.value, 0.0);
      await tester.tapAt(
        tester.getCenter(find.byType(GameWidget<PopStarGame>)),
      );
      await _pumpFrames(tester);

      expect(gameCtrl.comboCount.value, greaterThan(0));
      expect(gsc.game.comboTimerFraction, greaterThan(0.0));
      // Không so bằng tuyệt đối với gsc.game.comboTimerFraction — giá trị đó
      // trôi liên tục còn comboMeterFraction chỉ lấy mẫu mỗi 100ms qua
      // _comboMeterPoll, nên 2 lần đọc lệch nhau vài mili-giây là bình
      // thường. Điều cần khẳng định là poll đã thực sự chạy cho frostRush.
      expect(gsc.comboMeterFraction.value, greaterThan(0.0));

      // GameScreen là StatelessWidget nên Get.put(GameScreenController(...))
      // không tự huỷ theo lifecycle widget — phải Get.delete() tường minh
      // (gọi onClose() -> cancel _comboMeterPoll) trước khi kết thúc test,
      // nếu không Timer.periodic vẫn còn sống khi framework kiểm tra
      // "timersPending" ở cuối test.
      Get.delete<GameScreenController>(force: true);
      Get.reset();
    },
  );
}
