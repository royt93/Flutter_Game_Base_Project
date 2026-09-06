import 'dart:convert';

import 'cloud_save_provider.dart';
import 'storage_service.dart';

/// A thin, versioned JSON object store on top of [StorageService]'s plain
/// key-value strings — for save data with actual shape (player profile,
/// level progress) that needs to survive a schema change between game
/// versions without losing old players' data.
///
/// Not a schema itself: callers supply [toJson]/[fromJson] for their own
/// [T], and a [migrate] step that upgrades an old JSON map (tagged with the
/// `schemaVersion` it was saved under) to the current shape before
/// [fromJson] ever sees it.
class VersionedJsonStore<T> {
  VersionedJsonStore({
    required this.storage,
    required this.key,
    required this.schemaVersion,
    required this.toJson,
    required this.fromJson,
    required this.migrate,
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

  Future<void> save(T value) async {
    final json = {
      ...toJson(value),
      'schemaVersion': schemaVersion,
      'syncedAtMs': DateTime.now().millisecondsSinceEpoch,
    };
    await storage.setString(key, jsonEncode(json));
  }

  /// Returns `null` if nothing has been saved yet under [key].
  T? load() {
    final json = _readLocalJson();
    if (json == null) return null;
    return fromJson(json);
  }

  Map<String, Object?>? _readLocalJson() {
    final raw = storage.getString(key);
    if (raw == null || raw.isEmpty) return null;

    var json = jsonDecode(raw) as Map<String, Object?>;
    final storedVersion = json['schemaVersion'] as int? ?? 0;
    if (storedVersion < schemaVersion) {
      json = migrate(storedVersion, json);
    }
    return json;
  }

  /// Merges the local save with [provider]'s cloud copy: whichever side
  /// has the newer `syncedAtMs` timestamp wins (simple last-write-wins,
  /// no 3-way merge) — the newer side's data is written to the other.
  /// No-op if neither side has any data yet.
  Future<void> syncWith(CloudSaveProvider provider) async {
    final cloudJson = await provider.download();
    final localJson = _readLocalJson();

    final cloudTime = cloudJson?['syncedAtMs'] as int? ?? -1;
    final localTime = localJson?['syncedAtMs'] as int? ?? -1;

    if (cloudJson != null && cloudTime > localTime) {
      await storage.setString(key, jsonEncode(cloudJson));
    } else if (localJson != null) {
      await provider.upload(localJson);
    }
  }
}
