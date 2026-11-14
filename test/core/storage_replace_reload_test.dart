import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/achievement_service.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/energy_service.dart';
import 'package:roy_casual_kit/core/inventory_service.dart';
import 'package:roy_casual_kit/core/local_scoreboard_service.dart';
import 'package:roy_casual_kit/core/player_progression_service.dart';
import 'package:roy_casual_kit/core/save_slot_manager.dart';
import 'package:roy_casual_kit/core/reward_transaction_pipeline.dart';
import 'package:roy_casual_kit/core/onboarding_coordinator_service.dart';
import 'package:roy_casual_kit/core/offline_outbox_service.dart';
import 'package:roy_casual_kit/core/purchase_ledger_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BUG-117: after `StorageService.eraseAll()` / `importAll()` a stateful
/// service must not write its old in-memory copy back over the new data.

/// A platform-level `SharedPreferences` whose `setString` for one key can be
/// parked, so a write is genuinely in flight inside `StorageService`'s write
/// guard (BUG-118). Parking at the platform layer, not by overriding
/// `StorageService.setString`, is what exercises `_guardedWrite`.
class _ParkablePrefs implements SharedPreferences {
  _ParkablePrefs(this.delegate);
  final SharedPreferences delegate;
  Completer<void>? release;
  bool parked = false;
  String? parkKey;

  @override
  Future<bool> setString(String key, String value) async {
    final r = release;
    if (r != null && key == parkKey) {
      parked = true;
      await r.future;
    }
    return delegate.setString(key, value);
  }

  @override
  Set<String> getKeys() => delegate.getKeys();
  @override
  Object? get(String key) => delegate.get(key);
  @override
  Future<bool> remove(String key) => delegate.remove(key);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  test(
    'SaveSlotManager: erase empties the slot list; a new slot is alone',
    () async {
      final m = SaveSlotManager();
      m.createSlot('A');
      await m.debugPendingSaves;
      expect(m.listSlots(), hasLength(1));

      await storage.eraseAll();
      expect(m.listSlots(), isEmpty);

      m.createSlot('B');
      await m.debugPendingSaves;
      expect(SaveSlotManager().listSlots().map((x) => x.displayName), ['B']);
    },
  );

  test('OfflineOutboxService: erase clears queued items so a drain cannot '
      're-send erased data', () async {
    final sent = <String>[];
    final outbox = OfflineOutboxService(
      storage: storage,
      uploader: (payload, key) async {
        sent.add(key);
        return const SyncAck();
      },
    )..onInit();
    outbox.enqueue(idempotencyKey: 'secret', payload: const {'v': 1});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(outbox.items, hasLength(1));

    await storage.eraseAll();
    expect(outbox.items, isEmpty);

    await outbox.drain();
    expect(sent, isEmpty);
  });

  test('RewardTransactionPipeline: erase clears the audit trail', () async {
    final wallet = EconomyWallet(storage: storage);
    final pipeline = RewardTransactionPipeline(wallet: wallet)..onInit();
    await pipeline.grant(
      source: RewardSource.other,
      transactionId: 'r1',
      lines: const [RewardLine(currency: 'coin', amount: 5)],
    );
    expect(pipeline.auditTrail, hasLength(1));

    await storage.eraseAll();
    expect(pipeline.auditTrail, isEmpty);
  });

  test(
    'OnboardingCoordinatorService: erase makes a seen flow unseen again',
    () async {
      final o = OnboardingCoordinatorService();
      o.markFlowSeen('tutorial');
      await o.debugPendingSaves;
      expect(o.isFlowSeen('tutorial'), isTrue);

      await storage.eraseAll();
      expect(o.isFlowSeen('tutorial'), isFalse);
    },
  );

  group(
    'prefix replaces only reach services whose key is under the prefix',
    () {
      test(
        'deleteSlot keeps SaveSlotManager metadata (its key is not under the '
        'slot prefix)',
        () async {
          final m = SaveSlotManager();
          final a = m.createSlot('A');
          final b = m.createSlot('B');
          await m.debugPendingSaves;

          await m.deleteSlot(b.id);

          expect(m.listSlots().map((s) => s.id), [a.id]);
        },
      );

      test(
        'removeAllWithPrefix on ANOTHER slot does not reset a ledger',
        () async {
          final m = SaveSlotManager();
          final s1 = m.createSlot('One');
          final s2 = m.createSlot('Two');
          final ledger = PurchaseLedgerService(
            storageKey: m.keyFor(s1.id, 'ledger'),
          );
          ledger.grantConsumable('gems', 7);
          await ledger.debugPendingSaves;

          await storage.removeAllWithPrefix('slot_${s2.id}_');

          expect(ledger.balanceOf('gems'), 7);
        },
      );

      test(
        'removeAllWithPrefix on the ledger\'s OWN slot drops its cache',
        () async {
          final m = SaveSlotManager();
          final s1 = m.createSlot('One');
          final ledger = PurchaseLedgerService(
            storageKey: m.keyFor(s1.id, 'ledger'),
          );
          ledger.grantConsumable('gems', 7);
          await ledger.debugPendingSaves;

          await storage.removeAllWithPrefix('slot_${s1.id}_');

          expect(ledger.balanceOf('gems'), 0);
        },
      );

      test(
        'importWithPrefix restoring a slot reloads a ledger under it',
        () async {
          final m = SaveSlotManager();
          final s1 = m.createSlot('One');
          final key = m.keyFor(s1.id, 'ledger');
          final ledger = PurchaseLedgerService(storageKey: key);
          ledger.grantConsumable('gems', 7);
          await ledger.debugPendingSaves;
          final backup = storage.exportWithPrefix('slot_${s1.id}_');
          ledger.grantConsumable('gems', 100);
          await ledger.debugPendingSaves;

          await storage.importWithPrefix('slot_${s1.id}_', backup);

          expect(ledger.balanceOf('gems'), 7);
        },
      );
    },
  );

  test('BUG-118: an erase issued while a wallet write is in flight is not '
      'overtaken by that write', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = _ParkablePrefs(await SharedPreferences.getInstance());
    final parkedStorage = StorageService(prefs);
    final wallet = EconomyWallet(storage: parkedStorage);
    await wallet.earn(currency: 'coin', amount: 10, transactionId: 'seed');

    prefs
      ..parkKey = StorageKeys.economyWalletV1
      ..release = Completer<void>();
    final pending = wallet.earn(
      currency: 'coin',
      amount: 5,
      transactionId: 'late',
    );
    while (!prefs.parked) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    final erase = parkedStorage.eraseAll();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final release = prefs.release!;
    prefs.release = null;
    release.complete();
    await Future.wait([pending, erase]);

    // The erase was issued after the earn started: the final state is erased.
    expect(parkedStorage.getString(StorageKeys.economyWalletV1), isNull);
    expect(EconomyWallet(storage: parkedStorage).balanceOf('coin'), 0);
  });
}
