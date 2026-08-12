import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/board_frames.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/board_frame_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `BoardFrameScreen` (I73) — chưa có test widget nào.
///
/// `test/data/board_frames_test.dart` đã phủ phần thuần (`isBoardFrameUnlocked`,
/// cửa sổ mùa wrap qua năm). Phần chưa ai kiểm là **màn hình**, nơi có 4 nguồn
/// mở khoá khác nhau (prestige, achievement, treasure map, mùa) nối vào cùng
/// một `onTap: unlocked ? ... : null`, cộng lời gọi
/// `revalidateActiveBoardFrame()` ngay trong `build`.
///
/// Điểm tinh tế nhất của I73 và cũng là thứ dễ "sửa nhầm cho gọn" nhất:
/// khung theo mùa hết hạn thì **hiển thị** rơi về classic nhưng **storage giữ
/// nguyên id** — mùa sau tự hiện lại. Ghi đè storage lúc đó là mất lựa chọn
/// của người chơi vĩnh viễn.
late GameController ctrl;

const _prestigeFrame = 'neon_cyan'; // cần prestigeTier >= 1
const _achFrame = 'diamond'; // cần achievement 'clear_400'
const _treasureFrame = 'treasure_relic'; // cần hoàn thành treasure map

BoardFrame _f(String id) => kBoardFrames.firstWhere((f) => f.id == id);

/// Khung theo mùa đang **ngoài** cửa sổ ngay lúc chạy test.
///
/// Không hard-code 'seasonal_tet': màn hình gọi `isBoardFrameUnlocked` không
/// truyền `now`, tức là đọc đồng hồ thật — hard-code sẽ tự đỏ vào đúng dịp
/// Tết/Halloween/Giáng sinh. Có 3 khung mùa và tối đa 1 khung mở cùng lúc, nên
/// luôn tồn tại khung đang khoá.
BoardFrame get _outOfSeasonFrame => kBoardFrames.firstWhere(
  (f) =>
      f.unlockKind == BoardFrameUnlockKind.seasonal &&
      !isBoardFrameUnlocked(f, 0, const {}),
);

Future<void> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);

  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: const BoardFrameScreen(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Finder _row(String id) => find.ancestor(
  of: find.text(_f(id).nameKey.tr),
  matching: find.byType(GestureDetector),
);

Future<void> _tapRow(WidgetTester tester, String id) async {
  final f = _row(id);
  await tester.ensureVisible(f.first);
  await tester.pump(const Duration(milliseconds: 120));
  await tester.tap(f.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 250));
}

/// Dấu tick chỉ vẽ trên hàng đang active.
Finder _checkOn(String id) => find.descendant(
  of: _row(id),
  matching: find.byIcon(Icons.check_circle_rounded),
);

