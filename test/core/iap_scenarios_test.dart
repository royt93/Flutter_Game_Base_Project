import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/economy_wallet.dart';
import 'package:roy_casual_kit/core/purchase_ledger_service.dart';
import 'package:roy_casual_kit/core/purchase_seam.dart';
import 'package:roy_casual_kit/core/reward_transaction_pipeline.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/counter_limit.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/conditioned_providers.dart';

/// ENH-126: purchase scenarios across `PurchaseSeam` + `RewardTransactionPipeline`
/// (receipt-level idempotency) + `EconomyWallet` + `PurchaseLedgerService`.
///
/// Out of scope, on purpose: a real store (Google Play / App Store) and ads.
/// The kit has no store code and its ad feature was removed in 0.8.0, so these
/// tests prove the contract of the seam and the local books, not the store.
///
/// "Kill" is simulated by [_KillableStorage]: the write that would have run at
/// that instant never completes, the instance is dropped, and a new one is
/// built over the same `SharedPreferences`. The hung write is never released,
/// so the dead process cannot write after its death.
class _KillableStorage extends StorageService {
  _KillableStorage(super.prefs);

  String? killKey;
  int killOnWrite = 1;
  int _writes = 0;
  final reached = Completer<void>();

  @override
  Future<void> setString(String key, String value) async {
    if (key == killKey && ++_writes == killOnWrite) {
      reached.complete();
      await Completer<void>().future; // the process is gone
    }
    return super.setString(key, value);
  }
}

/// A store-side model with a controllable [NetworkScript] for `buy`.
class _ScriptedPurchaseSeam implements PurchaseSeam {
  _ScriptedPurchaseSeam({NetworkScript? script, this.chargeEvenIfBuyThrows = false})
    : script = script ?? NetworkScript();

  final NetworkScript script;

  /// A confirmation lost on the way back: the store charged, the app saw an error.
  final bool chargeEvenIfBuyThrows;

  /// Set to make [buy] report a plain failure (user cancelled, declined).
  bool declines = false;

  /// What the STORE knows: receiptId -> productId. Survives an app kill.
  final Map<String, String> storeReceipts = {};
  final Set<String> _owned = {};
  int buyCalls = 0;
  int _nextReceipt = 1;

  /// Adapter-owned detail the seam interface leaves to the adapter: the
  /// receipts the store still lists as unfinished after [restorePurchases].
  final List<(String receiptId, String productId)> unfinished = [];

  @override
  Future<bool> buy(String productId) async {
    buyCalls++;
    final receipt = 'rcpt_${_nextReceipt++}';
    try {
      await script.apply('buy $productId');
    } catch (_) {
      if (chargeEvenIfBuyThrows) storeReceipts[receipt] = productId;
      rethrow;
    }
    if (declines) return false;
    storeReceipts[receipt] = productId;
    _owned.add(productId);
    lastReceipt = receipt;
    return true;
  }

  String? lastReceipt;

  @override
  Future<void> restorePurchases() async {
    unfinished
      ..clear()
      ..addAll([for (final e in storeReceipts.entries) (e.key, e.value)]);
    _owned.addAll(storeReceipts.values);
  }

  @override
  bool isOwned(String productId) => _owned.contains(productId);

  /// A fresh process: the store keeps its receipts, the app forgets its memory.
  void restartApp() {
    _owned.clear();
    unfinished.clear();
    lastReceipt = null;
  }
}

const _gems = {'gem_pack': [RewardLine(currency: 'gem', amount: 100)]};

({EconomyWallet wallet, RewardTransactionPipeline pipeline}) _boot(
  StorageService storage,
) {
  final wallet = EconomyWallet(storage: storage)..onInit();
  final pipeline = RewardTransactionPipeline(wallet: wallet)..onInit();
  return (wallet: wallet, pipeline: pipeline);
}

