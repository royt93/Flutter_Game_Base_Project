import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';

import 'connectivity_coordinator.dart';
import 'crash_reporter.dart';
import 'storage_service.dart';
import 'utils/clamped_clock.dart';
import 'utils/retry_policy.dart';
import 'utils/safe_json.dart';
import 'utils/sdk_result.dart';

/// What to do when [OfflineOutboxService] uploads an item and the remote
/// authority reports its state has diverged from what was queued locally.
enum ConflictPolicy {
  /// Combine local + remote via the required `merger`, then re-upload the
  /// merged payload once more. If that second attempt still conflicts, the
  /// item falls back to [manual] instead of looping forever.
  merge,

  /// Discard the local change — the remote value wins. This only abandons
  /// *this sync attempt*; it never reaches back into wherever the local
  /// change came from (a wallet, an inventory, ...) to undo it, so nothing
  /// the player already has locally is lost.
  reject,

  /// Neither side is applied automatically — the item moves to
  /// [OfflineOutboxService.manualReviewItems] until [OfflineOutboxService.resolveManual]
  /// is called. The safe default: never silently pick a side.
  manual,
}

/// A [ConflictPolicy.merge] resolution: given the payload that was queued
/// locally and the authority's current payload for the same key, return the
/// payload to re-upload. Must be pure/deterministic — same inputs, same
/// output — since a crash between the merge and the retry may run it again.
typedef ConflictMerger =
    Map<String, Object?> Function(
      Map<String, Object?> local,
      Map<String, Object?> remote,
    );

/// Result of one [OutboxUploader] call.
sealed class SyncOutcome {
  const SyncOutcome();
}

/// The remote authority accepted the payload as-is.
class SyncAck extends SyncOutcome {
  const SyncAck();
}

/// The remote authority's state for this [OutboxItem.idempotencyKey] has
/// diverged from what was queued — [remotePayload] is its current value,
/// handled per [ConflictPolicy].
class SyncConflict extends SyncOutcome {
  const SyncConflict(this.remotePayload);
  final Map<String, Object?> remotePayload;
}

/// Attempts to sync one item with whatever remote authority a consumer app
/// wires up (a REST endpoint, a cloud function, ...) — this service knows
/// nothing about the transport. Throwing (a network error, a timeout) is
/// treated as transient and retried per [OfflineOutboxService.retryPolicy];
/// returning a [SyncOutcome] is the only way to report a definitive
/// accept/conflict. [idempotencyKey] is passed on every attempt (including
/// retries after a crash) specifically so the remote side can dedupe a
/// request it already applied.
typedef OutboxUploader =
    Future<SyncOutcome> Function(
      Map<String, Object?> payload,
      String idempotencyKey,
    );

/// What a caller decided for an item sitting in
/// [OfflineOutboxService.manualReviewItems].
enum ManualResolution {
  /// Re-queue the item's original local payload for another upload attempt.
  keepLocal,

  /// Abandon the local change — remove the item, nothing more is attempted.
  acceptRemote,
}

/// One queued, not-yet-synced unit of work. [payload] is plain,
/// caller-defined JSON data — same "never put a secret in it, it's
/// persisted locally in plain JSON" caveat as
/// `RewardTransactionRecord.receiptMeta` (FEAT-42).
class OutboxItem {
  const OutboxItem({
    required this.idempotencyKey,
    required this.payload,
    this.priority = 0,
    this.expiresAtMs,
    this.manualReview = false,
    this.remotePayload,
  });

  /// Enqueuing a second item with the same key replaces this one rather
  /// than running both, and is what a real [OutboxUploader] backend should
  /// use to dedupe a retried request.
  final String idempotencyKey;
  final Map<String, Object?> payload;

  /// Higher drains first; ties keep insertion order.
  final int priority;

  /// Checked against [nowMsClamped] at drain time — an expired item is
  /// dropped without ever calling [OfflineOutboxService.uploader].
  final int? expiresAtMs;

  /// `true` once a [ConflictPolicy.manual] (or an unresolved
  /// [ConflictPolicy.merge] retry) conflict parked this item — see
  /// [OfflineOutboxService.manualReviewItems].
  final bool manualReview;

  /// The remote authority's payload at the time [manualReview] was set —
  /// `null` otherwise.
  final Map<String, Object?>? remotePayload;

