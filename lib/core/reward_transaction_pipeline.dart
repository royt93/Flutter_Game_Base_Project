import 'dart:convert';

import 'package:get/get.dart';

import 'analytics_provider.dart';
import 'debug_log.dart';
import 'economy_wallet.dart';
import 'inventory_service.dart';
import 'storage_service.dart';
import 'utils/async_action_guard.dart';
import 'utils/fnv1a.dart';
import 'utils/safe_json.dart';
import 'utils/sdk_result.dart';

/// Where a [RewardTransactionRecord] originated — purely descriptive, used
/// for the audit trail/reconciliation, not for any behavior branch inside
/// [RewardTransactionPipeline] itself.
enum RewardSource { ad, purchase, dailyQuest, dailyLogin, other }

/// [RewardTransactionRecord.status] lifecycle: `pending` (reserved, no line
/// applied yet) → `partial` (some lines applied, one failed — resumable,
/// never rolled back) → `committed` (all lines applied). There is no
/// terminal "failed" state: a request that fails validation is rejected
/// before a record is ever created, so every persisted record is always
/// resumable via [RewardTransactionPipeline.resumePending].
enum RewardTransactionStatus { pending, partial, committed }

/// One currency amount inside a [RewardTransactionRecord]. A single reward
/// event (e.g. a rewarded ad) commonly grants more than one currency at
/// once ("+50 coin, +1 energy"), which is why a transaction is a list of
/// these rather than a single currency/amount pair.
class RewardLine {
  const RewardLine({required this.currency, required this.amount});

  final String currency;
  final int amount;

  Map<String, Object?> toJson() => {'currency': currency, 'amount': amount};

  static RewardLine? fromJson(Object? json) {
    if (json is! Map) return null;
    final currency = asStringOr(json['currency'], '');
    final amount = asIntOr(json['amount'], 0);
    if (currency.isEmpty || amount <= 0) return null;
    return RewardLine(currency: currency, amount: amount);
  }
}

/// One reward grant attempt — [RewardTransactionPipeline]'s audit-trail
/// entry. [receiptMeta] is caller-supplied bookkeeping (e.g. a store
/// product id) for reconciliation/support — never put a secret in it, it's
/// persisted locally in plain JSON.
class RewardTransactionRecord {
  /// Legacy/source-compatible currency-only constructor — exact public
  /// signature preserved for the API compatibility gate. Use
  /// [RewardTransactionRecord.withItems] for a FEAT-96 combined plan.
  const RewardTransactionRecord({
    required this.transactionId,
    required this.source,
    required this.lines,
    required this.status,
    required this.createdAtMs,
    this.receiptMeta,
  }) : itemLines = const [];

  const RewardTransactionRecord.withItems({
    required this.transactionId,
    required this.source,
    required this.lines,
    required this.itemLines,
    required this.status,
    required this.createdAtMs,
    this.receiptMeta,
  });

  final String transactionId;
  final RewardSource source;
  final List<RewardLine> lines;
  final RewardTransactionStatus status;
  final int createdAtMs;
  final Map<String, Object?>? receiptMeta;

  /// FEAT-96: inventory item lines granted alongside [lines] (currency) as
  /// part of the same logical transaction — populated by [RewardTransactionPipeline.executePlan].
  /// Empty for every reward that predates FEAT-96 or never involved items.
  final List<InventoryLine> itemLines;

  RewardTransactionRecord copyWith({RewardTransactionStatus? status}) =>
      itemLines.isEmpty
      ? RewardTransactionRecord(
          transactionId: transactionId,
          source: source,
          lines: lines,
          status: status ?? this.status,
          createdAtMs: createdAtMs,
          receiptMeta: receiptMeta,
        )
      : RewardTransactionRecord.withItems(
          transactionId: transactionId,
          source: source,
          lines: lines,
          itemLines: itemLines,
          status: status ?? this.status,
          createdAtMs: createdAtMs,
          receiptMeta: receiptMeta,
        );

  Map<String, Object?> toJson() => {
    'transactionId': transactionId,
    'source': source.name,
    'lines': lines.map((l) => l.toJson()).toList(),
    'status': status.name,
    'createdAtMs': createdAtMs,
    if (receiptMeta != null) 'receiptMeta': receiptMeta,
    if (itemLines.isNotEmpty)
      'itemLines': itemLines
          .map((l) => {'itemId': l.itemId, 'quantity': l.quantity})
          .toList(),
  };