void main() {
  tearDown(Get.reset);

  group('dựng màn hình', () {
    testWidgets('render được, không ném', (tester) async {
      await _pump(tester);
      expect(find.byType(BoardFrameScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('liệt kê đủ mọi khung, kể cả chưa mở', (tester) async {
      await _pump(tester);
      for (final f in kBoardFrames) {
        expect(
          find.text(f.nameKey.tr),
          findsOneWidget,
          reason:
              'thiếu khung "${f.id}" — người chơi phải thấy đích phía trước',
        );
      }
    });

    testWidgets('mặc định classic được đánh dấu đang dùng', (tester) async {
      await _pump(tester);
      expect(_checkOn(kBoardFrames.first.id), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('khung chưa mở hiện điều kiện mở khoá', (tester) async {
      await _pump(tester);
      expect(
        find.text(
          'board_frame_unlock_prestige'.trParams({
            'tier': '${_f(_prestigeFrame).requiredPrestigeTier}',
          }),
        ),
        findsOneWidget,
      );
      expect(find.text('board_frame_unlock_treasure'.tr), findsOneWidget);
    });
  });

  group('khung chưa mở khoá thì trơ', () {
    for (final entry in {
      'prestige': _prestigeFrame,
      'achievement': _achFrame,
      'treasure map': _treasureFrame,
    }.entries) {
      testWidgets('${entry.key}: bấm không đổi được', (tester) async {
        await _pump(tester);

        await _tapRow(tester, entry.value);

        expect(
          ctrl.activeBoardFrameId.value,
          kBoardFrames.first.id,
          reason: 'dùng được khung chưa kiếm ra là cho không phần thưởng',
        );
        expect(_checkOn(entry.value), findsNothing);
      });
    }

    testWidgets('theo mùa ngoài cửa sổ: bấm không đổi được', (tester) async {
      await _pump(tester);

      await _tapRow(tester, _outOfSeasonFrame.id);

      expect(ctrl.activeBoardFrameId.value, kBoardFrames.first.id);
    });

    testWidgets('setActiveBoardFrame cũng chặn, không chỉ UI', (tester) async {
      // Hàng khoá có `onTap: null` nên test bấm ở trên không bao giờ chạm tới
      // guard trong controller. Gọi thẳng để khoá tuyến phòng thủ thứ hai.
      //
      // Mutation-check nói rõ ai mới là người giữ cửa: đổi
      // `onTap: unlocked ? ... : null` thành `onTap: ...` (bỏ hẳn guard UI) mà
      // **cả 18 ca vẫn xanh** — vì controller chặn tiếp. Guard UI chỉ lo phần
      // cảm nhận (bấm vào không có gì xảy ra thay vì mờ đi và trơ), không phải
      // phần đúng-sai. Đừng đọc bộ test này như bằng chứng nó được phủ.
      await _pump(tester);
      ctrl.setActiveBoardFrame(_prestigeFrame);
      expect(ctrl.activeBoardFrameId.value, kBoardFrames.first.id);
      expect(
        StorageService.to.getString(StorageKeys.activeBoardFrame),
        isNot(_prestigeFrame),
      );
    });
  });

  group('khung đã mở khoá', () {
    testWidgets('prestige đủ tier -> chọn được, persist, tick chuyển sang', (
      tester,
    ) async {
      await _pump(
        tester,
        prefs: {
          StorageKeys.prestigeTier: _f(_prestigeFrame).requiredPrestigeTier,
        },
      );

      await _tapRow(tester, _prestigeFrame);

      expect(ctrl.activeBoardFrameId.value, _prestigeFrame);
      expect(ctrl.activeBoardFrame.id, _prestigeFrame);
      expect(
        StorageService.to.getString(StorageKeys.activeBoardFrame),
        _prestigeFrame,
      );
      expect(_checkOn(_prestigeFrame), findsOneWidget);
      expect(
        find.byIcon(Icons.check_circle_rounded),
        findsOneWidget,
        reason: 'chỉ được đánh dấu đúng 1 khung',
      );
    });

    testWidgets('tier thiếu đúng 1 bậc vẫn khoá', (tester) async {
      await _pump(
        tester,
        prefs: {
          StorageKeys.prestigeTier: _f(_prestigeFrame).requiredPrestigeTier - 1,
        },
      );

      await _tapRow(tester, _prestigeFrame);

      expect(ctrl.activeBoardFrameId.value, kBoardFrames.first.id);
    });

    testWidgets('achievement đã đạt -> chọn được', (tester) async {
      await _pump(
        tester,
        prefs: {
          StorageKeys.unlockedAchievements: _f(_achFrame).requiredAchievementId,
        },
      );

      await _tapRow(tester, _achFrame);

      expect(ctrl.activeBoardFrameId.value, _achFrame);
    });

    testWidgets('treasure map đã xong -> chọn được', (tester) async {
      await _pump(tester, prefs: {StorageKeys.treasureMapCompleted: true});

      await _tapRow(tester, _treasureFrame);

      expect(ctrl.activeBoardFrameId.value, _treasureFrame);
    });

    testWidgets('đổi qua lại giữa hai khung đã mở', (tester) async {
      await _pump(
        tester,
        prefs: {
          StorageKeys.prestigeTier: _f(_prestigeFrame).requiredPrestigeTier,
        },
      );

      await _tapRow(tester, _prestigeFrame);
      await _tapRow(tester, kBoardFrames.first.id);

      expect(ctrl.activeBoardFrameId.value, kBoardFrames.first.id);
      expect(_checkOn(kBoardFrames.first.id), findsOneWidget);
    });
  });

  group('I73 — khung theo mùa hết hạn', () {
    testWidgets('hiển thị rơi về classic nhưng storage GIỮ id đã chọn', (
      tester,
    ) async {
      // Đây là quyết định thiết kế của I73, không phải bug: ghi đè storage lúc
      // này thì mùa sau khung mở lại mà người chơi đã mất lựa chọn.
      final seasonal = _outOfSeasonFrame.id;
      await _pump(tester, prefs: {StorageKeys.activeBoardFrame: seasonal});

      expect(
        ctrl.activeBoardFrame.id,
        kBoardFrames.first.id,
        reason: 'khung đang khoá không được render',
      );
      expect(_checkOn(kBoardFrames.first.id), findsOneWidget);
      expect(_checkOn(seasonal), findsNothing);

      // Bất biến thật sự của I73, và là thứ duy nhất quyết định mùa sau người
      // chơi có được nhận lại lựa chọn cũ hay không.
      expect(
        StorageService.to.getString(StorageKeys.activeBoardFrame),
        seasonal,
        reason: 'mở màn hình này KHÔNG được ghi đè id chỉ đang tạm khoá',
      );
      // `_load()` hạ Rx xuống classic ngay lúc boot (game_controller.dart:1337)
      // nên đừng kỳ vọng Rx còn giữ id mùa — chỉ ĐĨA giữ.
      expect(ctrl.activeBoardFrameId.value, kBoardFrames.first.id);
    });
  });

  group('save hỏng', () {
    testWidgets('id không tồn tại -> về classic, màn hình vẫn dựng', (
      tester,
    ) async {
      await _pump(
        tester,
        prefs: {StorageKeys.activeBoardFrame: 'khung_da_bi_go'},
      );

      expect(ctrl.activeBoardFrameId.value, kBoardFrames.first.id);
      expect(_checkOn(kBoardFrames.first.id), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Đĩa vẫn giữ id chết. Vô hại: `_load()` ánh xạ nó về classic ở MỌI lần
      // boot, nên không có trạng thái sai nào tồn tại được.
      expect(
        StorageService.to.getString(StorageKeys.activeBoardFrame),
        'khung_da_bi_go',
      );
    });

    testWidgets('revalidateActiveBoardFrame: gọi lại không đổi gì thêm', (
      tester,
    ) async {
      // Ghi lại đúng như đo được: `_load()` đã hạ mọi id lạ/khoá xuống classic
      // trước khi `build` chạy, nên nhánh ghi đĩa của
      // `revalidateActiveBoardFrame()` không với tới được trong cùng một tiến
      // trình. Nó là guard phòng thủ, không phải đường chạy thật — ai định
      // "dọn" nó thì đọc [[I73]] trước, và ai sửa `_load()` để giữ nguyên id
      // lạ thì test này chuyển thành đỏ đúng lúc cần.
      await _pump(
        tester,
        prefs: {StorageKeys.activeBoardFrame: 'khung_da_bi_go'},
      );
      final before = StorageService.to.getString(StorageKeys.activeBoardFrame);

      ctrl.revalidateActiveBoardFrame();

      expect(ctrl.activeBoardFrameId.value, kBoardFrames.first.id);
      expect(StorageService.to.getString(StorageKeys.activeBoardFrame), before);
    });

    testWidgets('id hợp lệ nhưng vượt quyền -> render classic, không ném', (
      tester,
    ) async {
      // Sửa tay storage để trỏ khung prestige trong khi tier = 0.
      await _pump(
        tester,
        prefs: {StorageKeys.activeBoardFrame: _prestigeFrame},
      );

      expect(ctrl.activeBoardFrame.id, kBoardFrames.first.id);
      expect(_checkOn(_prestigeFrame), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
