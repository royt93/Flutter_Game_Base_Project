import 'dart:convert';

import 'cloud_save_provider.dart';
import 'debug_log.dart';
import 'storage_service.dart';
import 'utils/clamped_clock.dart';
import 'utils/safe_json.dart';
import 'utils/save_migration_registry.dart';
import 'utils/sdk_result.dart';

/// One side (local or cloud) of a [VersionedSyncConflict] — the parsed value plus
/// the `syncedAtMs` timestamp it was saved under.
class VersionedSyncConflictSide<T> {
  const VersionedSyncConflictSide({required this.value, required this.syncedAtMs});
  final T value;
  final int syncedAtMs;
}

/// Both sides of a genuine [VersionedJsonStore.syncWith] conflict — local
/// and cloud both have DIFFERENT data (see [VersionedJsonStore.syncWith]'s
/// own doc for exactly when this is raised), so picking a winner by
/// timestamp alone risks silently discarding real progress from whichever
/// device loses.
class VersionedSyncConflict<T> {
  const VersionedSyncConflict({required this.local, required this.cloud});
  final VersionedSyncConflictSide<T> local;
  final VersionedSyncConflictSide<T> cloud;
}

/// Which side [VersionedSyncConflictResolution] picked.
enum VersionedSyncConflictStrategy { preferLocal, preferCloud, merge }

/// What an [onConflict] handler decided to do about a [VersionedSyncConflict] —
/// built via one of the 3 named constructors, never directly.
class VersionedSyncConflictResolution<T> {
  const VersionedSyncConflictResolution.preferLocal()
    : strategy = VersionedSyncConflictStrategy.preferLocal,
      mergedValue = null;
  const VersionedSyncConflictResolution.preferCloud()
    : strategy = VersionedSyncConflictStrategy.preferCloud,
      mergedValue = null;

  /// Neither side wins outright — [value] (built by the caller, e.g. by
  /// combining fields from both [VersionedSyncConflict.local]/[VersionedSyncConflict.cloud])
  /// becomes the new value on BOTH local storage and the cloud.
  const VersionedSyncConflictResolution.merge(T value)
    : strategy = VersionedSyncConflictStrategy.merge,
      mergedValue = value;

  final VersionedSyncConflictStrategy strategy;
  final T? mergedValue;
}

/// Caller-supplied conflict handler for [VersionedJsonStore.syncWith] —
/// see that method's doc for exactly when this is invoked, and its
/// exception-safety contract.
typedef VersionedSyncConflictHandler<T> =
    VersionedSyncConflictResolution<T> Function(VersionedSyncConflict<T> conflict);

/// A thin, versioned JSON object store on top of [StorageService]'s plain
/// key-value strings — for save data with actual shape (player profile,
/// level progress) that needs to survive a schema change between game
/// versions without losing old players' data.
///
/// Not a schema itself: callers supply [toJson]/[fromJson] for their own
/// [T], and a [migrate] step that upgrades an old JSON map (tagged with the
/// `schemaVersion` it was saved under) to the current shape before
/// [fromJson] ever sees it.
///
/// **Trust boundary (BUG-20):** every envelope this class reads — a local
/// save from disk, or a cloud payload from [syncWith] — is treated as
/// untrusted. Malformed JSON, a non-object root, a `schemaVersion` of the
/// wrong type, or a `schemaVersion` NEWER than this store's own
/// [schemaVersion] (e.g. the app was downgraded after a newer version
/// wrote that save) is rejected — [load]/[syncWith] fall back to "nothing
/// usable" (`null`, same as a fresh install) rather than throw or hand a
/// shape [fromJson]/[migrate] were never told how to read.
class VersionedJsonStore<T> {
  VersionedJsonStore({
    required this.storage,
    required this.key,
    required this.schemaVersion,
    required this.toJson,
    required this.fromJson,
    required this.migrate,
    this.migrationRegistry,
  });

  final StorageService storage;
  final String key;
  final int schemaVersion;
  final Map<String, Object?> Function(T value) toJson;
  final T Function(Map<String, Object?> json) fromJson;

