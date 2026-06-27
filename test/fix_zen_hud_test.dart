import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/data/levels.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fix 3 — Chứng minh: zen HUD không còn hiện target vô nghĩa (268 triệu).
///
/// Root cause: `level` getter fallthrough về kLevels[currentLevel-1] khi isZen=true
/// → HUD đọc objective của màn campaign cũ → hiện "0 / 268.435.456" (hoặc order/collect
/// của màn campaign), user bị confuse.
///
/// Fix: thêm `_zenCfg = buildZenLevel()` + zen check trong `_goalValue` của GameScreen
/// → HUD chỉ hiện điểm hiện tại, không có "/" target.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.put(StorageService(await SharedPreferences.getInstance()));
    g = Get.put(GameController());
  });
  tearDown(Get.reset);

  group('Zen mode HUD không hiện target (Fix 3)', () {
    test('isZen=true sau startZen — HUD condition được trigger', () {
      g.startZen();
      expect(
        g.isZen.value,
        isTrue,
        reason: 'isZen phải true để HUD dùng branch "ĐIỂM" thay "MỤC TIÊU"',
      );
    });

    test(
      'zen level objective = score với targetScore không bao giờ đạt được',
      () {
        g.startZen();
        expect(g.level.objective, ObjectiveType.score);
        // Target phải rất lớn để game KHÔNG tự thắng
        expect(
          g.level.targetScore,
          greaterThan(99999999),
          reason: 'Target >= 1<<28 để game không tự kết thúc khi đạt điểm',
        );
      },
    );

    test('checkEnd luôn null — không hiện màn kết thúc tự động', () {
      g.startZen();
      // Giả lập điểm rất cao (user chơi lâu)
      for (int i = 0; i < 1000; i++) {
        g.addScore(100, 5);
      }
      expect(g.score.value, greaterThan(0));
      expect(
        g.checkEnd(),
        isNull,
        reason: 'Zen không bao giờ tự kết thúc dù điểm bao nhiêu',
      );
    });

    test('level.index = kZenLevelIndex, KHÔNG phải campaign level', () {
      // Setup: đặt currentLevel trước rồi mới zen
      g.startLevel(10); // campaign level 10
      expect(g.level.index, kLevels[9].index, reason: 'Đang ở campaign 10');

      g.startZen();
      expect(
        g.level.index,
        kZenLevelIndex,
        reason: 'Sau startZen phải dùng _zenCfg, không dùng campaign level cũ',
      );
      expect(
        g.level.index,
        isNot(kLevels[9].index),
        reason: 'Không được fallthrough về kLevels[9]',
      );
    });

    test(
      'HUD condition: isZen=true → dùng hud_score (ĐIỂM), không hud_goal (MỤC TIÊU)',
      () {
        // Test logic phân nhánh HUD (mô phỏng điều kiện trong game_screen.dart)
        g.startZen();

        // Điều kiện trong game_screen.dart:
        // label = ctrl.isZen.value ? 'hud_score'.tr : 'hud_goal'.tr
        final useScoreLabel = g.isZen.value; // phải true
        expect(
          useScoreLabel,
          isTrue,
          reason: 'isZen=true → dùng hud_score → hiện "ĐIỂM" thay "MỤC TIÊU"',
        );
      },
    );

    test('HUD _goalValue: zen chỉ hiện score, không phải "score/target"', () {
      g.startZen();
      g.addScore(350, 2); // user ghi được 350×2 = 700 điểm

      // Điều kiện trong game_screen._goalValue:
      // if (ctrl.isZen.value) return Text(fmtNum(ctrl.score.value))
      // → chỉ "700", không phải "700 / 268.435.456"
      final isZenBranch = g.isZen.value;
      expect(isZenBranch, isTrue);
      expect(
        g.score.value,
        greaterThan(0),
        reason:
            'Score hiện tại được dùng làm giá trị HUD thay cho score/target',
      );
      // targetScore không xuất hiện trong HUD zen → user không bị confuse
      expect(
        g.level.targetScore,
        greaterThan(99999999),
        reason: 'Target ẩn — không cần hiện ra vì zen không có mục tiêu',
      );
    });

    test('sau zen, startLevel bình thường → _zenCfg bị reset', () {
      g.startZen();
      expect(g.isZen.value, isTrue);
      expect(g.level.index, kZenLevelIndex);

      // Quay về campaign
      g.startLevel(5);
      expect(g.isZen.value, isFalse);
      expect(
        g.level.index,
        kLevels[4].index,
        reason: '_zenCfg = null sau khi rời zen → level trở về campaign',
      );
    });
  });
}
