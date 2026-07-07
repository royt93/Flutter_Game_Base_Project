import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/neon_theme.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:neon_jewels/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 25.2 — tương phản cảm giác: mỗi mode có accent màu + tên mở-màn riêng.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameController g;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    final prefs = await SharedPreferences.getInstance();
    Get.put(StorageService(prefs));
    g = Get.put(GameController());
  });
  tearDown(Get.reset);

  group('modeAccent — màu accent theo mode', () {
    test('campaign (không mode) → accent theo thế giới (world 1 = cyan)', () {
      expect(g.isSideMode, isFalse);
      expect(g.modeAccent, NeonTheme.accentForWorld(1));
    });

    test('mỗi side-mode có màu đặc trưng riêng', () {
      g.isBoss.value = true;
      expect(g.modeAccent, NeonTheme.red);
      g.isBoss.value = false;

      g.isRhythm.value = true;
      expect(g.modeAccent, NeonTheme.pink);
      g.isRhythm.value = false;

      g.isSurvival.value = true;
      expect(g.modeAccent, NeonTheme.cyan);
      g.isSurvival.value = false;

      g.isColorRush.value = true;
      expect(g.modeAccent, NeonTheme.orange);
      g.isColorRush.value = false;

      // Endless XOAY accent theo stage (review #3); stage 1 → worldAccents[0]
      g.isEndless.value = true;
      expect(g.modeAccent, NeonTheme.accentForWorld(1));
    });
  });

  group('modeIntroKey — tên mode cho mở-màn', () {
    test('campaign → null (không hiện mở-màn)', () {
      expect(g.modeIntroKey, isNull);
    });

    test('side-mode → key title đúng', () {
      g.isBoss.value = true;
      expect(g.modeIntroKey, 'boss_title');
      g.isBoss.value = false;

      g.isLabyrinth.value = true;
      expect(g.modeIntroKey, 'labyrinth_title');
      g.isLabyrinth.value = false;

      g.isZen.value = true;
      expect(g.modeIntroKey, 'zen_title');
    });
  });

  group('modeIntroIcon — icon mở-màn theo mode', () {
    test('campaign → null (không icon)', () {
      expect(g.modeIntroIcon, isNull);
    });

    test('side-mode → icon đúng', () {
      g.isBoss.value = true;
      expect(g.modeIntroIcon, Icons.coronavirus_rounded);
      g.isBoss.value = false;

      g.isLabyrinth.value = true;
      expect(g.modeIntroIcon, Icons.account_tree_rounded);
      g.isLabyrinth.value = false;

      g.isZen.value = true;
      expect(g.modeIntroIcon, Icons.spa_rounded);
    });
  });

  group('modeRuleKey — luật thắng 1 dòng theo mode', () {
    test('campaign → null (không có luật riêng)', () {
      expect(g.modeRuleKey, isNull);
    });

    test('side-mode → rule key đúng', () {
      g.isBoss.value = true;
      expect(g.modeRuleKey, 'rule_boss');
      g.isBoss.value = false;

      g.isLabyrinth.value = true;
      expect(g.modeRuleKey, 'rule_labyrinth');
      g.isLabyrinth.value = false;

      g.isZen.value = true;
      expect(g.modeRuleKey, 'rule_zen');
    });
  });
}