/// The consumer-side recovery loop the kit leaves to the app: restore, then
/// deliver every receipt the store still lists through the idempotent pipeline.
Future<void> _recover(
  _ScriptedPurchaseSeam seam,
  RewardTransactionPipeline pipeline,
) async {
  await seam.restorePurchases();
  for (final (receiptId, productId) in List.of(seam.unfinished)) {
    await pipeline.grantFromPurchase(receiptId: receiptId, lines: _gems[productId]!);
  }
}

Future<SdkResult<RewardTransactionRecord>> _buyAndGrant(
  _ScriptedPurchaseSeam seam,
  RewardTransactionPipeline pipeline,
) async {
  final ok = await seam.buy('gem_pack');
  if (!ok) {
    return const SdkFailure(kind: SdkErrorKind.unknown, message: 'declined');
  }
  return pipeline.grantFromPurchase(
    receiptId: seam.lastReceipt!,
    lines: _gems['gem_pack']!,
  );
}

void main() {
  late SharedPreferences prefs;
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = StorageService(prefs);
  });
  tearDown(() {
    storage.onClose();
    Get.reset();
  });

  group('a purchase that does not complete grants nothing', () {
    test('declined or cancelled: no currency, no audit record', () async {
      final seam = _ScriptedPurchaseSeam()..declines = true;
      final boot = _boot(storage);

      final result = await _buyAndGrant(seam, boot.pipeline);

      expect(result.isSuccess, isFalse);
      expect(boot.wallet.balanceOf('gem'), 0);
      expect(boot.pipeline.auditTrail, isEmpty);
      expect(seam.isOwned('gem_pack'), isFalse);
    });

    test('buy throws (no network): nothing granted and nothing owned', () async {
      final seam = _ScriptedPurchaseSeam(script: NetworkScript([NetStep.fail]));
      final boot = _boot(storage);

      await expectLater(_buyAndGrant(seam, boot.pipeline), throwsA(isA<TransportError>()));

      expect(boot.wallet.balanceOf('gem'), 0);
      expect(boot.pipeline.auditTrail, isEmpty);
      expect(seam.isOwned('gem_pack'), isFalse);
    });

    test('pending: nothing is granted or owned until the store confirms, then exactly once', () async {
      final seam = _ScriptedPurchaseSeam(script: NetworkScript([NetStep.slow]));
      final boot = _boot(storage);

      final pending = _buyAndGrant(seam, boot.pipeline);
      await pumpEventQueue();
      expect(seam.script.parked, hasLength(1));
      expect(boot.wallet.balanceOf('gem'), 0, reason: 'still pending');
      expect(seam.isOwned('gem_pack'), isFalse);

      seam.script.release();
      expect((await pending).isSuccess, isTrue);
      expect(boot.wallet.balanceOf('gem'), 100);
      expect(seam.isOwned('gem_pack'), isTrue);
    });
  });

  group('the store redelivers a receipt', () {
    test('the same receipt twice, one after the other: credited once, same record back', () async {
      final boot = _boot(storage);
      const lines = [RewardLine(currency: 'gem', amount: 100)];

      final first = await boot.pipeline.grantFromPurchase(receiptId: 'r1', lines: lines);
      final again = await boot.pipeline.grantFromPurchase(receiptId: 'r1', lines: lines);

      expect(boot.wallet.balanceOf('gem'), 100);
      expect((first as SdkSuccess<RewardTransactionRecord>).value.transactionId, 'purchase:r1');
      expect((again as SdkSuccess<RewardTransactionRecord>).value.transactionId, 'purchase:r1');
      expect(boot.pipeline.auditTrail, hasLength(1));
    });

    test('a redelivered receipt does not announce a second grant', () async {
      final boot = _boot(storage);
      const lines = [RewardLine(currency: 'gem', amount: 100)];
      final announced = <String>[];
      boot.pipeline.onGranted.listen((r) {
        if (r != null) announced.add(r.transactionId);
      });

      await boot.pipeline.grantFromPurchase(receiptId: 'r1', lines: lines);
      await boot.pipeline.grantFromPurchase(receiptId: 'r1', lines: lines);
      await pumpEventQueue();

      expect(announced, ['purchase:r1'], reason: 'thank-you toasts and analytics must fire once per purchase');
    });

    test('the same receipt delivered concurrently: credited once', () async {
      final boot = _boot(storage);
      const lines = [RewardLine(currency: 'gem', amount: 100)];

      await Future.wait([
        for (var i = 0; i < 5; i++) boot.pipeline.grantFromPurchase(receiptId: 'r1', lines: lines),
      ]);

      expect(boot.wallet.balanceOf('gem'), 100);
      expect(boot.pipeline.auditTrail, hasLength(1));
    });

    test('restore on every launch without ever finishing the receipt: still credited once', () async {
      final seam = _ScriptedPurchaseSeam();
      final boot = _boot(storage);
      await _buyAndGrant(seam, boot.pipeline);

      for (var launch = 0; launch < 3; launch++) {
        seam.restartApp();
        await _recover(seam, boot.pipeline);
      }

      expect(boot.wallet.balanceOf('gem'), 100);
    });

    test('two DIFFERENT receipts are two purchases and both credit', () async {
      final boot = _boot(storage);
      const lines = [RewardLine(currency: 'gem', amount: 100)];

      await boot.pipeline.grantFromPurchase(receiptId: 'r1', lines: lines);
      await boot.pipeline.grantFromPurchase(receiptId: 'r2', lines: lines);

      expect(boot.wallet.balanceOf('gem'), 200);
    });
  });

  group('the app is killed around the grant', () {
    test('kill after the store charged, before the app granted anything: restore credits once', () async {
      final seam = _ScriptedPurchaseSeam();
      await seam.buy('gem_pack'); // charged; the app dies before granting
      seam.restartApp();

      final boot = _boot(StorageService(prefs));
      expect(boot.wallet.balanceOf('gem'), 0);

      await _recover(seam, boot.pipeline);
      expect(boot.wallet.balanceOf('gem'), 100);

      await _recover(seam, boot.pipeline);
      expect(boot.wallet.balanceOf('gem'), 100, reason: 'restore twice must not credit twice');
    });

    test('kill after the audit record was saved, before the wallet moved: resume credits once', () async {
      final doomed = _KillableStorage(prefs)
        ..killKey = StorageKeys.economyWalletV1;
      final first = _boot(doomed);
      unawaited(first.pipeline.grantFromPurchase(
        receiptId: 'r1',
        lines: const [RewardLine(currency: 'gem', amount: 100)],
      ));
      await doomed.reached.future;

      final afterKill = _boot(StorageService(prefs));
      expect(afterKill.pipeline.auditTrail.single.status, RewardTransactionStatus.pending);
      expect(afterKill.wallet.balanceOf('gem'), 0);

      await afterKill.pipeline.resumePending();
      expect(afterKill.wallet.balanceOf('gem'), 100);
      expect(afterKill.pipeline.auditTrail.single.status, RewardTransactionStatus.committed);
    });

    test('kill after the wallet was credited, before the commit was saved: resume does NOT credit again', () async {
      final doomed = _KillableStorage(prefs)
        ..killKey = StorageKeys.rewardTransactionPipelineV1
        ..killOnWrite = 2; // 1st write: pending record; 2nd: the commit
      final first = _boot(doomed);
      unawaited(first.pipeline.grantFromPurchase(
        receiptId: 'r1',
        lines: const [RewardLine(currency: 'gem', amount: 100)],
      ));
      await doomed.reached.future;

      final afterKill = _boot(StorageService(prefs));
      expect(afterKill.wallet.balanceOf('gem'), 100, reason: 'the credit reached disk');
      expect(afterKill.pipeline.auditTrail.single.status, RewardTransactionStatus.pending);

      await afterKill.pipeline.resumePending();
      expect(afterKill.wallet.balanceOf('gem'), 100, reason: 'money must not be paid twice');
      expect(afterKill.pipeline.auditTrail.single.status, RewardTransactionStatus.committed);
    });

    test('confirmation lost on the way back (charged but buy threw): next launch credits exactly once', () async {
      final seam = _ScriptedPurchaseSeam(
        script: NetworkScript([NetStep.fail]),
        chargeEvenIfBuyThrows: true,
      );
      final boot = _boot(storage);

      await expectLater(_buyAndGrant(seam, boot.pipeline), throwsA(isA<TransportError>()));
      expect(boot.wallet.balanceOf('gem'), 0, reason: 'the app never saw success');

      seam.restartApp();
      await _recover(seam, boot.pipeline);
      expect(boot.wallet.balanceOf('gem'), 100, reason: 'the player paid, so restore must deliver');

      await _recover(seam, boot.pipeline);
      expect(boot.wallet.balanceOf('gem'), 100);
    });
  });

  group('limits and refunds', () {
    test('a purchase that would overflow the wallet leaves it unchanged and stays resumable', () async {
      final boot = _boot(storage);
      await boot.wallet.earn(currency: 'gem', amount: 0x7fffffff, transactionId: 'fill');

      final result = await boot.pipeline.grantFromPurchase(
        receiptId: 'r1',
        lines: const [RewardLine(currency: 'gem', amount: 1)],
      );

      expect(result, isA<SdkFailure<RewardTransactionRecord>>());
      expect((result as SdkFailure<RewardTransactionRecord>).retryable, isTrue);
      expect(boot.wallet.balanceOf('gem'), 0x7fffffff);

      await boot.wallet.trySpend(currency: 'gem', amount: 10, transactionId: 'spend');
      await boot.pipeline.resumePending();
      expect(boot.wallet.balanceOf('gem'), 0x7fffffff - 10 + 1);
    });

    test('refund after the player spent it: the wallet cannot go negative, the ledger clamps at 0', () async {
      Get.put<StorageService>(storage);
      final boot = _boot(storage);
      final ledger = PurchaseLedgerService();
      await boot.pipeline.grantFromPurchase(
        receiptId: 'r1',
        lines: const [RewardLine(currency: 'gem', amount: 100)],
      );
      ledger.grantConsumable('gem_pack', 100);
      await boot.wallet.trySpend(currency: 'gem', amount: 80, transactionId: 'spent');
      expect(boot.wallet.balanceOf('gem'), 20);

      final clawback = await boot.wallet.trySpend(
        currency: 'gem',
        amount: 100,
        transactionId: 'refund:r1',
      );
      ledger.revokeConsumable('gem_pack', 150);

      expect(clawback, isA<SdkFailure<int>>(), reason: 'not enough left to take back');
      expect(boot.wallet.balanceOf('gem'), 20);
      expect(ledger.balanceOf('gem_pack'), 0);
      await ledger.debugPendingSaves;
    });

    test('the ledger caps a consumable balance instead of wrapping', () async {
      Get.put<StorageService>(storage);
      final ledger = PurchaseLedgerService();
      ledger.grantConsumable('gem_pack', maxCounterValue);

      expect(() => ledger.grantConsumable('gem_pack', 1), throwsRangeError);
      expect(ledger.balanceOf('gem_pack'), maxCounterValue);
      await ledger.debugPendingSaves;
    });

    test('PurchaseLedgerService is NOT receipt-aware: the same grant twice adds twice (callers dedupe via the pipeline)', () async {
      Get.put<StorageService>(storage);
      final ledger = PurchaseLedgerService();

      ledger.grantConsumable('hint', 5);
      ledger.grantConsumable('hint', 5);

      expect(ledger.balanceOf('hint'), 10);
      await ledger.debugPendingSaves;
    });
  });
}
