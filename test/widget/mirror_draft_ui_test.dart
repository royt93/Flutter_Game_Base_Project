import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/game/pop_star_game.dart';
import 'package:pop_star_blast/logic/mirror_draft.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/controllers/game_screen_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F21 — hai khoản nợ đã ghi khi đóng task, giờ trả:
/// 1. hướng dẫn 2 câu lần đầu vào mode;
/// 2. tín hiệu khi nửa gương **không** nổ — rủi ro số 2 của task
///    ("đối xứng vỡ trông như bug").
late GameController gameCtrl;
late GameScreenController gsc;

Future<void> _boot({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  gameCtrl = Get.put(GameController(), permanent: true);
  gameCtrl.startMirrorDraft();
  gsc = Get.put(GameScreenController(gameCtrl), permanent: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('hướng dẫn lần đầu', () {
    test('lần đầu vào mode -> hiện', () async {
      await _boot();
      expect(gsc.showMirrorDraftTip.value, isTrue);
    });

    test('đã xem rồi -> không hiện lại', () async {
      await _boot(prefs: {StorageKeys.hasSeenMirrorDraftTip: true});
      expect(gsc.showMirrorDraftTip.value, isFalse);
    });

    test('đã bật "bỏ qua hướng dẫn" -> không hiện', () async {
      await _boot(prefs: {StorageKeys.skipTips: true});
      expect(gsc.showMirrorDraftTip.value, isFalse);
    });

    test('tắt là ghi nhớ vĩnh viễn', () async {
      await _boot();
      gsc.dismissMirrorDraftTip();

      expect(gsc.showMirrorDraftTip.value, isFalse);
      expect(
        StorageService.to.getBool(StorageKeys.hasSeenMirrorDraftTip),
        isTrue,
      );
    });

    test('mode khác KHÔNG hiện hướng dẫn này', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await SharedPreferences.getInstance();
      Get.put(StorageService(store), permanent: true);
      gameCtrl = Get.put(GameController(), permanent: true);
      gameCtrl.startLevel(1);
      gsc = Get.put(GameScreenController(gameCtrl), permanent: true);

      expect(gsc.showMirrorDraftTip.value, isFalse);
    });

    test('bản dịch tồn tại, dài đúng cỡ 2 câu', () {
      // Đọc thẳng bảng dịch: `.tr` chỉ hoạt động khi có `GetMaterialApp`, mà
      // ca này không dựng widget nào.
      // Khoá locale ở đây là dạng đầy đủ ('en_US'), không phải 'en'.
      final en = AppTranslations().keys['en_US']!;
      final vi = AppTranslations().keys['vi_VN']!;
      for (final m in [en, vi]) {
        final tip = m['mirror_draft_tip'];
        expect(tip, isNotNull);
        expect(
          tip!.length,
          lessThan(160),
          reason: 'hướng dẫn dài hơn 2 câu thì không ai đọc',
        );
      }
    });
  });

  group('tín hiệu nửa gương không nổ', () {
    testWidgets('nước chỉ nổ một bên -> tick tăng', (tester) async {
      await _boot();
      final game = PopStarGame(gameCtrl, presetGrid: presetGridForMode(gameCtrl));
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en'),
          fallbackLocale: const Locale('en'),
          home: GameWidget(game: game),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }

      // Nổ vài nước cho bàn phân kỳ, rồi tìm nước chỉ nổ được một bên.
      var found = false;
      for (var round = 0; round < 30 && !found; round++) {
        for (var r = 0; r < game.rows && !found; r++) {
          for (var c = 0; c < game.cols; c++) {
            final d = mirrorDraftCells(game.colorGrid, r, c);
            if (!d.isValid) continue;
            final before = gameCtrl.mirrorMissTick.value;
            game.handleTap(game.cellCenterFor(r, c));
            for (var i = 0; i < 25; i++) {
              await tester.pump(const Duration(milliseconds: 40));
            }
            if (!d.mirroredToo) {
              expect(
                gameCtrl.mirrorMissTick.value,
                before + 1,
                reason: 'không báo thì người chơi tưởng game lỗi',
              );
              found = true;
            } else {
              expect(gameCtrl.mirrorMissTick.value, before);
            }
            break;
          }
        }
      }
      expect(found, isTrue, reason: 'không dựng được ca nổ-một-bên');
    });

    test('bản dịch nhãn tồn tại ở cả en lẫn vi', () {
      for (final lang in ['en_US', 'vi_VN']) {
        expect(
          AppTranslations().keys[lang]!['mirror_draft_no_mirror'],
          isNotNull,
          reason: 'thiếu bản dịch cho "$lang"',
        );
      }
    });
  });
}
