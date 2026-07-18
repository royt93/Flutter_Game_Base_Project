import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/levels.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/logic/replay.dart';
import 'package:pop_star_blast/presentation/screens/ghost_replay_screen.dart';
import 'package:pop_star_blast/presentation/widgets/neon_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bơm nhiều frame nhỏ để game loop chạy hết effect + TimerComponent animation.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<void> _setupStorage() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put(StorageService(prefs), permanent: true);
}

void main() {
  testWidgets(
    'I28: mã hợp lệ → tự động phát lại, KHÔNG cộng thưởng thật dù có pop',
    (tester) async {
      await _setupStorage();

      // 2 tap cùng ô: tap đầu nổ nhóm ép sẵn, tap sau rơi vào ô rỗng (vô hại).
      final data = ReplayData(
        levelId: 1,
        seed: 1,
        taps: const [(0, 0), (0, 0)],
      );
      final code = encodeReplay(data);

      await tester.pumpWidget(GetMaterialApp(home: const GhostReplayScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), code);
      await tester.tap(find.byType(NeonButton));
      await tester.pump(const Duration(milliseconds: 100));
      // Chỉ bơm đủ để Flame onLoad() dựng xong board, KHÔNG được vượt quá
      // 450ms (_tapInterval) tính từ lúc bấm nút — nếu không, Timer.periodic
      // tự tap trước khi kịp ép lưới bên dưới, khiến bài test chạy nhầm trên
      // bàn ngẫu nhiên gốc thay vì bàn đã ép sẵn.
      await _pumpFrames(tester, frames: 5); // 200ms, tổng ~300ms từ lúc tap

      final game = tester
          .widget<GameWidget<PopStarGame>>(find.byType(GameWidget<PopStarGame>))
          .game!;
      expect(game.isReplay, isTrue);

      // Ép nhóm màu 0 ở hàng 0 (đủ ≥2 ô để nổ), cột cuối filler màu 1 —
      // đồng bộ pattern với replay_recording_test.dart.
      game.colorGrid = List.generate(
        game.rows,
        (r) => List<int?>.generate(
          game.cols,
          (c) => r == 0 && c < game.cols - 1 ? 0 : 1,
        ),
      );
      game.onGameResize(game.size);

      final coinsBefore = StorageService.to.getInt(StorageKeys.coins);
      final unlockedBefore = StorageService.to.getInt(
        StorageKeys.unlockedLevel,
        def: 1,
      );
      final highScoreBefore = StorageService.to.getInt(
        StorageKeys.highScore(1),
      );
      final starBefore = StorageService.to.getInt(StorageKeys.star(1));

      // Đợi Timer.periodic (450ms/lần) tự tap đủ 2 lượt đã ghi.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 450));
      }
      await _pumpFrames(tester); // hiệu ứng clear/collapse chạy xong hẳn

      expect(StorageService.to.getInt(StorageKeys.coins), coinsBefore);
      expect(
        StorageService.to.getInt(StorageKeys.unlockedLevel, def: 1),
        unlockedBefore,
      );
      expect(
        StorageService.to.getInt(StorageKeys.highScore(1)),
        highScoreBefore,
      );
      expect(StorageService.to.getInt(StorageKeys.star(1)), starBefore);

      Get.reset();
    },
  );

  testWidgets('I28: mã không phải base64 hợp lệ → báo lỗi, không crash', (
    tester,
  ) async {
    await _setupStorage();

    await tester.pumpWidget(GetMaterialApp(home: const GhostReplayScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'không phải mã hợp lệ!!!');
    await tester.tap(find.byType(NeonButton));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ghost_replay_invalid_code'.tr), findsOneWidget);
    expect(find.byType(GameWidget<PopStarGame>), findsNothing);

    Get.reset();
  });

  testWidgets(
    'I28: levelId ngoài phạm vi [1, kLevelCount] (giả mạo tay) → báo lỗi',
    (tester) async {
      await _setupStorage();

      final tooHigh = encodeReplay(
        ReplayData(levelId: kLevelCount + 1, seed: 1, taps: const []),
      );
      final tooLow = encodeReplay(
        ReplayData(levelId: 0, seed: 1, taps: const []),
      );

      await tester.pumpWidget(GetMaterialApp(home: const GhostReplayScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), tooHigh);
      await tester.tap(find.byType(NeonButton));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ghost_replay_invalid_code'.tr), findsOneWidget);

      await tester.enterText(find.byType(TextField), tooLow);
      await tester.tap(find.byType(NeonButton));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ghost_replay_invalid_code'.tr), findsOneWidget);

      Get.reset();
    },
  );

  testWidgets(
    'I28: taps rỗng → tự kết thúc ngay, không crash, không cộng thưởng',
    (tester) async {
      await _setupStorage();
      final code = encodeReplay(
        ReplayData(levelId: 1, seed: 1, taps: const []),
      );

      await tester.pumpWidget(GetMaterialApp(home: const GhostReplayScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), code);
      await tester.tap(find.byType(NeonButton));
      await tester.pump(const Duration(milliseconds: 100));
      // Dùng nhiều pump nhỏ (không phải 1-2 pump lớn) để Flame update(dt)
      // tích luỹ đúng qua hiệu ứng intro rơi ô (~590ms cho bàn 8x6, bị
      // `isAnimating` chặn nhịp Timer đầu) rồi mới tới nhịp Timer kế tiếp
      // thấy taps rỗng → kết thúc ngay — đồng bộ cách bơm frame với các test
      // khác trong file này.
      await _pumpFrames(tester, frames: 30); // ~1.2s, đủ qua 2 nhịp Timer

      expect(find.text('ghost_replay_finished'.tr), findsOneWidget);

      Get.reset();
    },
  );

  testWidgets(
    'I28: dispose giữa chừng playback → huỷ Timer, không leak (tránh race '
    'condition)',
    (tester) async {
      await _setupStorage();
      final code = encodeReplay(
        ReplayData(levelId: 1, seed: 1, taps: const [(0, 0), (1, 1), (2, 2)]),
      );

      await tester.pumpWidget(GetMaterialApp(home: const GhostReplayScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), code);
      await tester.tap(find.byType(NeonButton));
      await tester.pump(const Duration(milliseconds: 100));
      // Chỉ pump 1 nhịp ngắn — cố tình rời màn hình khi playback CHƯA xong,
      // để bắt lỗi nếu `dispose()` quên huỷ `_timer`.
      await tester.pump(const Duration(milliseconds: 200));

      await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
      await tester.pump(const Duration(milliseconds: 100));
      // flutter_test tự fail nếu còn Timer đang chờ lúc kết thúc test —
      // không cần assert thủ công.

      Get.reset();
    },
  );
}