  static RewardTransactionRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = asStringOr(json['transactionId'], '');
    if (id.isEmpty) return null;
    final rawLines = json['lines'];
    final lines = rawLines is List
        ? rawLines.map(RewardLine.fromJson).whereType<RewardLine>().toList()
        : const <RewardLine>[];
    final rawItemLines = json['itemLines'];
    final itemLines = rawItemLines is List
        ? rawItemLines
              .whereType<Map>()
              .map((raw) {
                final itemId = asStringOr(raw['itemId'], '');
                final quantity = asIntOr(raw['quantity'], 0);
                return itemId.isEmpty || quantity <= 0
                    ? null
                    : InventoryLine(itemId: itemId, quantity: quantity);
              })
              .whereType<InventoryLine>()
              .toList()
        : const <InventoryLine>[];
    // A record predating FEAT-96 (or a legacy currency-only reward) has no
    // itemLines at all — only reject when BOTH are empty, matching the old
    // "lines.isEmpty => reject" rule extended to "nothing to grant at all".
    if (lines.isEmpty && itemLines.isEmpty) return null;
    final source = RewardSource.values.firstWhere(
      (s) => s.name == json['source'],
      orElse: () => RewardSource.other,
    );
    final status = RewardTransactionStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => RewardTransactionStatus.pending,
    );
    final rawMeta = json['receiptMeta'];
    final receiptMeta = rawMeta is Map
        ? Map<String, Object?>.from(rawMeta)
        : null;
    return itemLines.isEmpty
        ? RewardTransactionRecord(
            transactionId: id,
            source: source,
            lines: lines,
            status: status,
            createdAtMs: asIntOr(json['createdAtMs'], 0),
            receiptMeta: receiptMeta,
          )
        : RewardTransactionRecord.withItems(
            transactionId: id,
            source: source,
            lines: lines,
            itemLines: itemLines,
            status: status,
            createdAtMs: asIntOr(json['createdAtMs'], 0),
            receiptMeta: receiptMeta,
          );
  }
}

/// Immutable dry-run result from [RewardTransactionPipeline.preview] —
/// what [RewardTransactionPipeline.executePlan] would grant, validated
/// against the state at preview time, WITHOUT having mutated or persisted
/// anything yet (FEAT-96). Only [RewardTransactionPipeline.preview] can
/// construct one.
class RewardPlan {
  const RewardPlan._({
    required this.transactionId,
    required this.source,
    required this.currencyLines,
    required this.itemLines,
    required this.receiptMeta,
    required this.stateFingerprint,
    required this.contentFingerprint,
  });

  final String transactionId;
  final RewardSource source;
  final List<RewardLine> currencyLines;
  final List<InventoryLine> itemLines;

  /// A DEEP COPY of the map passed to [RewardTransactionPipeline.preview] —
  /// never the caller's original reference. Without this, a caller that
  /// kept its own reference to the map it passed in could mutate it after
  /// preview (before [RewardTransactionPipeline.executePlan] runs) and
  /// silently change what gets persisted, with neither [stateFingerprint]
  /// nor [contentFingerprint] (computed from THIS copy, not the caller's
  /// live object) any the wiser.
  final Map<String, Object?>? receiptMeta;

  /// Deterministic fingerprint of every balance/inventory value this plan's
  /// validity depended on at preview time — see
  /// [RewardTransactionPipeline._stateFingerprint]. [executePlan] recomputes
  /// the same fingerprint against the CURRENT state and rejects the plan as
  /// stale (`SdkErrorKind.conflict`) if it no longer matches, instead of
  /// executing against state that may no longer actually have room/balance
  /// for it.
  final int stateFingerprint;

  /// Deterministic fingerprint of this plan's OWN content (currency/item
  /// lines + receiptMeta) — defense-in-depth against a plan somehow being
  /// reconstructed with different content than what [preview] validated
  /// (the primary defense is that [RewardPlan]'s constructor is private and
  /// every field is immutable/unmodifiable, making that impossible through
  /// this class's own public API). [executePlan] recomputes and compares it
  /// the same way it does [stateFingerprint].
  final int contentFingerprint;
}