  OutboxItem copyWith({
    Map<String, Object?>? payload,
    bool? manualReview,
    Map<String, Object?>? remotePayload,
  }) => OutboxItem(
    idempotencyKey: idempotencyKey,
    payload: payload ?? this.payload,
    priority: priority,
    expiresAtMs: expiresAtMs,
    manualReview: manualReview ?? this.manualReview,
    remotePayload: remotePayload ?? this.remotePayload,
  );

  Map<String, Object?> toJson() => {
    'idempotencyKey': idempotencyKey,
    'payload': payload,
    'priority': priority,
    if (expiresAtMs != null) 'expiresAtMs': expiresAtMs,
    'manualReview': manualReview,
    if (remotePayload != null) 'remotePayload': remotePayload,
  };

  static OutboxItem? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = asStringOr(json['idempotencyKey'], '');
    if (key.isEmpty) return null;
    final rawPayload = json['payload'];
    final rawRemote = json['remotePayload'];
    return OutboxItem(
      idempotencyKey: key,
      payload: rawPayload is Map
          ? Map<String, Object?>.from(rawPayload)
          : const {},
      priority: asIntOr(json['priority'], 0),
      expiresAtMs: json['expiresAtMs'] == null
          ? null
          : asIntOr(json['expiresAtMs'], 0),
      manualReview: json['manualReview'] == true,
      remotePayload: rawRemote is Map
          ? Map<String, Object?>.from(rawRemote)
          : null,
    );
  }
}

/// Persisted, priority-drained outbox for syncing local changes to a remote
/// authority once back online — built on [RetryExecutor] (FEAT-35) for
/// transient-failure backoff and, when [connectivity] is supplied, driven
/// automatically by [ConnectivityCoordinator] (FEAT-62)'s online transitions
/// the same way that service drains its own internal task queue.
///
/// **Lifecycle**: an item is [enqueue]d → sits pending → [drain] calls
/// [uploader] for it → either [SyncAck] (item removed) or [SyncConflict]
/// (handled per [conflictPolicy], see there) → a [ConflictPolicy.manual] or
/// unresolved [ConflictPolicy.merge] conflict parks it in
/// [manualReviewItems] until [resolveManual].
///
/// **Crash safety**: an item stays in the persisted outbox from [enqueue]
/// until the exact call that removes it *also* persists that removal — so
/// a crash at any point before that (including between the remote
/// authority accepting it and this service recording that) leaves the item
/// still queued for the next [drain], which retries it with the *same*
/// [OutboxItem.idempotencyKey]. Nothing is ever lost; avoiding a duplicate
/// effect on the remote side is the injected [uploader]'s responsibility
/// (a real backend keys on [OutboxItem.idempotencyKey] to dedupe a retried
/// request it already applied) — this service only guarantees it always
/// retries safely, never that it never retries.
///
/// **Error handling**: every public method returns [SdkResult] — this
/// service never throws for a caller-facing error.
///
/// **Compatibility**: [storageKey] namespaces the persisted JSON blob the
/// same way every other kit service's `storageKey` does — pass a distinct
/// one per independent outbox instance (e.g. one per save slot).
class OfflineOutboxService extends GetxService {
  OfflineOutboxService({
    required this.storage,
    required this.uploader,
    this.connectivity,
    this.conflictPolicy = ConflictPolicy.manual,
    this.merger,
    this.capacity = 200,
    this.retryPolicy = const RetryPolicy(maxAttempts: 3),
    RetryExecutor? retryExecutor,
    String? storageKey,
  }) : _retryExecutor = retryExecutor ?? RetryExecutor(),
       _key = storageKey ?? StorageKeys.offlineOutboxV1 {
    // ENH-89: was `assert(conflictPolicy != ConflictPolicy.merge ||
    // merger != null, ...)` — stripped entirely in release builds. A
    // caller passing `conflictPolicy: merge` without `merger` (a
    // hardcoded mistake, or a value assembled from remote config) would
    // then reach a real conflict at runtime with no merger to call,
    // failing confusingly deep inside the conflict-resolution path
    // instead of at construction. A plain `if`/`throw` is never
    // stripped, in any build mode.
    if (conflictPolicy == ConflictPolicy.merge && merger == null) {
      throw ArgumentError.value(
        merger,
        'merger',
        'is required when conflictPolicy is ConflictPolicy.merge',
      );
    }
    // BUG-40: see EconomyWallet's constructor for why this can't wait for
    // onInit() alone. The connectivity-subscription setup stays in onInit()
    // only — that's a GetX-lifecycle-bound side effect, not state hydration.
    _hydrate();
  }

