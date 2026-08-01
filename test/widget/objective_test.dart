import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/levels.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/logic/gift_tile.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/game_screen_controller.dart';
import 'package:pop_star_blast/presentation/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpFrames(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  testWidgets(
    'F6b: màn clearColor thắng ngay khi hết màu mục tiêu, dù bàn còn ô khác',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs), permanent: true);
      final gameCtrl = Get.put(GameController(), permanent: true);
      gameCtrl.startLevel(1);
      final base = gameCtrl.currentLevel;
      gameCtrl.currentLevelRx.value = PopLevel(
        id: base.id,
        rows: base.rows,
        cols: base.cols,
        colorCount: base.colorCount,
        targetScore: base.targetScore,
        objective: const LevelObjective.clearColor(0),
      );

      await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await _pumpFrames(tester, frames: 20); // A6: chờ hết intro rơi ô

      final gsc = Get.find<GameScreenController>();
      final game = gsc.game;

      // Chỉ 2 ô màu 0 (mục tiêu), còn lại toàn màu 1 — bàn vẫn đầy sau khi
      // dọn xong màu 0 nên chỉ objective mới kết thúc được ván, không phải
      // bàn hết/kẹt.
      game.colorGrid = List.generate(
        game.rows,
        (r) => List.generate(game.cols, (c) {
          if (r == 0 && c == 0) return 0;
          if (r == 0 && c == 1) return 0;
          return 1;
        }),
      );
      game.onGameResize(game.size);

      expect(gameCtrl.ended.value, isFalse);
      game.handleTap(game.cellCenterFor(0, 0));
      await _pumpFrames(tester);

      expect(gameCtrl.objectiveRemaining.value, 0);
      expect(gameCtrl.ended.value, isTrue);
      // Bàn chưa hết — chứng minh thắng do objective, không phải clear-board.
      expect(game.colorGrid[0][2], isNotNull);

      Get.reset();
    },
  );

  testWidgets(
    'F6b: màn campaign clearObstacle (level 5) dựng bàn có sẵn obstacle',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs), permanent: true);
      final gameCtrl = Get.put(GameController(), permanent: true);
      gameCtrl.startLevel(5); // i=4, slot 4 → clearObstacle theo levels.dart

      await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await _pumpFrames(tester, frames: 20); // chờ hết intro rơi ô

      final gsc = Get.find<GameScreenController>();
      final grid = gsc.game.colorGrid;

      expect(gameCtrl.currentLevel.objective.type, ObjectiveType.clearObstacle);
      expect(
        grid.expand((row) => row).where((v) => v != null && v < 0),
        isNotEmpty,
      );

      Get.reset();
    },
  );

  testWidgets('F9-fix: màn collect thắng ngay khi đủ số ô màu mục tiêu bị nổ', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs), permanent: true);
    final gameCtrl = Get.put(GameController(), permanent: true);
    gameCtrl.startLevel(1);
    final base = gameCtrl.currentLevel;
    gameCtrl.currentLevelRx.value = PopLevel(
      id: base.id,
      rows: base.rows,
      cols: base.cols,
      colorCount: base.colorCount,
      targetScore: base.targetScore,
      objective: const LevelObjective.collect(0, 2),
    );

    await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await _pumpFrames(tester, frames: 20); // A6: chờ hết intro rơi ô

    final gsc = Get.find<GameScreenController>();
    final game = gsc.game;

    // Chỉ 2 ô màu 0 (đúng target) — bàn vẫn đầy sau khi dọn xong nên chỉ
    // objective mới kết thúc được ván, không phải bàn hết/kẹt.
    game.colorGrid = List.generate(
      game.rows,
      (r) => List.generate(game.cols, (c) {
        if (r == 0 && c == 0) return 0;
        if (r == 0 && c == 1) return 0;
        return 1;
      }),
    );
    game.onGameResize(game.size);

    expect(gameCtrl.ended.value, isFalse);
    game.handleTap(game.cellCenterFor(0, 0));
    await _pumpFrames(tester);

    expect(gameCtrl.objectiveRemaining.value, 0);
    expect(gameCtrl.ended.value, isTrue);
    // Bàn chưa hết — chứng minh thắng do objective, không phải clear-board.
    expect(game.colorGrid[0][2], isNotNull);

    Get.reset();
  });

  test(
    'F9-fix: bàn màn collect luôn đủ số ô màu mục tiêu ngay từ đầu (sweep 500 seed)',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs), permanent: true);
      final gameCtrl = GameController();
      // Kích thước worst-case (level 6/15 theo levels.dart): 48 ô, 5 màu,
      // target=5 — trước fix có ~2.48% xác suất bàn random không đủ.
      const level = PopLevel(
        id: 6,
        rows: 8,
        cols: 6,
        colorCount: 5,
        targetScore: 1,
        objective: LevelObjective.collect(0, 5),
      );
      gameCtrl.currentLevelRx.value = level;

      for (var seed = 0; seed < 500; seed++) {
        final game = PopStarGame(gameCtrl, seed: seed);
        // GameWidget gọi onGameResize (thiết lập layout) TRƯỚC onLoad() —
        // mô phỏng lại thủ công vì test này bỏ qua pumpWidget để chạy nhanh.
        game.onGameResize(Vector2(800, 600));
        await game.onLoad();
        final count = game.colorGrid
            .expand((row) => row)
            .where((v) => v == 0)
            .length;
        expect(
          count,
          greaterThanOrEqualTo(5),
          reason: 'seed=$seed chỉ có $count ô màu 0, cần >= 5',
        );
      }

      Get.reset();
    },
  );

  test(
    'F9-fix2: countdown-lock/wildcard không đè lên ô màu mục tiêu objective collect (sweep 300 seed, level > 60)',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs), permanent: true);
      final gameCtrl = GameController();
      // Bàn nhỏ, target = toàn bộ ô — bất kỳ ô nào bị countdown-lock/wildcard
      // đè lên cũng chắc chắn là ô màu mục tiêu, tối đa hoá khả năng bắt lỗi.
      // id > 60 để bật cả countdown-lock (~18%) lẫn wildcard (~15%).
      const level = PopLevel(
        id: 61,
        rows: 4,
        cols: 3,
        colorCount: 2,
        targetScore: 1,
        objective: LevelObjective.collect(0, 12),
      );
      gameCtrl.currentLevelRx.value = level;

      for (var seed = 0; seed < 300; seed++) {
        final game = PopStarGame(gameCtrl, seed: seed);
        game.onGameResize(Vector2(800, 600));
        await game.onLoad();
        final count = game.colorGrid
            .expand((row) => row)
            .where((v) => v == 0)
            .length;
        expect(
          count,
          12,
          reason:
              'seed=$seed chỉ có $count/12 ô màu 0 sau khi countdown-lock/wildcard đặt xong',
        );
      }

      Get.reset();
    },
  );

  testWidgets(
    'F9-fix: gift ở đáy bàn tự mở khi tap nổ nhóm khác, hoàn thành objective openGift',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs), permanent: true);
      final gameCtrl = Get.put(GameController(), permanent: true);
      gameCtrl.startLevel(1);
      final base = gameCtrl.currentLevel;
      gameCtrl.currentLevelRx.value = PopLevel(
        id: base.id,
        rows: base.rows,
        cols: base.cols,
        colorCount: base.colorCount,
        targetScore: base.targetScore,
        objective: const LevelObjective.openGift(1),
      );

      await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await _pumpFrames(tester, frames: 20); // A6: chờ hết intro rơi ô

      final gsc = Get.find<GameScreenController>();
      final game = gsc.game;

      // 1 gift ở đáy cột 0 — _checkEnd() quét gift ở hàng đáy vô điều kiện
      // nên sẽ tự mở ngay lần settle kế tiếp, không cần tap đúng cột đó.
      // Nhóm 2 ô màu 0 ở cột 1 để có gì đó nổ mà không đụng cột 0.
      game.colorGrid = List.generate(
        game.rows,
        (r) => List.generate(game.cols, (c) {
          if (c == 0) return r == game.rows - 1 ? giftTileValue : 1;
          if (c == 1 && (r == 0 || r == 1)) return 0;
          return 1;
        }),
      );
      game.onGameResize(game.size);

      expect(gameCtrl.objectiveRemaining.value, 1);
      game.handleTap(game.cellCenterFor(0, 1));
      await _pumpFrames(tester);

      expect(gameCtrl.objectiveRemaining.value, 0);
      expect(gameCtrl.ended.value, isTrue);

      Get.reset();
    },
  );

  testWidgets(
    'F9-fix: màn obstacleInMoves thắng ngay khi obstacle liền kề bị chip vỡ',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      Get.put(StorageService(prefs), permanent: true);
      final gameCtrl = Get.put(GameController(), permanent: true);
      gameCtrl.startLevel(1);
      final base = gameCtrl.currentLevel;
      gameCtrl.currentLevelRx.value = PopLevel(
        id: base.id,
        rows: base.rows,
        cols: base.cols,
        colorCount: base.colorCount,
        targetScore: base.targetScore,
        objective: const LevelObjective.obstacleInMoves(1, 30),
      );

      await tester.pumpWidget(GetMaterialApp(home: const GameScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await _pumpFrames(tester, frames: 20); // A6: chờ hết intro rơi ô

      final gsc = Get.find<GameScreenController>();
      final game = gsc.game;

      // objectiveRemaining của obstacleInMoves đếm TẤT CẢ ô âm trên bàn nên
      // chỉ được có đúng 1 obstacle (durability=1, mã -1) liền kề nhóm màu 0
      // sẽ nổ, không có ô âm nào khác (gift/countdown/wildcard) lẫn vào.
      game.colorGrid = List.generate(
        game.rows,
        (r) => List.generate(game.cols, (c) {
          if (r == 0 && c == 0) return 0;
          if (r == 0 && c == 1) return 0;
          if (r == 0 && c == 2) return -1; // obstacle durability=1
          return 1;
        }),
      );
      game.onGameResize(game.size);

      expect(gameCtrl.ended.value, isFalse);
      game.handleTap(game.cellCenterFor(0, 0));
      await _pumpFrames(tester);

      expect(gameCtrl.objectiveRemaining.value, 0);
      expect(gameCtrl.ended.value, isTrue);

      Get.reset();
    },
  );
}
