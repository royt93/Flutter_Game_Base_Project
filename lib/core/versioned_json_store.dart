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
  /// [value] is already parsed through the store's `fromJson`.
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
enum VersionedSyncConflictStrategy {
  /// Keep local data and upload it to the cloud.
  preferLocal,

  /// Overwrite local storage with the cloud copy.
  preferCloud,

  /// Write a caller-built value to both local storage and the cloud.
  merge,
}

/// What an [onConflict] handler decided to do about a [VersionedSyncConflict] —
/// built via one of the 3 named constructors, never directly.
class VersionedSyncConflictResolution<T> {
  /// Keep the local save; it is uploaded and the cloud copy is replaced.
  const VersionedSyncConflictResolution.preferLocal()
    : strategy = VersionedSyncConflictStrategy.preferLocal,
      mergedValue = null;

  /// Take the cloud copy; its validated (and, if older, migrated) envelope
  /// replaces the local save.
  const VersionedSyncConflictResolution.preferCloud()
    : strategy = VersionedSyncConflictStrategy.preferCloud,
      mergedValue = null;

  /// Neither side wins outright — [value] (built by the caller, e.g. by
  /// combining fields from both [VersionedSyncConflict.local]/[VersionedSyncConflict.cloud])
  /// becomes the new value on BOTH local storage and the cloud.
  const VersionedSyncConflictResolution.merge(T value)
    : strategy = VersionedSyncConflictStrategy.merge,
      mergedValue = value;

  /// The chosen resolution kind.
  final VersionedSyncConflictStrategy strategy;

  /// The caller-built value; only set for [VersionedSyncConflictStrategy.merge].
  final T? mergedValue;
}

