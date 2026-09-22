import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'storage_service.dart';
import 'versioned_json_store.dart';

class _LedgerState {
  _LedgerState({required this.consumables, required this.permanents});

  // A fresh, mutable empty state — NOT a `static const` — every call.
  // `grantConsumable`/`grantPermanent` mutate these collections in place,
  // and a `const {}`/`const {}` literal would be an unmodifiable
  // singleton shared across every instance that never had a prior save.
  static _LedgerState initial() =>
      _LedgerState(consumables: {}, permanents: {});

  final Map<String, int> consumables;
  final Set<String> permanents;
}

/// Thin local cache on top of `PurchaseSeam` for the 2 purchase shapes
/// almost every game needs and would otherwise re-implement per project:
/// a consumable with a remaining balance ("5 hint tokens left") and a
/// permanent one-time unlock ("remove ads", "premium skin pack").
///
/// **This is NOT a receipt-validation layer.** It trusts whatever it's
/// told — [grantConsumable]/[grantPermanent] are meant to be called by the
/// app's own `PurchaseSeam` adapter, and ONLY after that adapter has
/// already verified the purchase through the real store/server. This
/// service persists the resulting balance/ownership locally; it has no
/// way to detect a fabricated grant call, same trust-boundary framing as
/// `save_integrity.dart`'s "best-effort local cache, not a substitute for
/// server-side validation" doc.
class PurchaseLedgerService extends GetxService {
  PurchaseLedgerService({String? storageKey})
    : _storageKey = storageKey ?? StorageKeys.purchaseLedgerV1;

  // ENH-71: instance field (was `static const`) so 2 instances can point
  // at 2 independent ledgers — e.g. 1 per SaveSlotManager slot via its
  // `keyFor(slotId, suffix)` (same pattern ENH-69 used for
  // LocalScoreboardService). Defaulting to the same literal every prior
  // release used keeps an existing consumer app's save reading exactly the
  // same table it always did.
  final String _storageKey;
  static final int _maxInt = 0x7FFFFFFFFFFFFFFF;

  _LedgerState? _cached;

  /// Gets the instance if already registered (safe to call from
  /// game/widget tests).
  static PurchaseLedgerService? get maybe =>
      Get.isRegistered<PurchaseLedgerService>()
      ? Get.find<PurchaseLedgerService>()
      : null;

  VersionedJsonStore<_LedgerState> get _store =>
      VersionedJsonStore<_LedgerState>(
        storage: StorageService.to,
        key: _storageKey,
        schemaVersion: 1,
        toJson: (value) => {
          'consumables': value.consumables,
          'permanents': value.permanents.toList(),
        },
        fromJson: _parseState,
        migrate: (fromVersion, json) => json,
      );

  static _LedgerState _parseState(Map<String, Object?> json) {
    final consumablesRaw = json['consumables'];
    final permanentsRaw = json['permanents'];
    if (consumablesRaw is! Map || permanentsRaw is! List) {
      return _LedgerState.initial();
    }

    final consumables = <String, int>{};
    for (final entry in consumablesRaw.entries) {
      final sku = entry.key;
      final balance = entry.value;
      if (sku is! String || sku.trim().isEmpty) continue;
      if (balance is! int || balance < 0) continue;
      consumables[sku] = balance;
    }

    final permanents = <String>{};
    for (final sku in permanentsRaw) {
      if (sku is! String || sku.trim().isEmpty) continue;
      permanents.add(sku);
    }

    return _LedgerState(consumables: consumables, permanents: permanents);
  }

  // Lazily hydrated on first touch — same reasoning as
  // AchievementService/DailyQuestService: avoids depending on
  // StorageService already being Get.put'd before this service is
  // constructed.
  _LedgerState get _state {
    if (_cached != null) return _cached!;
    try {
      _cached = _store.load() ?? _LedgerState.initial();
    } catch (_) {
      _cached = _LedgerState.initial();
    }
    return _cached!;
  }

  // Same save-serialization pattern as every other ledger-shaped service
  // in this package (BUG-17): a burst of rapid grant/consume calls
  // without awaiting in between must still land on disk in the order
  // they were made.
  bool _saving = false;
  bool _saveDirty = false;
  Future<void> _saveChain = Future.value();