/// Orchestrates a reward grant (ad/IAP/quest/daily-login) across multiple
/// currency lines on top of [EconomyWallet], which already guarantees
/// per-line idempotency (same derived transaction id → applied once, even
/// across a restart or a concurrent duplicate callback — see
/// `economy_wallet.dart`). This pipeline adds what the wallet alone can't:
/// - Grouping several currency lines under one logical transaction id
///   (each line gets its own derived wallet transaction id
///   `'$transactionId#$i'`, so 2 lines under the same request never collide).
/// - A source-tagged, persisted audit trail for reconciliation/support.
/// - [resumePending] to finish a multi-line grant interrupted mid-way (a
///   `partial` record) — safe to call any number of times, every line is
///   independently idempotent at the wallet layer.
/// - A post-commit analytics hook that can never affect the already-applied
///   reward, no matter what it does.
///
/// Earn-only by design — this models a reward being granted, not currency
/// being spent; a spend flow should call [EconomyWallet.trySpend] directly.
class RewardTransactionPipeline extends GetxService {
  /// Legacy/source-compatible currency-only constructor — exact public
  /// signature preserved for the API compatibility gate. Use
  /// [RewardTransactionPipeline.withInventory] to preview/execute combined
  /// currency+item plans.
  RewardTransactionPipeline({
    required this.wallet,
    this.onAnalytics,
    AsyncActionGuard? guard,
    String? storageKey,
    this.capacity = 200,
    // BUG-81: injectable seam so tests can fake createdAtMs without
    // depending on real wall-clock; defaults to DateTime.now() in prod.
    int Function()? nowMs,
  }) : inventory = null,
       _guard = guard ?? AsyncActionGuard(),
       _key = storageKey ?? StorageKeys.rewardTransactionPipelineV1,
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch) {
    _validateCapacityAndHydrate();
  }

  RewardTransactionPipeline.withInventory({
    required this.wallet,
    required this.inventory,
    this.onAnalytics,
    AsyncActionGuard? guard,
    String? storageKey,
    this.capacity = 200,
    int Function()? nowMs,
  }) : _guard = guard ?? AsyncActionGuard(),
       _key = storageKey ?? StorageKeys.rewardTransactionPipelineV1,
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch) {
    _validateCapacityAndHydrate();
  }

  void _validateCapacityAndHydrate() {
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'capacity', 'must be > 0');
    }
    // BUG-40: see EconomyWallet's constructor for why this can't wait for
    // onInit() alone.
    _hydrate();
  }

  final EconomyWallet wallet;

  /// FEAT-96: required whenever a [preview]/[executePlan]/[grant] call
  /// actually includes item lines — `null` (default) is fine for a pipeline
  /// that only ever grants currency, matching every pre-FEAT-96 call site.
  final InventoryService? inventory;

  /// Called once, right after a transaction fully commits. Defaults to
  /// `AnalyticsProvider.maybe?.logEvent(...)` when left null. Any exception
  /// thrown here is caught and logged — it can never undo the grant or turn
  /// [grant]'s result into a failure (see class doc).
  final void Function(RewardTransactionRecord record)? onAnalytics;

  final int capacity;
  final AsyncActionGuard _guard;
  final String _key;
  final int Function() _nowMs;
  final _records = <RewardTransactionRecord>[];

  /// Fires with the completed record right after each successful commit —
  /// for UI (a reward popup) or other in-app listeners. Not persisted;
  /// [auditTrail] is the durable record.
  final onGranted = Rx<RewardTransactionRecord?>(null);

  StorageService get storage => wallet.storage;

  /// Bounded, newest-last. Like `EconomyWallet`'s own transaction list, the
  /// oldest record is evicted once [capacity] is exceeded — a `pending`/
  /// `partial` record evicted this way can no longer be found by
  /// [resumePending], but the wallet-level idempotency it already applied
  /// (or didn't) is unaffected; only this pipeline's own convenience retry
  /// is lost, not correctness.
  List<RewardTransactionRecord> get auditTrail => List.unmodifiable(_records);

  static RewardTransactionPipeline? get maybe =>
      Get.isRegistered<RewardTransactionPipeline>()
      ? Get.find<RewardTransactionPipeline>()
      : null;

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
      if (decoded is! List) return;
      _records
        ..clear()
        ..addAll(
          decoded
              .map(RewardTransactionRecord.fromJson)
              .whereType<RewardTransactionRecord>(),
        );
    } catch (_) {
      _records.clear();
    }
  }

  RewardTransactionRecord? _find(String transactionId) {
    for (final record in _records) {
      if (record.transactionId == transactionId) return record;
    }
    return null;
  }

  /// Returns `null` on success. A persist failure (BUG-88) rolls the
  /// in-memory mutation back to the snapshot taken before this call — so a
  /// storage exception never leaves `_records` claiming a state the disk
  /// doesn't actually have — and returns an `SdkFailure(kind: storage)` for
  /// [grant] to surface instead of letting the exception escape.
  Future<SdkFailure<RewardTransactionRecord>?> _upsert(
    RewardTransactionRecord record,
  ) async {
    final snapshot = List<RewardTransactionRecord>.of(_records);
    final idx = _records.indexWhere(
      (r) => r.transactionId == record.transactionId,
    );
    if (idx >= 0) {
      _records[idx] = record;
    } else {
      _records.add(record);
      if (_records.length > capacity) {
        _records.removeRange(0, _records.length - capacity);
      }
    }
    try {
      await storage.setString(
        _key,
        jsonEncode(_records.map((r) => r.toJson()).toList()),
      );
      return null;
    } catch (error, stack) {
      _records
        ..clear()
        ..addAll(snapshot);
      return SdkFailure(
        kind: SdkErrorKind.storage,
        message: 'Failed to persist reward transaction',
        cause: error,
        stackTrace: stack,
      );
    }
  }

  /// Grants [lines] under [transactionId]. Rejects the whole request before
  /// any mutation if [transactionId] is empty, [lines] is empty, or any
  /// line has an empty currency/non-positive amount. Calling this again
  /// with a [transactionId] that already fully committed is a no-op that
  /// returns the existing record.
  /// Legacy/source-compatible currency-only API — exact public signature
  /// preserved for the API compatibility gate. Use [grantWithItems] (or
  /// [preview]/[executePlan]) for a combined currency+inventory reward.
  Future<SdkResult<RewardTransactionRecord>> grant({
    required RewardSource source,
    required String transactionId,
    required List<RewardLine> lines,
    Map<String, Object?>? receiptMeta,
  }) => _grantInternal(
    source: source,
    transactionId: transactionId,
    lines: lines,
    receiptMeta: receiptMeta,
  );

  Future<SdkResult<RewardTransactionRecord>> grantWithItems({
    required RewardSource source,
    required String transactionId,
    List<RewardLine> lines = const [],
    required List<InventoryLine> itemLines,
    Map<String, Object?>? receiptMeta,
  }) => _grantInternal(
    source: source,
    transactionId: transactionId,
    lines: lines,
    itemLines: itemLines,
    receiptMeta: receiptMeta,
  );

  Future<SdkResult<RewardTransactionRecord>> _grantInternal({
    required RewardSource source,
    required String transactionId,
    required List<RewardLine> lines,
    List<InventoryLine> itemLines = const [],
    Map<String, Object?>? receiptMeta,
  }) => _guard.runExclusive('pipeline', () async {
    if (transactionId.isEmpty) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Invalid reward transaction',
      );
    }
    final invalid = _validateLines(lines, itemLines);
    if (invalid != null) return invalid;

    final existing = _find(transactionId);
    if (existing != null &&
        existing.status == RewardTransactionStatus.committed) {
      return SdkSuccess(existing);
    }

    // BUG-71: a pending/partial record's `lines` are what each line index's
    // derived wallet transaction id (`'$transactionId#$i'`) was already
    // reserved against — silently swapping in a DIFFERENT `lines` list here
    // would keep using the OLD lines (see below), quietly discarding
    // whatever the caller just passed, with no error to signal it. Reject
    // instead so a caller who genuinely needs different amounts is forced
    // to either retry via [resumePending] (which always replays the
    // original `lines`) or pick a new `transactionId`. FEAT-96: same rule
    // now extended to `itemLines`.
    if (existing != null &&
        (!_linesMatch(existing.lines, lines) ||
            !_itemLinesMatch(existing.itemLines, itemLines))) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message:
            'grant() called again for a pending/partial transactionId with '
            'different lines than the existing record — call '
            'resumePending() to retry with the original lines, or use a '
            'new transactionId for a different grant',
      );
    }

    var record =
        existing ??
        (itemLines.isEmpty
            ? RewardTransactionRecord(
                transactionId: transactionId,
                source: source,
                lines: lines,
                status: RewardTransactionStatus.pending,
                createdAtMs: _nowMs(),
                receiptMeta: receiptMeta,
              )
            : RewardTransactionRecord.withItems(
                transactionId: transactionId,
                source: source,
                lines: lines,
                itemLines: itemLines,
                status: RewardTransactionStatus.pending,
                createdAtMs: _nowMs(),
                receiptMeta: receiptMeta,
              ));
    final pendingPersistFailure = await _upsert(record);
    if (pendingPersistFailure != null) return pendingPersistFailure;

    for (var i = 0; i < record.lines.length; i++) {
      final line = record.lines[i];
      final result = await wallet.earn(
        currency: line.currency,
        amount: line.amount,
        transactionId: '$transactionId#$i',
      );
      if (result is SdkFailure<int>) {
        record = record.copyWith(status: RewardTransactionStatus.partial);
        final partialPersistFailure = await _upsert(record);
        if (partialPersistFailure != null) return partialPersistFailure;
        return SdkFailure(
          kind: result.kind,
          message: result.message,
          retryable: true,
        );
      }
    }

    // FEAT-96: item lines apply AFTER every currency line has committed —
    // same `pending -> partial -> committed` state machine, just one more
    // sub-operation in the chain. A failure here leaves the record
    // `partial` (currency already committed, items not yet) exactly like a
    // currency-line failure would — [resumePending] retries this same
    // `grant()` call, and `wallet.earn`'s own idempotency ledger makes
    // re-running the already-committed currency lines a no-op, so nothing
    // is double-applied on retry.
    if (record.itemLines.isNotEmpty) {
      final inv = inventory;
      if (inv == null) {
        // Can only happen if `inventory` was removed between grant() calls
        // for a pending/partial record — validated as non-null at the top
        // of this method for the normal path.
        record = record.copyWith(status: RewardTransactionStatus.partial);
        final partialPersistFailure = await _upsert(record);
        if (partialPersistFailure != null) return partialPersistFailure;
        return const SdkFailure(
          kind: SdkErrorKind.validation,
          message: 'itemLines require an InventoryService to be configured',
          retryable: true,
        );
      }
      final itemResult = await inv.grant(
        lines: record.itemLines,
        transactionId: '$transactionId#item',
      );
      if (itemResult is SdkFailure<InventorySnapshot>) {
        record = record.copyWith(status: RewardTransactionStatus.partial);
        final partialPersistFailure = await _upsert(record);
        if (partialPersistFailure != null) return partialPersistFailure;
        return SdkFailure(
          kind: itemResult.kind,
          message: itemResult.message,
          retryable: true,
        );
      }
    }

    record = record.copyWith(status: RewardTransactionStatus.committed);
    final committedPersistFailure = await _upsert(record);
    if (committedPersistFailure != null) return committedPersistFailure;
    onGranted.value = record;
    _reportAnalytics(record);
    return SdkSuccess(record);
  });

  SdkFailure<RewardTransactionRecord>? _validateLines(
    List<RewardLine> lines,
    List<InventoryLine> itemLines,
  ) {
    if (lines.isEmpty && itemLines.isEmpty) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Invalid reward transaction',
      );
    }
    if (lines.any((l) => l.currency.isEmpty || l.amount <= 0) ||
        itemLines.any((l) => l.itemId.isEmpty || l.quantity <= 0)) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Invalid reward transaction',
      );
    }
    if (itemLines.isNotEmpty && inventory == null) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'itemLines require an InventoryService to be configured',
      );
    }
    return null;
  }

  /// FEAT-96: computes what [grant]/[executePlan] would do for [lines] +
  /// [itemLines] against the state RIGHT NOW, without mutating or
  /// persisting anything — for a UI that needs to show "you will receive
  /// X" before the player commits. Rejects the same malformed input
  /// [grant] would (empty transactionId, empty currency/non-positive
  /// amount, unknown item id, capacity exceeded) so a caller can trust a
  /// successful preview will actually apply cleanly via [executePlan] —
  /// unless the relevant state changes in between, which [executePlan]
  /// itself detects and rejects as stale.
  SdkResult<RewardPlan> preview({
    required RewardSource source,
    required String transactionId,
    List<RewardLine> currencyLines = const [],
    List<InventoryLine> itemLines = const [],
    Map<String, Object?>? receiptMeta,
  }) {
    if (transactionId.isEmpty) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Invalid reward transaction',
      );
    }
    final invalid = _validateLines(currencyLines, itemLines);
    if (invalid != null) {
      return SdkFailure(kind: invalid.kind, message: invalid.message);
    }

    // Accumulate per-currency instead of checking each line independently
    // against the real current balance — `grant`/`_grantInternal` applies
    // lines SEQUENTIALLY via `wallet.earn`, so 2+ lines for the SAME
    // currency compound on top of each other by the time execution reaches
    // the later one. Checking each line against the unchanged real balance
    // would let a preview succeed for amounts that individually fit but
    // together overflow, only for `executePlan` to then hit that same
    // overflow for real and land the plan in `partial` — silently breaking
    // this method's own "a successful preview applies cleanly" promise.
    final projectedBalances = <String, int>{};
    for (final line in currencyLines) {
      final current =
          projectedBalances[line.currency] ?? wallet.balanceOf(line.currency);
      final next = current + line.amount;
      if (next < 0 || next > 0x7fffffff) {
        return const SdkFailure(
          kind: SdkErrorKind.validation,
          message: 'Insufficient or invalid balance',
        );
      }
      projectedBalances[line.currency] = next;
    }
    if (itemLines.isNotEmpty) {
      final previewResult = inventory!.previewGrant(lines: itemLines);
      if (previewResult is SdkFailure<InventorySnapshot>) {
        return SdkFailure(
          kind: previewResult.kind,
          message: previewResult.message,
        );
      }
    }

    // Deep copy — via a JSON round-trip, since receiptMeta is documented as
    // plain-JSON-safe bookkeeping already (RewardTransactionRecord persists
    // it through jsonEncode) — so a caller mutating the map/list reference
    // it originally passed in can never retroactively change this plan's
    // content out from under [contentFingerprint].
    final receiptMetaCopy = receiptMeta == null
        ? null
        : (jsonDecode(jsonEncode(receiptMeta)) as Map).cast<String, Object?>();
    final frozenCurrencyLines = List<RewardLine>.unmodifiable(currencyLines);
    final frozenItemLines = List<InventoryLine>.unmodifiable(itemLines);

    return SdkSuccess(
      RewardPlan._(
        transactionId: transactionId,
        source: source,
        currencyLines: frozenCurrencyLines,
        itemLines: frozenItemLines,
        receiptMeta: receiptMetaCopy,
        stateFingerprint: _stateFingerprint(currencyLines, itemLines),
        contentFingerprint: _contentFingerprint(
          transactionId,
          frozenCurrencyLines,
          frozenItemLines,
          receiptMetaCopy,
        ),
      ),
    );
  }

  /// Applies a [plan] built by [preview] — rejects it as stale
  /// (`SdkErrorKind.conflict`) if the balances/inventory it was validated
  /// against have changed since, instead of executing against state that
  /// may no longer actually have room/balance for it. Otherwise delegates
  /// straight to [grant] — same persisted audit trail, same resumable
  /// `partial` state on a mid-way failure.
  Future<SdkResult<RewardTransactionRecord>> executePlan(
    RewardPlan plan,
  ) async {
    // Defense-in-depth (see RewardPlan.contentFingerprint's doc) — this
    // can't actually be tripped through this class's own public API today
    // (RewardPlan's constructor is private, its lists unmodifiable, and
    // preview() deep-copies receiptMeta), but recomputing it costs nothing
    // and means a future change to this file that accidentally weakens one
    // of those guarantees fails loudly here instead of silently executing
    // altered content.
    final recomputedContent = _contentFingerprint(
      plan.transactionId,
      plan.currencyLines,
      plan.itemLines,
      plan.receiptMeta,
    );
    if (recomputedContent != plan.contentFingerprint) {
      return const SdkFailure(
        kind: SdkErrorKind.conflict,
        message: 'Reward plan content does not match what was previewed.',
      );
    }
    final current = _stateFingerprint(plan.currencyLines, plan.itemLines);
    if (current != plan.stateFingerprint) {
      return const SdkFailure(
        kind: SdkErrorKind.conflict,
        message:
            'Reward plan is stale — balances/inventory changed since it '
            'was previewed. Preview again before executing.',
      );
    }
    return grantWithItems(
      source: plan.source,
      transactionId: plan.transactionId,
      lines: plan.currencyLines,
      itemLines: plan.itemLines,
      receiptMeta: plan.receiptMeta,
    );
  }

  /// Deterministic fingerprint of every value a [preview]'s validity
  /// depended on: the CURRENT balance of every currency in [currencyLines]
  /// (not the whole wallet — an unrelated currency changing shouldn't stale
  /// a plan that never touched it) plus the full inventory snapshot
  /// whenever [itemLines] is non-empty (capacity fill order depends on
  /// every existing slot, not just same-item ones).
  int _stateFingerprint(
    List<RewardLine> currencyLines,
    List<InventoryLine> itemLines,
  ) {
    final currencies = {for (final l in currencyLines) l.currency}.toList()
      ..sort();
    final balances = {
      for (final currency in currencies) currency: wallet.balanceOf(currency),
    };
    Object? inventoryFingerprint;
    if (itemLines.isNotEmpty) {
      final snap = inventory!.snapshot.value;
      inventoryFingerprint = [
        for (final slot in snap.slots)
          '${slot.slotId}:${slot.itemId}:${slot.quantity}:${slot.equipped}',
      ];
    }
    return fnv1aHash(jsonEncode({'b': balances, 'i': inventoryFingerprint}));
  }

  int _contentFingerprint(
    String transactionId,
    List<RewardLine> currencyLines,
    List<InventoryLine> itemLines,
    Map<String, Object?>? receiptMeta,
  ) => fnv1aHash(
    jsonEncode({
      'tx': transactionId,
      'currency': [for (final l in currencyLines) l.toJson()],
      'items': [
        for (final l in itemLines) {'itemId': l.itemId, 'quantity': l.quantity},
      ],
      'meta': receiptMeta,
    }),
  );

  void _reportAnalytics(RewardTransactionRecord record) {
    try {
      if (onAnalytics != null) {
        onAnalytics!(record);
      } else {
        AnalyticsProvider.maybe?.logEvent('reward_granted', {
          'transactionId': record.transactionId,
          'source': record.source.name,
        });
      }
    } catch (error) {
      dlog('RewardTransactionPipeline: analytics failed: $error');
    }
  }

  /// Retries every `pending`/`partial` record — safe to call any time (app
  /// boot, after regaining connectivity, ...), any number of times: each
  /// line is independently idempotent at the wallet layer.
  Future<void> resumePending() async {
    final unresolved = _records
        .where((r) => r.status != RewardTransactionStatus.committed)
        .toList();
    for (final record in unresolved) {
      if (record.itemLines.isEmpty) {
        await grant(
          source: record.source,
          transactionId: record.transactionId,
          lines: record.lines,
          receiptMeta: record.receiptMeta,
        );
      } else {
        await grantWithItems(
          source: record.source,
          transactionId: record.transactionId,
          lines: record.lines,
          itemLines: record.itemLines,
          receiptMeta: record.receiptMeta,
        );
      }
    }
  }

  Future<SdkResult<RewardTransactionRecord>> grantFromDailyQuest({
    required String questId,
    required String periodKey,
    required List<RewardLine> lines,
  }) => grant(
    source: RewardSource.dailyQuest,
    transactionId: 'daily_quest:$questId:$periodKey',
    lines: lines,
  );

  Future<SdkResult<RewardTransactionRecord>> grantFromDailyLogin({
    required int day,
    required String periodKey,
    required List<RewardLine> lines,
  }) => grant(
    source: RewardSource.dailyLogin,
    transactionId: 'daily_login:day$day:$periodKey',
    lines: lines,
  );

  Future<SdkResult<RewardTransactionRecord>> grantFromPurchase({
    required String receiptId,
    required List<RewardLine> lines,
    Map<String, Object?>? receiptMeta,
  }) => grant(
    source: RewardSource.purchase,
    transactionId: 'purchase:$receiptId',
    lines: lines,
    receiptMeta: receiptMeta,
  );

  static bool _linesMatch(List<RewardLine> a, List<RewardLine> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].currency != b[i].currency || a[i].amount != b[i].amount) {
        return false;
      }
    }
    return true;
  }

  static bool _itemLinesMatch(List<InventoryLine> a, List<InventoryLine> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].itemId != b[i].itemId || a[i].quantity != b[i].quantity) {
        return false;
      }
    }
    return true;
  }
}
