import 'dart:convert';

import 'package:get/get.dart';

import 'storage_service.dart';
import 'utils/async_action_guard.dart';
import 'utils/sdk_result.dart';

class EconomyWallet extends GetxService {
  EconomyWallet({
    required this.storage,
    AsyncActionGuard? guard,
    String? storageKey,
  }) : _guard = guard ?? AsyncActionGuard(),
       _key = storageKey ?? 'economy_wallet_v1';
  final StorageService storage;
  final AsyncActionGuard _guard;
  final balances = <String, int>{}.obs;
  // Bounded FIFO of recently-processed transaction ids — a plain List (not
  // a fancier LRU) is the simplest structure that satisfies "don't grow
  // unboundedly", same posture as ReplayRecorder's ring buffer (IDEA-42).
  // Persisted alongside `balances` (see `_hydrate`/`_apply`) so idempotency
  // survives a restart: without this, a store replaying an already-applied
  // receipt after the app was killed would double-apply it.
  final _transactions = <String>[];
  static const _transactionsCapacity = 200;

  // ENH-73: instance field (was `static const`) so 2 instances can point
  // at 2 independent wallets — e.g. 1 per SaveSlotManager slot via its
  // `keyFor(slotId, suffix)` (same pattern ENH-69/71 used for the other 7
  // per-player services). Defaulting to the same literal every prior
  // release used keeps an existing consumer app's save reading exactly the
  // same table it always did.
  final String _key;

  /// Gets the instance if already registered (safe to call from
  /// game/widget tests).
  static EconomyWallet? get maybe =>
      Get.isRegistered<EconomyWallet>() ? Get.find<EconomyWallet>() : null;

  @override
  void onInit() {
    super.onInit();
    _hydrate();
  }

  void _hydrate() {
    final raw = storage.getString(_key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      // ENH-62: the new format wraps balances under a 'balances' key; the
      // OLD format (before this change) WAS the balances map itself, so
      // whether that key is present is exactly how the two are told apart
      // — a save from before this change has no 'balances' key at all.
      final rawBalances = decoded.containsKey('balances')
          ? decoded['balances']
          : decoded;
      if (rawBalances is Map) {
        final next = <String, int>{};
        for (final entry in rawBalances.entries) {
          if (entry.key is String &&
              entry.value is int &&
              (entry.value as int) >= 0) {
            next[entry.key as String] = entry.value as int;
          }
        }
        balances.assignAll(next);
      }

      // A missing key (old format) or a wrong-typed value (corrupt) both
      // fall back to "no transactions known" rather than throwing — worst
      // case a single already-applied transaction gets re-applied once
      // right after this migration, never a crash or a lost balance read.
      final rawTransactions = decoded['transactions'];
      if (rawTransactions is List) {
        _transactions
          ..clear()
          ..addAll(rawTransactions.whereType<String>());
      }
    } catch (_) {
      balances.clear();
    }
  }

  int balanceOf(String currency) => balances[currency] ?? 0;

  Future<SdkResult<int>> earn({
    required String currency,
    required int amount,
    required String transactionId,
  }) => _apply(currency, amount, transactionId);

  Future<SdkResult<int>> trySpend({
    required String currency,
    required int amount,
    required String transactionId,
  }) => _apply(currency, -amount, transactionId);

  Future<SdkResult<int>> _apply(
    String currency,
    int delta,
    String transactionId,
  ) => _guard.runExclusive('wallet', () async {
    if (currency.isEmpty || transactionId.isEmpty || delta == 0) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Invalid wallet transaction',
      );
    }
    if (_transactions.contains(transactionId)) {
      return SdkSuccess(balanceOf(currency));
    }
    final current = balanceOf(currency);
    final next = current + delta;
    if (next < 0 || next > 0x7fffffff) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Insufficient or invalid balance',
      );
    }
    final snapshot = {...balances, currency: next};
    final nextTransactions = [..._transactions, transactionId];
    if (nextTransactions.length > _transactionsCapacity) {
      nextTransactions.removeRange(
        0,
        nextTransactions.length - _transactionsCapacity,
      );
    }
    try {
      await storage.setString(
        _key,
        jsonEncode({'balances': snapshot, 'transactions': nextTransactions}),
      );
      balances.assignAll(snapshot);
      _transactions
        ..clear()
        ..addAll(nextTransactions);
      return SdkSuccess(next);
    } catch (error, stack) {
      return SdkFailure(
        kind: SdkErrorKind.storage,
        message: 'Wallet could not be saved',
        cause: error,
        stackTrace: stack,
      );
    }
  });
}
