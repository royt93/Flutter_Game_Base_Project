import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/pigments.dart';
import 'package:pop_star_blast/logic/mystery_crate.dart';
import 'package:pop_star_blast/logic/replay.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ba khoản nợ nhỏ đã ghi khi đóng F16 / F18 / F19, giờ trả.
late GameController ctrl;

Future<void> _boot({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);
}

DuelData _duel() => const DuelData(
  seed: 4242,
  taps: [(0, 0), (1, 1)],
  score: 500,
  senderName: 'A',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('F16 — bật/tắt điểm ghost', () {
    test('mặc định BẬT khi không giảm chuyển động', () async {
      await _boot();
      ctrl.startDuel(_duel());
      expect(ctrl.showGhostScore.value, isTrue);
    });

    test('mặc định TẮT khi đã bật giảm chuyển động', () async {
      // Con số nhấp nháy theo từng nước là đúng loại chuyển động họ vừa xin bớt.
      await _boot(prefs: {StorageKeys.reduceMotion: true});
      ctrl.startDuel(_duel());
      expect(ctrl.showGhostScore.value, isFalse);
    });

    test('bật/tắt được giữa ván', () async {
      await _boot();
      ctrl.startDuel(_duel());

      ctrl.toggleGhostScore();
      expect(ctrl.showGhostScore.value, isFalse);
      ctrl.toggleGhostScore();
      expect(ctrl.showGhostScore.value, isTrue);
    });

    test('KHÔNG persist — là lựa chọn của một trận', () async {
      await _boot();
      ctrl.startDuel(_duel());
      ctrl.toggleGhostScore();
      expect(ctrl.showGhostScore.value, isFalse);

      ctrl.startDuel(_duel());
      expect(
        ctrl.showGhostScore.value,
        isTrue,
        reason: 'ván mới phải theo mặc định, không nhớ lựa chọn ván cũ',
      );
    });

    test('tắt ghost KHÔNG làm sai kết quả trận', () async {
      await _boot();
      ctrl.startDuel(_duel());
      ctrl.toggleGhostScore();
      ctrl.score.value = 900;

      expect(ctrl.duelOutcomeNow, isNotNull);
      expect(ctrl.ghostScoreNow, isNotNull);
    });
  });

  group('F18 — nhãn "đã chơi hôm nay"', () {
    final today = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;

    test('chưa chơi -> còn ghi điểm được', () async {
      await _boot();
      expect(ctrl.canRecordPuzzleDailyScore, isTrue);
    });

    test('đã chơi hôm nay -> hết lượt ghi điểm', () async {
      await _boot(prefs: {StorageKeys.lastPuzzleDailyDay: today});
      expect(ctrl.canRecordPuzzleDailyScore, isFalse);
    });

    test('mốc của hôm qua -> hôm nay ghi lại được', () async {
      await _boot(prefs: {StorageKeys.lastPuzzleDailyDay: today - 1});
      expect(ctrl.canRecordPuzzleDailyScore, isTrue);
    });
  });

  group('F19 — pigment KHÔNG tính vào Sticker Album', () {
    test('mystery_crate chỉ bọc 4 hệ cosmetic, không có pigment', () {
      final kinds = getAllCosmeticEntries().map((e) => e.kind).toSet();
      expect(kinds.length, lessThanOrEqualTo(CosmeticKind.values.length));
      // Không có CosmeticKind nào cho pigment — ranh giới cố ý.
      expect(CosmeticKind.values.length, 4);
    });

    test('mở khoá pigment KHÔNG làm tăng totalCosmeticsOwned', () async {
      // Chốt quyết định của F19: thêm pigment vào con số này sẽ phát mốc
      // Sticker Album khống cho mọi người chơi cũ, mà mốc đã nhận không lấy
      // lại được.
      await _boot();
      final before = ctrl.totalCosmeticsOwned;

      for (final p in kPigments) {
        ctrl.unlockedPigmentIds.add(p.id);
      }

      expect(ctrl.totalCosmeticsOwned, before);
    });

    test('pha pigment fusion cũng không đổi con số', () async {
      await _boot(prefs: {
        StorageKeys.craftPoints: 99,
        StorageKeys.unlockedPigments: 'aqua,coral',
      });
      final before = ctrl.totalCosmeticsOwned;

      expect(ctrl.fusePigments('aqua', 'coral'), isNotNull);

      expect(ctrl.totalCosmeticsOwned, before);
    });
  });
}