  Future<void> _runSave() async {
    try {
      await _store.save(_state);
    } catch (_) {
      // Swallow — a transient save failure must not wedge every
      // subsequent grant/consume's save behind a permanently-rejected
      // chain.
    }
  }

  // BUG-45: was `_saving ? _saveChain.then(...) : _runSave()` — same race
  // as every other service in this family (see
  // season_event_service.dart's longer comment on this exact method for
  // why the naive "drop `_saving`, chain via `.then()`" fix is ALSO wrong,
  // proven by TDD). Keeps `_saving`, resets it only after a whole pass
  // settles with no new request arriving during it, calling `_runSave()`
  // directly (never through `await`/`.then()`) and rescheduling via
  // `Future.whenComplete`. `_scheduleSave` itself never awaits anything,
  // so its `if (_saving)` check-and-set is atomic.
  void _scheduleSave() {
    if (_saving) {
      _saveDirty = true;
      return;
    }
    _saving = true;
    _runSaveAndReschedule();
  }

  void _runSaveAndReschedule() {
    _saveDirty = false;
    _saveChain = _runSave().whenComplete(() {
      if (_saveDirty) {
        _runSaveAndReschedule();
      } else {
        _saving = false;
      }
    });
  }

  /// Awaits every save queued so far — lets a test deterministically wait
  /// for a burst of rapid calls to fully settle instead of guessing a
  /// delay.
  @visibleForTesting
  Future<void> get debugPendingSaves => _saveChain;

  void _validateSku(String sku) {
    if (sku.trim().isEmpty) {
      throw ArgumentError.value(sku, 'sku', 'must not be empty');
    }
  }

  void _validateAmount(int amount) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'must be greater than 0');
    }
  }

  /// Adds [amount] to [sku]'s consumable balance.
  void grantConsumable(String sku, int amount) {
    _validateSku(sku);
    _validateAmount(amount);
    final current = _state.consumables[sku] ?? 0;
    if (amount > _maxInt - current) {
      throw RangeError('balance overflow for $sku');
    }
    _state.consumables[sku] = current + amount;
    _scheduleSave();
  }

  /// Spends [amount] from [sku]'s consumable balance. Returns `true` if
  /// the balance covered it (and was deducted); `false` (never throws,
  /// balance left untouched) if [sku] has fewer than [amount] remaining —
  /// this is the guard against the balance ever going negative.
  bool consume(String sku, int amount) {
    _validateSku(sku);
    _validateAmount(amount);
    final current = _state.consumables[sku] ?? 0;
    if (amount > current) return false;
    _state.consumables[sku] = current - amount;
    _scheduleSave();
    return true;
  }

  /// [sku]'s current consumable balance, `0` if never granted (never
  /// throws).
  int balanceOf(String sku) => _state.consumables[sku] ?? 0;

  /// Marks [sku] as permanently owned. Safe to call again for an
  /// already-owned [sku] — stays owned, no error.
  void grantPermanent(String sku) {
    _validateSku(sku);
    _state.permanents.add(sku);
    _scheduleSave();
  }

  /// `true` once [sku] has been [grantPermanent]ed, `false` (never
  /// throws) otherwise.
  bool owns(String sku) => _state.permanents.contains(sku);

  /// Reverses a [grantConsumable] — subtracts [amount] from [sku]'s
  /// balance for a store refund/chargeback arriving after the original
  /// grant. Clamped at `0` (never throws `RangeError`) rather than going
  /// negative: the player may have already spent some of that balance by
  /// the time the refund lands, and a negative "debt" balance has no
  /// meaningful interpretation here.
  void revokeConsumable(String sku, int amount) {
    _validateSku(sku);
    _validateAmount(amount);
    final current = _state.consumables[sku] ?? 0;
    _state.consumables[sku] = amount >= current ? 0 : current - amount;
    _scheduleSave();
  }

  /// Reverses a [grantPermanent] — for a store refund/chargeback. Safe to
  /// call for a [sku] never granted (no-op, mirrors [grantPermanent]'s own
  /// "safe to call again" symmetry).
  void revokePermanent(String sku) {
    _validateSku(sku);
    _state.permanents.remove(sku);
    _scheduleSave();
  }
}
