import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F21 — phần nối Mirror Draft vào `GameController`.
late GameController ctrl;

Future<void> _boot({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('bắt đầu ván', () {
    test('vào đúng mode, bàn ĐỐI XỨNG dọc', () async {
      await _boot();
      ctrl.startMirrorDraft();

      expect(ctrl.mode.value, GameMode.mirrorDraft);
      expect(ctrl.currentLevel.id, -21);

      final g = ctrl.puzzleLabGrid!;
      final cols = g.first.length;
      for (final row in g) {
        for (var c = 0; c < cols ~/ 2; c++) {
          expect(
            row[c],
            row[cols - 1 - c],
            reason: 'bàn phải đối xứng lúc mới sinh',
          );
        }
      }
    });

    test('reset điểm và cờ gương', () async {
      await _boot();
      ctrl.lastMirrorMirrored = true;
      ctrl.startMirrorDraft();
      expect(ctrl.score.value, 0);
      expect(ctrl.lastMirrorMirrored, isFalse);
    });

    test('mỗi ván một bàn mới', () async {
      await _boot();
      ctrl.startMirrorDraft();
      final a = ctrl.puzzleLabGrid;
      var differs = false;
      for (var i = 0; i < 5 && !differs; i++) {
        ctrl.startMirrorDraft();
        differs = ctrl.puzzleLabGrid.toString() != a.toString();
      }
      expect(differs, isTrue, reason: 'bàn cố định thì chơi lại vô nghĩa');
    });
  });

  group('nếp chung side-mode', () {
    test('KHÔNG đụng star/highScore/unlock campaign', () async {
      await _boot();
      final unlockedBefore = ctrl.unlockedLevel.value;
      final starsBefore = ctrl.totalStars.value;

      ctrl.startMirrorDraft();
      ctrl.score.value = 99999;
      ctrl.checkEnd(true);

      expect(ctrl.unlockedLevel.value, unlockedBefore);
      expect(ctrl.totalStars.value, starsBefore);
      expect(ctrl.starsEarned.value, 0);
    });

    test('best score key riêng, chỉ tăng', () async {
      await _boot();
      ctrl.startMirrorDraft();
      ctrl.score.value = 800;
      ctrl.checkEnd(true);
      expect(ctrl.mirrorDraftBest, 800);

      ctrl.startMirrorDraft();
      ctrl.score.value = 100;
      ctrl.checkEnd(true);
      expect(ctrl.mirrorDraftBest, 800);
    });

    test('best nạp lại từ save', () async {
      await _boot(prefs: {StorageKeys.mirrorDraftBest: 555});
      expect(ctrl.mirrorDraftBest, 555);
    });

    test('KHÔNG đụng best của Mirror Mode (I47)', () async {
      // Hai mode tên gần giống nhau, key phải tách bạch.
      await _boot(prefs: {StorageKeys.mirrorModeBest: 111});
      ctrl.startMirrorDraft();
      ctrl.score.value = 900;
      ctrl.checkEnd(true);

      expect(ctrl.mirrorDraftBest, 900);
      expect(
        StorageService.to.getInt(StorageKeys.mirrorModeBest),
        111,
        reason: 'Mirror Draft ghi đè best của Mirror Mode là mất kỷ lục cũ',
      );
    });
  });
}
