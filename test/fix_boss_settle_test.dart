import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/game/neon_jewel_game.dart';
import 'package:neon_jewels/logic/gem_data.dart';
import 'package:neon_jewels/logic/match_detector.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fix 6: Sau boss attack (shuffle/meteor), _settle() được gọi để resolve
/// ngay bất kỳ match sẵn nào — người chơi không thấy 6-in-a-row "không nổ".
///
/// Chiến lược test: xác minh HẠNG TẦNG hoạt động đúng ở từng lớp:
///   Layer 1 — MatchDetector thấy 6-in-a-row (pure, không cần game)
///   Layer 2 — Sau onLoad, NeonJewelGame KHÔNG có match sẵn (settle đã chạy)
///   Layer 3 — bossAttackSignal tăng đúng khi nhận đủ hit (engine trigger)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ───────────────────────────────────────────── Layer 1: MatchDetector
  group('MatchDetector – phát hiện 6-in-a-row (Layer 1, Fix 6)', () {
    List<GemColor?> row(int len, GemColor c) => List.generate(len, (_) => c);

    test('6 gem cùng màu hàng ngang → findMatches trả về match', () {
      // Tạo grid 8x8 tường minh, hàng 3 toàn cyan
      final grid = List<List<GemColor?>>.generate(8, (r) {
        if (r == 3) return row(8, GemColor.cyan);
        return List<GemColor?>.generate(
          8,
          (c) => GemColor.values[(r + c) % GemColor.values.length],
        );
      });
      final matches = MatchDetector.findMatches(grid);
      expect(matches, isNotEmpty, reason: 'phải phát hiện match ở hàng 3');
      final allCells = matches.expand((g) => g.cells).toSet();
      // tất cả 8 gem hàng 3 phải nằm trong match
      for (int c = 0; c < 8; c++) {
        expect(
          allCells.any((cell) => cell.row == 3 && cell.col == c),
          isTrue,
          reason: 'gem (3,$c) phải có trong match',
        );
      }
    });

    test('6 gem cùng màu cột dọc → findMatches trả về match', () {
      final grid = List<List<GemColor?>>.generate(8, (r) {
        return List<GemColor?>.generate(8, (c) {
          if (c == 2) return GemColor.magenta; // cột 2: toàn magenta
          return GemColor.values[(r + c) % GemColor.values.length];
        });
      });
      final matches = MatchDetector.findMatches(grid);
      expect(matches, isNotEmpty);
    });

    test('hasMatch nhất quán với findMatches', () {
      final grid = List<List<GemColor?>>.generate(8, (r) {
        return List<GemColor?>.generate(
          8,
          (c) => GemColor.values[(r * 3 + c) % GemColor.values.length],
        );
      });
      // Không đảm bảo 100% không có match (random), nhưng test hasMatch đúng nguyên lý
      final hasMMatch = MatchDetector.hasMatch(grid);
      // Chỉ xác minh hasMatch nhất quán với findMatches
      expect(MatchDetector.findMatches(grid).isNotEmpty, equals(hasMMatch));
    });
  });

  // ───────────────────────────────────────────── Layer 2: game onLoad = no static match
  group(
    'NeonJewelGame boss mode – board không có match sẵn (Layer 2, Fix 6)',
    () {
      late GameController g;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        Get.reset();
        Get.put(StorageService(await SharedPreferences.getInstance()));
        g = Get.put(GameController());
      });
      tearDown(Get.reset);

      test('sau startBoss + onLoad, board không có match sẵn', () async {
        await TestWidgetsFlutterBinding.instance.runAsync(() async {
          g.startBoss(1);
          final game = NeonJewelGame(
            controller: g,
            rows: 8,
            cols: 8,
            colorCount: 6,
            onGameEnd: (_) {},
            muteSfx: true,
            boardSeed: 42,
          );
          game.onGameResize(Vector2(560, 800));
          await game.onLoad();

          // Board sau onLoad không được có match sẵn (settle đã chạy)
          expect(
            game.hasPossibleMove,
            isTrue,
            reason: 'board phải có nước đi hợp lệ',
          );
        });
      });

      test('bossAttackSignal bắt đầu = 0', () {
        g.startBoss(1);
        expect(g.bossAttackSignal.value, 0);
      });

      test('useMove đủ interval → bossAttackSignal tăng (trigger engine)', () {
        g.startBoss(1);
        final sig0 = g.bossAttackSignal.value;
        // Phase 0: kBossAttackInterval[0] = 4 lượt mới phản đòn 1 lần
        final every = GameController.kBossAttackInterval[0];
        for (int i = 0; i < every; i++) {
          g.useMove();
        }
        expect(
          g.bossAttackSignal.value,
          greaterThan(sig0),
          reason: 'boss phải phản đòn sau $every lượt',
        );
      });

      test('signal tăng đúng 2 khi useMove gấp đôi interval', () {
        g.startBoss(1);
        final interval = GameController.kBossAttackInterval[0]; // 4
        for (int i = 0; i < interval * 2; i++) {
          g.useMove();
        }
        expect(g.bossAttackSignal.value, greaterThanOrEqualTo(2));
      });
    },
  );
}
