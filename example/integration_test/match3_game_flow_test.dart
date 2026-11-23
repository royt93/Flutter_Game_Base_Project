import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';
import 'package:roy_casual_kit_example/main.dart' as app;
import 'package:roy_casual_kit_example/screens/match3_lite_screen.dart';

Future<void> _pumpFor(WidgetTester tester, int ms) async {
  for (var spent = 0; spent < ms; spent += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openMatch3(WidgetTester tester) async {
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .push(MaterialPageRoute<void>(builder: (_) => const Match3LiteScreen()));
  await _pumpFor(tester, 800);
  expect(find.byType(Match3LiteScreen), findsOneWidget);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(finder);
}

Finder _menuButton(String label) => find
    .descendant(
      of: find.byType(PauseOverlay),
      matching: find.ancestor(
        of: find.text(label),
        matching: find.byType(CommonButton),
      ),
    )
    .first;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Match-3 flow on device: tutorial, booster, pause, resume, restart',
    (tester) async {
      await app.app();
      await tester.pump(const Duration(seconds: 2));

      // Independent of whatever energy this device holds from earlier runs.
      // The screen registers EnergyService itself on open; do it first here
      // with the same settings so infinite lives can be granted up front.
      final EnergyService energy =
          EnergyService.maybe ??
          Get.put<EnergyService>(EnergyService(maxEnergy: 5), permanent: true);
      await energy.grantInfiniteLives(const Duration(hours: 1));
      // A genuine first-time player: forget the tutorial and any save.
      await StorageService.to.remove(StorageKeys.onboardingSeenV1);
      await StorageService.to.remove('match3_lite_save_v2');
      Get.delete<OnboardingCoordinatorService>(force: true);
      Get.put(OnboardingCoordinatorService(), permanent: true);

      await _openMatch3(tester);
      final session = Get.find<GameSessionController>();
      expect(session.snapshot.value.phase, GameSessionPhase.ready);

      // Start: the tutorial must cover the board for a first-time player.
      final start = find.byWidgetPredicate(
        (w) => w is CommonButton && w.label == 'match3_start'.tr,
      );
      await tester.ensureVisible(start);
      await tester.tap(start);
      await _pumpFor(tester, 600);
      expect(session.snapshot.value.phase, GameSessionPhase.playing);
      expect(find.byType(SpotlightOverlay), findsOneWidget);
      for (var step = 0; step < 3; step++) {
        final label = step < 2
            ? 'match3_tutorial_next'.tr
            : 'match3_tutorial_done'.tr;
        await tester.tap(find.text(label).first);
        await _pumpFor(tester, 400);
      }
      expect(find.byType(SpotlightOverlay), findsNothing);

      // Booster: armed bomb clears tiles, costs no move, spends one booster.
      final inventory = Get.find<InventoryService>();
      final bombsBefore = inventory.snapshot.value.quantityOf('booster_bomb');
      expect(bombsBefore, greaterThan(0));
      await _tapKey(tester, 'boosterSlotTap_booster_bomb');
      await _pumpFor(tester, 200);
      await _tapKey(tester, 'match3_tile_14');
      await _pumpFor(tester, 2500);
      expect(
        inventory.snapshot.value.quantityOf('booster_bomb'),
        bombsBefore - 1,
      );
      expect(
        find.text('match3_moves'.trParams({'moves': '20'})),
        findsOneWidget,
        reason: 'a booster must not cost a move',
      );

      // Pause: menu opens, board is locked, resume returns to playing.
      await _tapKey(tester, 'match3_pause');
      await _pumpFor(tester, 800);
      expect(session.snapshot.value.phase, GameSessionPhase.paused);
      expect(find.text('pause_resume'.tr), findsWidgets);
      await tester.tap(_menuButton('pause_resume'.tr));
      await _pumpFor(tester, 800);
      expect(session.snapshot.value.phase, GameSessionPhase.playing);

      // Restart from the pause menu: fresh run, session playing again.
      await _tapKey(tester, 'match3_pause');
      await _pumpFor(tester, 800);
      await tester.tap(_menuButton('pause_restart'.tr));
      await _pumpFor(tester, 1000);
      expect(session.snapshot.value.phase, GameSessionPhase.playing);
      expect(
        find.text('match3_moves'.trParams({'moves': '20'})),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