  final StorageService storage;
  final OutboxUploader uploader;
  final ConnectivityCoordinator? connectivity;
  final ConflictPolicy conflictPolicy;
  final ConflictMerger? merger;
  final int capacity;
  final RetryPolicy retryPolicy;
  final RetryExecutor _retryExecutor;
  final String _key;

  final items = <OutboxItem>[].obs;
  bool _draining = false;
  StreamSubscription<ConnectivityState>? _connectivitySub;

  List<OutboxItem> get manualReviewItems =>
      items.where((i) => i.manualReview).toList();

  static OfflineOutboxService? get maybe =>
      Get.isRegistered<OfflineOutboxService>()
      ? Get.find<OfflineOutboxService>()
      : null;

  @override
  void onInit() {
    super.onInit();
    _hydrate();
    final coordinator = connectivity;
    if (coordinator != null) {
      _connectivitySub = coordinator.stateStream.listen((state) {
        if (state == ConnectivityState.online) unawaited(drain());
      });
    }
  }

  void _hydrate() {
    final raw = storage.getString(_key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      items.assignAll(decoded.map(OutboxItem.fromJson).whereType<OutboxItem>());
    } catch (_) {
      items.clear();
    }
  }

  Future<void> _persist() => storage.setString(
    _key,
    jsonEncode(items.map((i) => i.toJson()).toList()),
  );

