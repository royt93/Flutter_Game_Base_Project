import 'dart:convert';

import 'package:get/get.dart';

import 'analytics_provider.dart';
import 'debug_log.dart';
import 'economy_wallet.dart';
import 'storage_service.dart';
import 'utils/async_action_guard.dart';
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
  const RewardTransactionRecord({
    required this.transactionId,
    required this.source,
    required this.lines,
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

  RewardTransactionRecord copyWith({RewardTransactionStatus? status}) =>
      RewardTransactionRecord(
        transactionId: transactionId,
        source: source,
        lines: lines,
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
  };

  static RewardTransactionRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = asStringOr(json['transactionId'], '');
    if (id.isEmpty) return null;
    final rawLines = json['lines'];
    final lines = rawLines is List
        ? rawLines.map(RewardLine.fromJson).whereType<RewardLine>().toList()
        : const <RewardLine>[];
    if (lines.isEmpty) return null;
    final source = RewardSource.values.firstWhere(
      (s) => s.name == json['source'],
      orElse: () => RewardSource.other,
    );
    final status = RewardTransactionStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => RewardTransactionStatus.pending,
    );
    final rawMeta = json['receiptMeta'];
    return RewardTransactionRecord(
      transactionId: id,
      source: source,
      lines: lines,
      status: status,
      createdAtMs: asIntOr(json['createdAtMs'], 0),
      receiptMeta: rawMeta is Map ? Map<String, Object?>.from(rawMeta) : null,
    );
  }
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
  RewardTransactionPipeline({
    required this.wallet,
    this.onAnalytics,
    AsyncActionGuard? guard,
    String? storageKey,
    this.capacity = 200,
  }) : _guard = guard ?? AsyncActionGuard(),
       _key = storageKey ?? StorageKeys.rewardTransactionPipelineV1 {
    // BUG-40: see EconomyWallet's constructor for why this can't wait for
    // onInit() alone.
    _hydrate();
  }

  final EconomyWallet wallet;

  /// Called once, right after a transaction fully commits. Defaults to
  /// `AnalyticsProvider.maybe?.logEvent(...)` when left null. Any exception
  /// thrown here is caught and logged — it can never undo the grant or turn
  /// [grant]'s result into a failure (see class doc).
  final void Function(RewardTransactionRecord record)? onAnalytics;

  final int capacity;
  final AsyncActionGuard _guard;
  final String _key;
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

  Future<void> _upsert(RewardTransactionRecord record) async {
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
    await storage.setString(
      _key,
      jsonEncode(_records.map((r) => r.toJson()).toList()),
    );
  }

  /// Grants [lines] under [transactionId]. Rejects the whole request before
  /// any mutation if [transactionId] is empty, [lines] is empty, or any
  /// line has an empty currency/non-positive amount. Calling this again
  /// with a [transactionId] that already fully committed is a no-op that
  /// returns the existing record.
  Future<SdkResult<RewardTransactionRecord>> grant({
    required RewardSource source,
    required String transactionId,
    required List<RewardLine> lines,
    Map<String, Object?>? receiptMeta,
  }) => _guard.runExclusive('pipeline', () async {
    if (transactionId.isEmpty ||
        lines.isEmpty ||
        lines.any((l) => l.currency.isEmpty || l.amount <= 0)) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Invalid reward transaction',
      );
    }

    final existing = _find(transactionId);
    if (existing != null &&
        existing.status == RewardTransactionStatus.committed) {
      return SdkSuccess(existing);
    }

    var record =
        existing ??
        RewardTransactionRecord(
          transactionId: transactionId,
          source: source,
          lines: lines,
          status: RewardTransactionStatus.pending,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          receiptMeta: receiptMeta,
        );
    await _upsert(record);

    for (var i = 0; i < record.lines.length; i++) {
      final line = record.lines[i];
      final result = await wallet.earn(
        currency: line.currency,
        amount: line.amount,
        transactionId: '$transactionId#$i',
      );
      if (result is SdkFailure<int>) {
        record = record.copyWith(status: RewardTransactionStatus.partial);
        await _upsert(record);
        return SdkFailure(
          kind: result.kind,
          message: result.message,
          retryable: true,
        );
      }
    }

    record = record.copyWith(status: RewardTransactionStatus.committed);
    await _upsert(record);
    onGranted.value = record;
    _reportAnalytics(record);
    return SdkSuccess(record);
  });

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
      await grant(
        source: record.source,
        transactionId: record.transactionId,
        lines: record.lines,
        receiptMeta: record.receiptMeta,
      );
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
}
