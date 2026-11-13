import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/achievement_service.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/energy_service.dart';
import 'package:roy_casual_kit/core/inventory_service.dart';
import 'package:roy_casual_kit/core/local_scoreboard_service.dart';
import 'package:roy_casual_kit/core/player_progression_service.dart';
import 'package:roy_casual_kit/core/purchase_ledger_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BUG-117: after `StorageService.eraseAll()` / `importAll()` a stateful
/// service must not write its old in-memory copy back over the new data.
void main() {
  tearDown(Get.reset);

  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    Get.put(storage, permanent: true);
  });

  test(
    'PurchaseLedgerService: restore then grant continues from the backup',
    () async {
      final ledger = PurchaseLedgerService();
      ledger.grantConsumable('gems', 10);
      await ledger.debugPendingSaves;
      final backup = storage.exportAll();
      ledger.grantConsumable('gems', 500);
      await ledger.debugPendingSaves;

      await storage.importAll(backup);
      expect(ledger.balanceOf('gems'), 10);

      ledger.grantConsumable('gems', 1);
      await ledger.debugPendingSaves;
      expect(PurchaseLedgerService().balanceOf('gems'), 11);
    },
  );

  test('PurchaseLedgerService: erase then grant does not resurrect', () async {
    final ledger = PurchaseLedgerService();
    ledger.grantConsumable('gems', 510);
    await ledger.debugPendingSaves;

    await storage.eraseAll();
    ledger.grantConsumable('coins', 1);
    await ledger.debugPendingSaves;

    final fresh = PurchaseLedgerService();
    expect(fresh.balanceOf('gems'), 0);
    expect(fresh.balanceOf('coins'), 1);
  });

  test(
    'EnergyService: erase resets energy to full instead of keeping 3',
    () async {
      final energy = EnergyService(maxEnergy: 5);
      expect(energy.consumeEnergy(2), isTrue);
      await energy.debugPendingSaves;
      expect(energy.currentEnergy, 3);

      await storage.eraseAll();

      expect(energy.currentEnergy, 5);
    },
  );

  test(
    'InventoryService: erase empties the bag and a new grant is alone',
    () async {
      const catalog = {'sword': ItemDefinition(id: 'sword', maxStack: 9)};
      final inv = InventoryService(storage: storage, itemCatalog: catalog);
      await inv.grant(
        lines: const [InventoryLine(itemId: 'sword', quantity: 2)],
        transactionId: 'g1',
      );
      await storage.eraseAll();

      await inv.grant(
        lines: const [InventoryLine(itemId: 'sword', quantity: 1)],
        transactionId: 'g2',
      );
      final fresh = InventoryService(storage: storage, itemCatalog: catalog);
      expect(
        fresh.snapshot.value.slots.fold<int>(0, (a, s) => a + s.quantity),
        1,
      );
    },
  );

  test('PlayerProgressionService: erase resets XP; the next grant starts '
      'from zero', () async {
    const curve = [
      LevelDefinition(level: 1, xpToNext: 100),
      LevelDefinition(level: 2, xpToNext: 200),
      LevelDefinition(level: 3, xpToNext: 0),
    ];
    final p = PlayerProgressionService(storage: storage, levelCurve: curve);
    await p.grantXp(amount: 50, transactionId: 'x1');
    expect(p.snapshot.value.xpIntoLevel, 50);

    await storage.eraseAll();
    expect(p.snapshot.value.xpIntoLevel, 0);

    await p.grantXp(amount: 5, transactionId: 'x2');
    final fresh = PlayerProgressionService(storage: storage, levelCurve: curve);
    expect(fresh.snapshot.value.xpIntoLevel, 5);
  });

  test('LocalScoreboardService: erase clears scores', () async {
    final board = LocalScoreboardService();
    board.submitScore('A', 100);
    await board.debugPendingSaves;

    await storage.eraseAll();
    board.submitScore('B', 5);
    await board.debugPendingSaves;

    final names = LocalScoreboardService().topN(10).map((e) => e.name);
    expect(names, ['B']);
  });

  test('AchievementService: erase clears progress', () async {
    final a = AchievementService()..register('win', 10);
    a.incrementProgress('win', 4);
    await a.debugPendingSaves;

    await storage.eraseAll();
    expect(a.progressOf('win'), 0);
  });

  test('wallet restore still works through the same signal (sanity)', () async {
    final w = EconomyWallet(storage: storage);
    await w.earn(currency: 'coin', amount: 9, transactionId: 't');
    await storage.eraseAll();
    expect(w.balanceOf('coin'), 0);
  });
}
