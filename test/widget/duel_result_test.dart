import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/logic/ghost_duel.dart';
import 'package:pop_star_blast/logic/replay.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F16 — băng kết quả trận đấu ghost.
///
/// Trước batch này `duelOutcomeNow` có API + test nhưng **không nối UI**:
/// người chơi đấu xong không biết mình thắng hay thua. Đây là phần nợ đã ghi
/// khi đóng F16, giờ trả.
late GameController ctrl;

Future<void> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('kết quả hiện đúng nhãn', () {
    Future<void> play(int mine, int ghost) async {
      await _boot();
      ctrl.startDuel(
        DuelData(
          seed: 4242,
          taps: const [(0, 0)],
          score: ghost,
          senderName: 'Bạn A',
        ),
      );
      ctrl.score.value = mine;
    }

    test('hơn điểm -> thắng', () async {
      await play(700, 640);
      expect(ctrl.duelOutcomeNow, GhostDuelOutcome.win);
    });

    test('kém điểm -> thua', () async {
      await play(500, 640);
      expect(ctrl.duelOutcomeNow, GhostDuelOutcome.lose);
    });

    test('bằng điểm -> hoà', () async {
      await play(640, 640);
      expect(ctrl.duelOutcomeNow, GhostDuelOutcome.draw);
    });
  });

  testWidgets('nhãn i18n của cả 3 kết quả đều tồn tại', (tester) async {
    // Băng kết quả đọc 3 key này; thiếu key thì người chơi thấy chính tên key.
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        fallbackLocale: const Locale('en'),
        home: const SizedBox(),
      ),
    );
    for (final k in ['ghost_duel_win', 'ghost_duel_lose', 'ghost_duel_draw']) {
      expect(k.tr, isNot(k), reason: 'thiếu bản dịch cho "$k"');
    }
    expect('ghost_duel_rematch'.tr, isNot('ghost_duel_rematch'));
    expect('ghost_duel_copied'.tr, isNot('ghost_duel_copied'));
  });
}
