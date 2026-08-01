import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/core/runtime_flags.dart';
import 'package:pop_star_blast/logic/backup_code.dart';
import 'package:pop_star_blast/main.dart' as app;
import 'package:pop_star_blast/presentation/screens/home_screen.dart';
import 'package:pop_star_blast/presentation/screens/settings_screen.dart';
import 'package:pop_star_blast/presentation/widgets/neon_dialog.dart';
import 'package:get/get.dart';

Future<void> _pumpBounded(
  WidgetTester tester, {
  int times = 6,
  Duration step = const Duration(milliseconds: 300),
}) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(step);
  }
}

Future<void> _dismissDailyRewardIfShown(WidgetTester tester) async {
  if (isE2eTest) return;
  // Daily reward is scheduled after startup; do not sample once and continue
  // while a modal may still be mounting over the home screen.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 300));
    final dialog = find.byType(Dialog);
    if (dialog.evaluate().isEmpty) continue;

    await tester.pump(const Duration(milliseconds: 400));
    final claim = find.descendant(
      of: dialog,
      matching: find.text('daily_claim'.tr),
    );
    final action = find.descendant(
      of: dialog,
      matching: find.byType(NeonDialogButton),
    );
    if (claim.evaluate().isNotEmpty) {
      await tester.tap(claim);
    } else if (action.evaluate().isNotEmpty) {
      await tester.tap(action.last);
    } else {
      continue;
    }
    await _pumpBounded(tester);
    return;
  }
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu_rounded).first);
  await _pumpBounded(tester, times: 2);
  await tester.tap(find.text('settings'.tr));
  await _pumpBounded(tester, times: 3);
  expect(find.byType(SettingsScreen), findsOneWidget);
}

Future<void> _scrollSettingsTo(WidgetTester tester, Finder target) async {
  final list = find.byType(ListView);
  for (var i = 0; i < 4 && target.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -250));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('backup export/import restores data after app restart', (
    tester,
  ) async {
    debugPrint('E2E: boot');
    await app.app(withAudio: false);
    await _pumpBounded(tester, times: 15);
    await _dismissDailyRewardIfShown(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    debugPrint('E2E: home ready');

    await StorageService.to.setInt(StorageKeys.coins, 321);
    await StorageService.to.setString(StorageKeys.playerName, 'Integration');
    final expected = StorageService.to.exportAll();
    final expectedCode = await encodeSecureBackupCode(expected);

    await _openSettings(tester);
    debugPrint('E2E: settings ready');
    final exportLabel = find.text('backup_export'.tr);
    await _scrollSettingsTo(tester, exportLabel);
    final exportTile = find.ancestor(
      of: exportLabel,
      matching: find.byType(ListTile),
    );
    await tester.ensureVisible(exportTile);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(exportTile);
    await _pumpBounded(tester, times: 3);
    final exported = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data!;
    expect(exported, startsWith(secureBackupCodePrefix));
    expect(await decodeSecureBackupCode(exported), expected);
    expect(exported, isNot(expectedCode));
    await tester.tap(find.text('cancel'.tr).last);
    await _pumpBounded(tester, times: 2);

    final importLabel = find.text('backup_import'.tr);
    await _scrollSettingsTo(tester, importLabel);
    final importTile = find.ancestor(
      of: importLabel,
      matching: find.byType(ListTile),
    );
    await tester.ensureVisible(importTile);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(importTile);
    debugPrint('E2E: import dialog ready');
    await _pumpBounded(tester, times: 3);
    await tester.enterText(find.byType(TextField), exported);
    if (tester.testTextInput.isRegistered) {
      tester.testTextInput.hide();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(NeonDialogButton).last);
    await tester.pump();
    await _pumpBounded(tester, times: 4);
    expect(find.text('backup_import_confirm_title'.tr), findsOneWidget);
    debugPrint('E2E: confirmation ready');

    await tester.tap(find.byType(NeonDialogButton).last);
    await _pumpBounded(tester, times: 15);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(StorageService.to.getInt(StorageKeys.coins), 321);
    expect(StorageService.to.getString(StorageKeys.playerName), 'Integration');
    expect(tester.takeException(), isNull);
    debugPrint('E2E: restore verified');

    Get.reset();
  });
}
