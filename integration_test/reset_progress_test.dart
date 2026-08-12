import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/main.dart' as app;
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/home_screen.dart';
import 'package:pop_star_blast/presentation/screens/settings_screen.dart';

/// Integration cho [X19] — **Reset Progress phải xoá sạch, qua đúng UI thật**.
///
/// Unit test gọi thẳng `resetProgress()`. Nhưng đường thật đi qua: nút trong
/// Settings → `NeonDialog` xác nhận → `Get.find<GameController>()`. Nếu dialog
/// nối nhầm nút, hoặc `Get.find` trả instance khác instance đang giữ state,
/// thì reset "chạy" mà không xoá gì — unit test không thấy được.
///
/// Chạy: `flutter test integration_test/reset_progress_test.dart -d <device>`
Future<void> _pumpBounded(
  WidgetTester tester, {
  int times = 12,
  Duration step = const Duration(milliseconds: 300),
}) async {
  // Không pumpAndSettle: StarMascot chạy animation lặp vô hạn.
  for (var i = 0; i < times; i++) {
    await tester.pump(step);
  }
}

Future<void> _dismissDialogIfShown(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 300));
    final dialog = find.byType(Dialog);
    if (dialog.evaluate().isEmpty) continue;
    final claim = find.descendant(
      of: dialog,
      matching: find.text('daily_claim'.tr),
    );
    if (claim.evaluate().isNotEmpty) {
      await tester.tap(claim.first);
      await _pumpBounded(tester, times: 4);
      return;
    }
  }
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu_rounded).first);
  await _pumpBounded(tester, times: 3);
  await tester.tap(find.text('settings'.tr));
  await _pumpBounded(tester, times: 4);
  expect(find.byType(SettingsScreen), findsOneWidget);
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  final list = find.byType(ListView);
  for (var i = 0; i < 8 && target.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -280));
    await tester.pump(const Duration(milliseconds: 80));
  }
  await tester.ensureVisible(target.first);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Reset Progress qua UI xoá tiến độ nhưng giữ cài đặt', (
    tester,
  ) async {
    await app.app(withAudio: false);
    await _pumpBounded(tester, times: 15);
    await _dismissDialogIfShown(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    final store = StorageService.to;
    final ctrl = Get.find<GameController>();

    // Gieo tiến độ, gồm ĐÚNG những key mà bản cũ của X19 bỏ sót.
    await store.setInt(StorageKeys.coins, 4242);
    await store.setInt(StorageKeys.unlockedLevel, 37);
    await store.setInt(StorageKeys.starDustCount, 150);
    await store.setInt(StorageKeys.starSeedCount, 4);
    await store.setInt(StorageKeys.streakFreezeCount, 2);
    await store.setInt(StorageKeys.bossRushBestStreak, 9);
    await store.setInt(StorageKeys.highScore(3), 8888);
    await store.setInt(StorageKeys.star(3), 3);
    await store.setInt(StorageKeys.remixBest(7), 555);
    // Cài đặt + trạng thái đã-xem-rồi: phải SỐNG SÓT.
    await store.setBool(StorageKeys.hasSeenFtue, true);
    await store.setString(StorageKeys.playerName, 'RoyIntegration');
    await store.setBool(StorageKeys.reduceMotion, true);
    await store.flush();

    await _openSettings(tester);
    final resetLabel = find.text('reset_progress'.tr);
    await _scrollTo(tester, resetLabel);
    await tester.tap(resetLabel.last);
    await _pumpBounded(tester, times: 4);

    // Dialog xác nhận: bấm 'confirm', không phải 'cancel'.
    expect(find.text('reset_confirm_msg'.tr), findsOneWidget);
    await tester.tap(find.text('confirm'.tr).last);
    await _pumpBounded(tester, times: 10);

    // Tiến độ: sạch.
    expect(store.getInt(StorageKeys.coins), 0);
    expect(store.getInt(StorageKeys.unlockedLevel, def: 1), 1);
    expect(store.getInt(StorageKeys.starDustCount), 0);
    expect(store.getInt(StorageKeys.starSeedCount), 0);
    expect(store.getInt(StorageKeys.streakFreezeCount), 0);
    expect(store.getInt(StorageKeys.bossRushBestStreak), 0);
    expect(store.getInt(StorageKeys.highScore(3)), 0);
    expect(store.getInt(StorageKeys.star(3)), 0);
    expect(
      store.getInt(StorageKeys.remixBest(7)),
      0,
      reason: 'remixBest từng bị bỏ sót vì nằm ngoài vòng lặp per-level cũ',
    );
    expect(ctrl.coins.value, 0);
    expect(ctrl.unlockedLevel.value, 1);

    // Cài đặt + UX: giữ nguyên.
    expect(store.getString(StorageKeys.playerName), 'RoyIntegration');
    expect(store.getBool(StorageKeys.hasSeenFtue), isTrue);
    expect(store.getBool(StorageKeys.reduceMotion), isTrue);

    expect(tester.takeException(), isNull);
  });

  testWidgets('bấm Huỷ trong dialog thì KHÔNG xoá gì', (tester) async {
    await app.app(withAudio: false);
    await _pumpBounded(tester, times: 15);
    await _dismissDialogIfShown(tester);

    final store = StorageService.to;
    await store.setInt(StorageKeys.coins, 999);
    await store.flush();

    await _openSettings(tester);
    final resetLabel = find.text('reset_progress'.tr);
    await _scrollTo(tester, resetLabel);
    await tester.tap(resetLabel.last);
    await _pumpBounded(tester, times: 4);

    await tester.tap(find.text('cancel'.tr).last);
    await _pumpBounded(tester, times: 6);

    expect(
      store.getInt(StorageKeys.coins),
      999,
      reason: 'Huỷ mà vẫn xoá là mất trắng tiến độ của người chơi',
    );
  });
}
