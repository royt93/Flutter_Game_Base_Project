import 'storage_service.dart';

/// Result of [PlayerDataRightsService.requestExport] — everything currently
/// in [StorageService] plus metadata identifying when/what schema it was
/// captured under, ready to hand to a player who asked "give me my data"
/// (GDPR/CCPA-style export request).
class DataExportReceipt {
  const DataExportReceipt({
    required this.exportedAtMs,
    required this.schemaVersion,
    required this.data,
  });

  final int exportedAtMs;
  final int schemaVersion;

  /// Everything [StorageService.exportAll] returned at export time — the
  /// player's full data, not a redacted/partial slice (an export request
  /// is meant to be complete).
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {
    'exportedAtMs': exportedAtMs,
    'schemaVersion': schemaVersion,
    'data': data,
  };
}

/// Result of [PlayerDataRightsService.requestErasure] — confirms the local
/// storage wipe completed, plus which best-effort erasure hooks (if any
/// were registered) succeeded or failed, so a support/compliance flow has
/// a concrete receipt to show or log rather than just "trust me, it's
/// deleted".
class DataErasureReceipt {
  const DataErasureReceipt({
    required this.completedAtMs,
    required this.erasedKeyCount,
    required this.hookResults,
  });

  final int completedAtMs;

  /// How many storage keys existed right before the wipe (0 if the
  /// player's storage was already empty).
  final int erasedKeyCount;

  /// One entry per registered [PlayerDataRightsService.registerErasureHook]
  /// call, keyed by its label — `true` if that hook completed without
  /// throwing, `false` if it threw (best-effort: 1 failing hook never
  /// blocks the others, or the storage wipe itself, which already ran
  /// first).
  final Map<String, bool> hookResults;

  Map<String, Object?> toJson() => {
    'completedAtMs': completedAtMs,
    'erasedKeyCount': erasedKeyCount,
    'hookResults': hookResults,
  };
}

/// A complete "player requested their data" workflow (GDPR/CCPA-style)
/// built on top of [StorageService.exportAll]/[StorageService.eraseAll] —
/// those give the low-level mechanism, this gives the business workflow: a
/// clear export receipt with metadata, and an erasure receipt confirming
/// completion + which other seams got a chance to clean up their own side.
///
/// **Why hooks, not new methods on [AnalyticsProvider]/[CrashReporter]**:
/// those seams are deliberately minimal (`logEvent`/`recordError` only),
/// and a real analytics/crash SDK's actual "delete this user's data" API is
/// vendor-specific — not something a 1-size-fits-all abstract method could
/// meaningfully wrap. [registerErasureHook] instead lets a consuming app
/// wire in whatever cleanup its own adapters need, generically — not
/// limited to those 2 seams.
class PlayerDataRightsService {
  PlayerDataRightsService({required this.storage, int Function()? nowMs})
    : _nowMs = nowMs ?? (() => DateTime.now().toUtc().millisecondsSinceEpoch);

  final StorageService storage;
  final int Function() _nowMs;

  static const int schemaVersion = 1;

  final Map<String, Future<void> Function()> _erasureHooks = {};

  /// Registers a best-effort cleanup hook (e.g. clear an
  /// [AnalyticsProvider]/[CrashReporter] adapter's own locally-cached data)
  /// to run during [requestErasure], after the local storage wipe. A
  /// second call with the same [label] replaces the prior hook.
  void registerErasureHook(String label, Future<void> Function() hook) {
    _erasureHooks[label] = hook;
  }

  /// Removes a previously-registered hook — a no-op if [label] was never
  /// registered.
  void unregisterErasureHook(String label) {
    _erasureHooks.remove(label);
  }

  /// Exports everything currently in [storage] as a [DataExportReceipt] —
  /// synchronous and never throws, since [StorageService.exportAll] itself
  /// never does.
  DataExportReceipt requestExport() {
    return DataExportReceipt(
      exportedAtMs: _nowMs(),
      schemaVersion: schemaVersion,
      data: storage.exportAll(),
    );
  }

  /// Wipes [storage] completely (via [StorageService.eraseAll]), then runs
  /// every registered erasure hook best-effort (a hook that throws is
  /// recorded as failed in the returned receipt, never rethrown — 1 failing
  /// hook can't block the others or undo the already-completed storage
  /// wipe), and returns a [DataErasureReceipt] confirming completion.
  Future<DataErasureReceipt> requestErasure() async {
    final erasedKeyCount = storage.allKeys().length;
    await storage.eraseAll();

    final hookResults = <String, bool>{};
    for (final entry in _erasureHooks.entries) {
      try {
        await entry.value();
        hookResults[entry.key] = true;
      } catch (_) {
        hookResults[entry.key] = false;
      }
    }

    return DataErasureReceipt(
      completedAtMs: _nowMs(),
      erasedKeyCount: erasedKeyCount,
      hookResults: hookResults,
    );
  }
}
