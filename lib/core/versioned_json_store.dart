import 'dart:convert';

import 'cloud_save_provider.dart';
import 'storage_service.dart';
import 'utils/clamped_clock.dart';
import 'utils/safe_json.dart';
import 'utils/save_migration_registry.dart';

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
  Future<void> syncWith(CloudSaveProvider provider) async {
    final cloudJson = _validate(await provider.download());
    final localJson = _readLocalJson();

    final cloudTime = cloudJson == null
        ? -1
        : asIntOr(cloudJson['syncedAtMs'], -1);
    final localTime = localJson == null
        ? -1
        : asIntOr(localJson['syncedAtMs'], -1);

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
}
