import 'dart:convert';

import 'package:get/get.dart';

import 'storage_service.dart';
import 'utils/async_action_guard.dart';
import 'utils/sdk_result.dart';

class EconomyWallet extends GetxService {
  EconomyWallet({required this.storage, AsyncActionGuard? guard})
    : _guard = guard ?? AsyncActionGuard();
  final StorageService storage;
  final AsyncActionGuard _guard;
  final balances = <String, int>{}.obs;
  final _transactions = <String>{};
  static const _key = 'economy_wallet_v1';

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
      final next = <String, int>{};
      for (final entry in decoded.entries) {
        if (entry.key is String &&
            entry.value is int &&
            (entry.value as int) >= 0) {
          next[entry.key as String] = entry.value as int;
        }
      }
      balances.assignAll(next);
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
    try {
      await storage.setString(_key, jsonEncode(snapshot));
      balances.assignAll(snapshot);
      _transactions.add(transactionId);
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