  /// Queues [payload] under [idempotencyKey] — replaces any existing item
  /// with the same key rather than duplicating it. Bounded at [capacity]:
  /// once full, the lowest-[priority] item is evicted to make room.
  SdkResult<void> enqueue({
    required String idempotencyKey,
    required Map<String, Object?> payload,
    int priority = 0,
    int? expiresAtMs,
  }) {
    if (idempotencyKey.isEmpty) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'idempotencyKey must not be empty',
      );
    }
    final next = [...items]
      ..removeWhere((i) => i.idempotencyKey == idempotencyKey);
    if (next.length >= capacity) {
      // BUG-44: eviction candidates exclude any item already parked in
      // manualReview (never auto-discard something only a human decision
      // can resolve) and must have STRICTLY LOWER priority than the
      // incoming item (a low/equal-priority newcomer can't bump an
      // existing higher-or-equal-priority item). If nothing qualifies,
      // the outbox is genuinely full for this item — reject it loudly
      // instead of silently evicting something it has no right to.
      final evictable = [
        for (var i = 0; i < next.length; i++)
          if (!next[i].manualReview && next[i].priority < priority) i,
      ];
      if (evictable.isEmpty) {
        return const SdkFailure(
          kind: SdkErrorKind.validation,
          message:
              'Outbox is full and no lower-priority, non-manualReview item '
              'can be evicted for this one',
        );
      }
      var lowestIndex = evictable.first;
      for (final i in evictable) {
        if (next[i].priority < next[lowestIndex].priority) lowestIndex = i;
      }
      next.removeAt(lowestIndex);
    }
    next.add(
      OutboxItem(
        idempotencyKey: idempotencyKey,
        payload: payload,
        priority: priority,
        expiresAtMs: expiresAtMs,
      ),
    );
    items.assignAll(next);
    unawaited(_persist());
    // Auto-drain only when a ConnectivityCoordinator confirms we're online
    // right now — without one, the caller drives drain() explicitly (e.g.
    // this SDK's own tests, or an app not wiring FEAT-62 in). Auto-draining
    // unconditionally here would race a caller enqueuing several items
    // back-to-back against each one's own fire-and-forget drain attempt,
    // breaking the priority ordering a single drain() call guarantees.
    if (connectivity?.state == ConnectivityState.online) {
      unawaited(drain());
    }
    return const SdkSuccess(null);
  }

  /// Attempts to sync every non-[OutboxItem.manualReview] item,
  /// highest-[OutboxItem.priority] first. Safe to call concurrently with
  /// itself (a no-op re-entry) or with [enqueue]/[resolveManual].
  Future<void> drain() async {
    if (_draining) return;
    _draining = true;
    try {
      final ordered = [...items.where((i) => !i.manualReview)]
        ..sort((a, b) => b.priority.compareTo(a.priority));
      for (final item in ordered) {
        if (!items.contains(item)) continue;
        final expiresAt = item.expiresAtMs;
        if (expiresAt != null && nowMsClamped(storage) > expiresAt) {
          await _remove(item);
          continue;
        }
        await _attempt(item);
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _attempt(OutboxItem item) async {
    final result = await _retryExecutor.run(
      () => uploader(item.payload, item.idempotencyKey),
      policy: retryPolicy,
    );
    if (result is SdkFailure<SyncOutcome>) {
      // Transient failure, retries exhausted for this drain pass — item
      // stays queued for the next one.
      return;
    }
    final outcome = (result as SdkSuccess<SyncOutcome>).value;
    switch (outcome) {
      case SyncAck():
        await _remove(item);
      case SyncConflict(remotePayload: final remote):
        await _handleConflict(item, remote);
    }
  }

  Future<void> _handleConflict(
    OutboxItem item,
    Map<String, Object?> remote,
  ) async {
    switch (conflictPolicy) {
      case ConflictPolicy.reject:
        await _remove(item);
      case ConflictPolicy.manual:
        await _markManualReview(item, remote);
      case ConflictPolicy.merge:
        // BUG-44: `merger` is consumer-supplied and can throw (a bad
        // assumption about the payload shape, a bug in their merge logic)
        // — without this, that exception would escape drain()'s for-loop
        // entirely, aborting the whole drain pass (and, since enqueue()
        // calls drain() via unawaited(...), potentially surfacing as an
        // unhandled async error) instead of just failing THIS item's
        // attempt the way a transient upload failure already does.
        final Map<String, Object?> merged;
        try {
          merged = merger!(item.payload, remote);
        } catch (error, stack) {
          CrashReporter.maybe?.recordError(
            error,
            stack,
            reason:
                'OfflineOutboxService: ConflictMerger threw for '
                '"${item.idempotencyKey}"',
          );
          return; // item stays queued untouched, retried on the next drain.
        }
        final retryOutcome = await uploader(merged, item.idempotencyKey);
        if (retryOutcome is SyncAck) {
          await _remove(item);
        } else if (retryOutcome is SyncConflict) {
          await _markManualReview(
            item.copyWith(payload: merged),
            retryOutcome.remotePayload,
          );
        }
    }
  }

  Future<void> _markManualReview(
    OutboxItem item,
    Map<String, Object?> remote,
  ) async {
    final idx = items.indexWhere(
      (i) => i.idempotencyKey == item.idempotencyKey,
    );
    final updated = item.copyWith(manualReview: true, remotePayload: remote);
    if (idx < 0) {
      items.add(updated);
    } else {
      items[idx] = updated;
    }
    items.refresh();
    await _persist();
  }

  /// Removes exactly [item] — matched by object identity, not
  /// [OutboxItem.idempotencyKey] (BUG-44). `enqueue` replaces (not
  /// mutates) the item for a given key, so a re-enqueue for the same key
  /// while [item] is mid-upload in [drain] produces a DIFFERENT instance
  /// in [items]; removing by key alone would delete that newer instance
  /// instead of doing nothing to it (silently losing a real, newer
  /// change). [OutboxItem] has no `==` override, so `next[i] == item` is
  /// already identity comparison, same as [drain]'s own
  /// `items.contains(item)` check — `identical` here is just explicit
  /// about relying on that.
  Future<void> _remove(OutboxItem item) async {
    items.removeWhere((i) => identical(i, item));
    await _persist();
  }

  /// Resolves an item sitting in [manualReviewItems]. [ManualResolution.keepLocal]
  /// re-queues its original payload for another [drain] attempt;
  /// [ManualResolution.acceptRemote] removes it — the local change is
  /// abandoned, nothing further is attempted.
  SdkResult<void> resolveManual({
    required String idempotencyKey,
    required ManualResolution resolution,
  }) {
    final idx = items.indexWhere(
      (i) => i.idempotencyKey == idempotencyKey && i.manualReview,
    );
    if (idx < 0) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'No manual-review item with that idempotencyKey',
      );
    }
    if (resolution == ManualResolution.acceptRemote) {
      items.removeAt(idx);
    } else {
      items[idx] = items[idx].copyWith(manualReview: false);
    }
    items.refresh();
    unawaited(_persist());
    return const SdkSuccess(null);
  }

  @override
  void onClose() {
    unawaited(_connectivitySub?.cancel());
    super.onClose();
  }
}