  /// Upgrades a JSON map saved under an older [fromVersion] to a shape
  /// [fromJson] can read. Not called when the stored data is already at
  /// [schemaVersion].
  final Map<String, Object?> Function(
    int fromVersion,
    Map<String, Object?> json,
  )
  migrate;
  final SaveMigrationRegistry? migrationRegistry;

  Future<void> save(T value) async {
    final json = {
      ...toJson(value),
      'schemaVersion': schemaVersion,
      // nowMsClamped(storage) — NOT raw DateTime.now() — with THIS store's
      // own injected `storage` (not the ambient StorageService.to), so the
      // last-write-wins cloud-sync timestamp can't be rolled back by
      // winding the device clock, matching every other reward-adjacent
      // timestamp in this package (BUG-13).
      'syncedAtMs': nowMsClamped(storage),
    };
    await storage.setString(key, jsonEncode(json));
  }

  /// Returns `null` if nothing has been saved yet, or if what's saved
  /// isn't safely usable (see the class doc's trust-boundary policy).
  T? load() {
    final json = _readLocalJson();
    if (json == null) return null;
    return fromJson(json);
  }

  SdkResult<T> loadResult() {
    try {
      final value = load();
      return value == null
          ? const SdkFailure(
              kind: SdkErrorKind.storage,
              message: 'Save data unavailable',
              retryable: false,
            )
          : SdkSuccess(value);
    } catch (error, stack) {
      return SdkFailure(
        kind: SdkErrorKind.storage,
        message: 'Save data could not be read',
        cause: error,
        stackTrace: stack,
      );
    }
  }