/// Caller-supplied conflict handler for [VersionedJsonStore.syncWith] —
/// see that method's doc for exactly when this is invoked, and its
/// exception-safety contract.
typedef VersionedSyncConflictHandler<T> =
    VersionedSyncConflictResolution<T> Function(
      VersionedSyncConflict<T> conflict,
    );

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
  /// [storage] and [key] locate the save; [schemaVersion] is the current
  /// shape's version, stamped on every [save]. [toJson]/[fromJson] convert [T]
  /// to and from a JSON map. [migrate] upgrades an older map, unless
  /// [migrationRegistry] is given, in which case the registry's multi-hop
  /// chain is used instead and [migrate] is never called.
  VersionedJsonStore({
    required this.storage,
    required this.key,
    required this.schemaVersion,
    required this.toJson,
    required this.fromJson,
    required this.migrate,
    this.migrationRegistry,
  });

  /// Backing key-value store; also the clock source for `syncedAtMs`.
  final StorageService storage;

  /// Storage key the JSON envelope is persisted under.
  final String key;

  /// Current schema version; stored saves with a higher version are rejected.
  final int schemaVersion;

  /// Serializes [T] to a JSON map. [save] adds `schemaVersion`/`syncedAtMs`.
  final Map<String, Object?> Function(T value) toJson;

  /// Builds [T] from a map already at [schemaVersion]; it may throw on a
  /// wrong-typed field (see [loadResult]).
  final T Function(Map<String, Object?> json) fromJson;

  /// Upgrades a JSON map saved under an older [fromVersion] to a shape
  /// [fromJson] can read. Not called when the stored data is already at
  /// [schemaVersion].
  final Map<String, Object?> Function(
    int fromVersion,
    Map<String, Object?> json,
  )
  migrate;

  /// Optional multi-hop migration chain; when set it replaces [migrate].
  final SaveMigrationRegistry? migrationRegistry;

  /// Persists [value] as a JSON envelope tagged with the current
  /// [schemaVersion] and a clamped `syncedAtMs` (used for last-write-wins in
  /// [syncWith]). Uses the unbuffered `setString`, so the write is not lost on
  /// a kill.
  ///
  /// BUG-141: if the raw value currently stored under [key] exists but is not
  /// usable (corrupt JSON, a NEWER schema, a failing migration), it is first
  /// copied to [backupKey] instead of being silently overwritten, so a
  /// downgrade or a migration bug cannot destroy the player's only copy. One
  /// backup is kept: a later unusable value replaces it.
  Future<void> save(T value) async {
    // Not awaited unless a backup is needed: callers rely on an ordinary save
    // starting its write synchronously (an `await` here would defer it).
    final backup = _backupIfUnreadable();
    if (backup != null) await backup;
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

  /// How far ahead of this device's clock a cloud `syncedAtMs` may be before
  /// it stops winning last-write-wins (BUG-142): 24 hours of clock skew.
  static const int maxCloudClockSkewMs = 24 * 60 * 60 * 1000;

  /// Storage key holding the last unusable raw value [save] replaced (BUG-141).
  String get backupKey => '$key.bak';

  Future<void>? _backupIfUnreadable() {
    final raw = storage.getString(key);
    if (raw == null || raw.isEmpty || _readLocalJson() != null) return null;
    return storage.setString(backupKey, raw);
  }

  Map<String, Object?>? _readBackupJson() {
    final raw = storage.getString(backupKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return _validate(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// `true` if [save] has set aside an unusable value (see [backupKey]).
  bool get hasBackup => storage.getString(backupKey)?.isNotEmpty ?? false;

  /// Reads the backup through the same schema policy as [load] (older
  /// `schemaVersion` migrated, newer or corrupt rejected). `null` when there is
  /// no backup or it is still not usable, e.g. a save from a newer app version
  /// read by the older app that backed it up: try again after updating.
  T? loadBackup() {
    final json = _readBackupJson();
    if (json == null) return null;
    try {
      return fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Makes the backup the live save and clears the backup. Returns `false`,
  /// changing nothing, when [loadBackup] would return `null`. This REPLACES the
  /// current save, so ask the player first when one exists.
  Future<bool> restoreBackup() async {
    final value = loadBackup();
    if (value == null) return false;
    await save(value);
    await storage.remove(backupKey);
    return true;
  }

  /// Returns `null` if nothing has been saved yet, or if what's saved
  /// isn't safely usable (see the class doc's trust-boundary policy). Does not
  /// catch a throwing [fromJson]; use [loadResult] when that is possible.
  T? load() {
    final json = _readLocalJson();
    if (json == null) return null;
    return fromJson(json);
  }

  /// Like [load] but typed. Returns an [SdkFailure] of kind
  /// [SdkErrorKind.storage] (marked non-retryable) when nothing usable is
  /// saved, and also one carrying the cause when [fromJson] throws on a
  /// structurally valid envelope — the case where [load] itself would let the
  /// exception propagate.
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
      final migrated = registry == null
          ? migrate(storedVersion, decoded)
          : registry.migrate(storedVersion, decoded);
      // BUG-111: a migrate step is free to rebuild the map from scratch, which
      // used to drop the envelope keys. Losing `syncedAtMs` made the cloud copy
      // read as timestamp -1, so it lost last-write-wins to an empty local save
      // and was never restored; losing `schemaVersion` made the stored copy
      // read as version 0 on the next load and get migrated a second time.
      // Restore both from the source (schemaVersion becomes the current one).
      final synced = decoded['syncedAtMs'];
      return {
        ...migrated,
        if (synced != null && !migrated.containsKey('syncedAtMs'))
          'syncedAtMs': synced,
        'schemaVersion': schemaVersion,
      };
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
  ///
  /// BUG-84: kept `Future<void>` (unchanged, non-breaking) — a genuine
  /// network failure is now caught internally (see [syncWithResult]) and
  /// logged rather than thrown, instead of crashing whatever called this.
  /// A caller that needs to know WHETHER the sync actually succeeded should
  /// call [syncWithResult] instead.
  Future<void> syncWith(
    CloudSaveProvider provider, {
    VersionedSyncConflictHandler<T>? onConflict,
  }) async {
    await syncWithResult(provider, onConflict: onConflict);
  }

  /// Same merge as [syncWith], but reports whether it actually succeeded
  /// instead of silently swallowing a transport failure.
  ///
  /// BUG-84: [CloudSaveProvider.download]/`upload` are real network calls
  /// this class doesn't control — before this, `download()` throwing
  /// (offline, timeout, server error) propagated straight out of `syncWith`
  /// as an unhandled exception, even though every OTHER failure path in
  /// this method already degrades gracefully (a malformed cloud payload,
  /// a broken [onConflict] handler). Both are now caught and reported as
  /// `SdkFailure(kind: SdkErrorKind.network)` instead.
  Future<SdkResult<void>> syncWithResult(
    CloudSaveProvider provider, {
    VersionedSyncConflictHandler<T>? onConflict,
  }) async {
    final Map<String, Object?>? cloudRaw;
    try {
      cloudRaw = await provider.download();
    } catch (error, stack) {
      return SdkFailure(
        kind: SdkErrorKind.network,
        message: 'Cloud download failed',
        cause: error,
        stackTrace: stack,
      );
    }
    final cloudJson = _validate(cloudRaw);
    final localJson = _readLocalJson();

    final localTime = localJson == null
        ? -1
        : asIntOr(localJson['syncedAtMs'], -1);
    final cloudTime = cloudJson == null
        ? -1
        : asIntOr(cloudJson['syncedAtMs'], -1);
    // BUG-142: a cloud stamp far in the future would win last-write-wins on
    // every later sync and keep overwriting honest local saves. With a local
    // save present it never wins by timestamp alone (the [onConflict] handler,
    // below, still sees the real value); with nothing local there is nothing
    // to lose, so it may still restore.
    final cloudWinsByTime =
        cloudTime > localTime &&
        !(localJson != null &&
            cloudTime > nowMsClamped(storage) + maxCloudClockSkewMs);

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
      if (resolved != null) return resolved;
    }

    if (cloudJson != null && cloudWinsByTime) {
      try {
        fromJson(cloudJson);
      } catch (_) {
        // Passed the envelope-level checks in _validate but still isn't a
        // real T (e.g. a field of the wrong type inside) — don't let it
        // anywhere near local storage.
        return const SdkSuccess(null);
      }
      await _backupIfUnreadable();
      await storage.setString(key, jsonEncode(cloudJson));
    } else if (localJson != null) {
      try {
        await provider.upload(localJson);
      } catch (error, stack) {
        return SdkFailure(
          kind: SdkErrorKind.network,
          message: 'Cloud upload failed',
          cause: error,
          stackTrace: stack,
        );
      }
    }
    return const SdkSuccess(null);
  }

  /// Returns `SdkSuccess(null)` if the conflict was fully resolved,
  /// `SdkFailure` if an underlying storage or upload call failed, or
  /// `null` to fall through to the default last-write-wins (e.g. handler threw).
  Future<SdkResult<void>?> _tryResolveConflict(
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
      return null;
    }

    final VersionedSyncConflictResolution<T> resolution;
    try {
      resolution = onConflict(
        VersionedSyncConflict(
          local: VersionedSyncConflictSide(
            value: localValue,
            syncedAtMs: localTime,
          ),
          cloud: VersionedSyncConflictSide(
            value: cloudValue,
            syncedAtMs: cloudTime,
          ),
        ),
      );
    } catch (error) {
      dlog(
        'VersionedJsonStore.syncWith: onConflict handler threw, falling '
        'back to last-write-wins: $error',
      );
      return null;
    }

    var failureKind = SdkErrorKind.storage;
    try {
      switch (resolution.strategy) {
        case VersionedSyncConflictStrategy.preferLocal:
          failureKind = SdkErrorKind.network;
          await provider.upload(localJson);
          return const SdkSuccess(null);
        case VersionedSyncConflictStrategy.preferCloud:
          failureKind = SdkErrorKind.storage;
          await storage.setString(key, jsonEncode(cloudJson));
          return const SdkSuccess(null);
        case VersionedSyncConflictStrategy.merge:
          final merged = {
            ...toJson(resolution.mergedValue as T),
            'schemaVersion': schemaVersion,
            'syncedAtMs': nowMsClamped(storage),
          };
          failureKind = SdkErrorKind.storage;
          await storage.setString(key, jsonEncode(merged));
          failureKind = SdkErrorKind.network;
          await provider.upload(merged);
          return const SdkSuccess(null);
      }
    } catch (error, stack) {
      return SdkFailure(
        kind: failureKind,
        message: 'Conflict resolution failed: $error',
        cause: error,
        stackTrace: stack,
      );
    }
  }

  /// Deep-equal comparison of 2 already-[_validate]d JSON envelopes,
  /// ignoring `syncedAtMs` — 2 saves with identical content but different
  /// save timestamps (the common case: re-saving unchanged data) are NOT a
  /// conflict, so [onConflict] shouldn't fire for them.
  static bool _sameContent(Map<String, Object?> a, Map<String, Object?> b) {
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