  /// Decodes the raw string from [storage], migrating an older
  /// `schemaVersion` to the current shape. Never throws: a decode failure,
  /// a non-object JSON root, or a NEWER-than-[schemaVersion] envelope all
  /// return `null` instead.
  Map<String, Object?>? _readLocalJson() {
    final raw = storage.getString(key);
    if (raw == null || raw.isEmpty) return null;

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    try {
      return _validate(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Applies this store's schema policy to an already-decoded envelope —
  /// shared by [_readLocalJson] (a local save) and [syncWith] (a cloud
  /// payload), which is exactly as untrusted as a local save file.
  ///
  /// - Not a `Map<String, Object?>` at all → rejected (`null`).
  /// - `schemaVersion` newer than this store's own → rejected (`null`):
  ///   [migrate] was only ever written to upgrade FROM older versions, so
  ///   handing it (or today's [fromJson]) a shape from the future would be
  ///   guessing, not migrating.
  /// - `schemaVersion` older → run through [migrate] first.
  /// - Already current → returned as-is.
  Map<String, Object?>? _validate(Object? decoded) {
    if (decoded is! Map<String, Object?>) return null;

    final storedVersion = asIntOr(decoded['schemaVersion'], 0);
    if (storedVersion > schemaVersion) return null;
    if (storedVersion < schemaVersion) {
      final registry = migrationRegistry;
      return registry == null
          ? migrate(storedVersion, decoded)
          : registry.migrate(storedVersion, decoded);
    }
    return decoded;
  }

  /// Merges the local save with [provider]'s cloud copy: whichever side
  /// has the newer `syncedAtMs` timestamp wins (simple last-write-wins,
  /// no 3-way merge) — the newer side's data is written to the other.
  /// No-op if neither side has any data yet.
  ///
  /// The cloud payload goes through the exact same [_validate] policy (and
  /// a [fromJson] sanity check) as a local save before it's ever trusted
  /// enough to overwrite local data — a malformed or future-schema cloud
  /// record just leaves the local save untouched instead of corrupting it.
  ///
  /// [onConflict] (ENH-83) is consulted INSTEAD of blind last-write-wins
  /// whenever BOTH local and cloud have valid, DIFFERENT data — same
  /// timestamp (can't tell who's newer) or different timestamps (one side
  /// might just have a drifted device clock, not genuinely newer data) are
  /// both exactly the case where trusting the timestamp alone risks
  /// silently discarding a real device's progress. Left `null` (the
  /// default), behavior is byte-for-byte the same last-write-wins as
  /// before this parameter existed — fully backward compatible.
  ///
  /// If [onConflict] itself throws, the error is logged (via [dlog]) and
  /// this falls back to the same last-write-wins default — a broken
  /// handler can never crash a sync or leave it half-applied.
  Future<void> syncWith(
    CloudSaveProvider provider, {
    VersionedSyncConflictHandler<T>? onConflict,
  }) async {
    final cloudJson = _validate(await provider.download());
    final localJson = _readLocalJson();

    final cloudTime = cloudJson == null
        ? -1
        : asIntOr(cloudJson['syncedAtMs'], -1);
    final localTime = localJson == null
        ? -1
        : asIntOr(localJson['syncedAtMs'], -1);

    if (onConflict != null &&
        cloudJson != null &&
        localJson != null &&
        !_sameContent(localJson, cloudJson)) {
      final resolved = await _tryResolveConflict(
        onConflict,
        provider,
        localJson: localJson,
        cloudJson: cloudJson,
        localTime: localTime,
        cloudTime: cloudTime,
      );
      if (resolved) return;
      // Handler threw (already logged) or either side failed to parse as
      // a real T — fall through to the default below.
    }

    if (cloudJson != null && cloudTime > localTime) {
      try {
        fromJson(cloudJson);
      } catch (_) {
        // Passed the envelope-level checks in _validate but still isn't a
        // real T (e.g. a field of the wrong type inside) — don't let it
        // anywhere near local storage.
        return;
      }
      await storage.setString(key, jsonEncode(cloudJson));
    } else if (localJson != null) {
      await provider.upload(localJson);
    }
  }

  /// Returns `true` if the conflict was fully resolved (either side's data
  /// already ends up exactly where [syncWith]'s default path would also
  /// have put it — no further action needed), `false` to fall through to
  /// the default last-write-wins.
  Future<bool> _tryResolveConflict(
    VersionedSyncConflictHandler<T> onConflict,
    CloudSaveProvider provider, {
    required Map<String, Object?> localJson,
    required Map<String, Object?> cloudJson,
    required int localTime,
    required int cloudTime,
  }) async {
    final T localValue;
    final T cloudValue;
    try {
      localValue = fromJson(localJson);
      cloudValue = fromJson(cloudJson);
    } catch (_) {
      return false;
    }

    try {
      final resolution = onConflict(
        VersionedSyncConflict(
          local: VersionedSyncConflictSide(value: localValue, syncedAtMs: localTime),
          cloud: VersionedSyncConflictSide(value: cloudValue, syncedAtMs: cloudTime),
        ),
      );
      switch (resolution.strategy) {
        case VersionedSyncConflictStrategy.preferLocal:
          await provider.upload(localJson);
          return true;
        case VersionedSyncConflictStrategy.preferCloud:
          await storage.setString(key, jsonEncode(cloudJson));
          return true;
        case VersionedSyncConflictStrategy.merge:
          final merged = {
            ...toJson(resolution.mergedValue as T),
            'schemaVersion': schemaVersion,
            'syncedAtMs': nowMsClamped(storage),
          };
          await storage.setString(key, jsonEncode(merged));
          await provider.upload(merged);
          return true;
      }
    } catch (error) {
      dlog(
        'VersionedJsonStore.syncWith: onConflict handler threw, falling '
        'back to last-write-wins: $error',
      );
      return false;
    }
  }

  /// Deep-equal comparison of 2 already-[_validate]d JSON envelopes,
  /// ignoring `syncedAtMs` — 2 saves with identical content but different
  /// save timestamps (the common case: re-saving unchanged data) are NOT a
  /// conflict, so [onConflict] shouldn't fire for them.
  static bool _sameContent(
    Map<String, Object?> a,
    Map<String, Object?> b,
  ) {
    Map<String, Object?> withoutTimestamp(Map<String, Object?> json) =>
        Map.of(json)..remove('syncedAtMs');
    return _jsonEquals(withoutTimestamp(a), withoutTimestamp(b));
  }

  static bool _jsonEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final entry in a.entries) {
        if (!b.containsKey(entry.key) ||
            !_jsonEquals(entry.value, b[entry.key])) {
          return false;
        }
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_jsonEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
