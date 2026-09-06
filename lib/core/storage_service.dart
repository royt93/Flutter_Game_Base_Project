import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'debug_log.dart';

class StorageKeys {
  StorageKeys._();

  static const String localeCode = 'locale_code';
  static const String audioMuted = 'audio_muted';
  static const String themeDark = 'theme_dark';

  // 4 extra keys beyond the base project's own 3: lib/core/haptics.dart and
  // lib/core/utils/clamped_clock.dart read/write them directly.
  static const String hapticsEnabled = 'haptics_enabled';
  static const String hapticSoftMode = 'haptic_soft_mode';
  static const String maxEpochDaySeen = 'max_epoch_day_seen';
  static const String maxMsSeen = 'max_ms_seen';
}

/// Shared local storage service (wraps SharedPreferences).
/// Registered once in main: `Get.put(StorageService(prefs), permanent: true)`.
///
/// [_prefs] is null when `SharedPreferences.getInstance()` fails at boot
/// (rare devices, corrupted storage) — the in-memory [_fallback] is used so
/// the app can still run with safe default values instead of a hard crash
/// (it doesn't persist across sessions, but that's a tradeoff to fix later,
/// not a crash).
class StorageService extends GetxService {
  final SharedPreferences? _prefs;
  final Map<String, Object> _fallback = {};
  StorageService(this._prefs);

  static StorageService get to => Get.find<StorageService>();

  /// Safe to call from a standalone widget test that hasn't registered the
  /// service (e.g. small effect widgets like confetti/mascot/pulse-glow
  /// tested in isolation).
  static StorageService? get maybe =>
      Get.isRegistered<StorageService>() ? Get.find<StorageService>() : null;

  /// Count of actual `SharedPreferences` hits (platform channel + disk
  /// write). Incremented on every `setX` that does **not** go through the
  /// buffer, and on every key [flush] pushes down.
  ///
  /// Exists to make this deterministically testable instead of having to
  /// hand-profile on a device when a hot path (e.g. a counter written on
  /// every tap in gameplay) accidentally writes straight to disk repeatedly
  /// instead of going through the buffer. One `int++` is negligible at
  /// runtime, in exchange for a permanent regression guard.
  int platformWrites = 0;

  /// Write-behind buffer for hot paths. Values written via `setXBuffered`
  /// live here until [flush] pushes them down to disk in one batch.
  ///
  /// **Every read path must check the buffer BEFORE `_prefs`** — otherwise a
  /// value just written but not yet flushed would read back as the old
  /// number. That's the main trap of this kind of optimization, so
  /// [getInt]/[getBool]/[getString]/[getDouble]/[allKeys]/[exportAll] all
  /// handle it, and [remove]/[importAll] clear the buffer.
  ///
  /// ONLY use this for hot-path counters (e.g. a counter written on every
  /// tap in gameplay). Real transactions — purchases, reward grants, resets
  /// — must write immediately via the regular `setX`: losing them if the app
  /// is killed means losing the player's money/items.
  final Map<String, Object> _buffer = {};

  Future<void> setIntBuffered(String key, int value) async =>
      _buffer[key] = value;

  Future<void> setStringBuffered(String key, String value) async =>
      _buffer[key] = value;

  /// Pushes every buffered value down to disk. Call this at safe
  /// checkpoints: level end, app going to background, controller disposal,
  /// and before any transaction that grants a reward.
  Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final pending = Map<String, Object>.from(_buffer);
    _buffer.clear();
    for (final entry in pending.entries) {
      final value = entry.value;
      if (value is int) {
        await setInt(entry.key, value);
      } else if (value is String) {
        await setString(entry.key, value);
      } else if (value is bool) {
        await setBool(entry.key, value);
      } else if (value is double) {
        await setDouble(entry.key, value);
      }
    }
  }

  /// Reads the raw value then **checks its type**, instead of casting directly.
  ///
  /// The old version used `_prefs.getInt(key)` / `as int?`, both of which
  /// throw a `TypeError` if the key holds a different type (a String where
  /// an int was expected). Once real state hydrates dozens of keys in the
  /// `onInit()` of a `permanent: true` singleton set up right in
  /// `main.dart`, a single wrong-typed key means **the app can't boot** —
  /// the player has to uninstall.
  ///
  /// A real entry point for this: [importAll] only checks that values are
  /// int/bool/double/String, it does NOT check that each key holds the type
  /// it's expected to — a corrupted backup or a hand-edited one containing
  /// `"coins": "abc"` is enough to trigger this.
  ///
  /// Wrong type → returns the default, exactly as if the key didn't exist.
  /// Fixing it here covers **every** key at once, instead of wrapping
  /// try/catch around each hydration call site.
  Object? _raw(String key) =>
      _buffer[key] ?? _prefs?.get(key) ?? _fallback[key];

  int getInt(String key, {int def = 0}) {
    final v = _raw(key);
    return v is int ? v : def;
  }

  /// A direct write must **invalidate the buffered copy** of the same key.
  /// Without this line, the stale buffered value would still shadow the
  /// result in `_raw`, and the next [flush] would overwrite it right back
  /// down to disk — an undo, reset, purchase, or import would silently have
  /// no effect if that key had ever gone through the hot path.
  Future<void> setInt(String key, int value) async {
    _buffer.remove(key);
    platformWrites++;
    if (_prefs != null) {
      await _prefs.setInt(key, value);
      return;
    }
    _fallback[key] = value;
  }

  bool getBool(String key, {bool def = false}) {
    final v = _raw(key);
    return v is bool ? v : def;
  }

  /// See the note on [setInt].
  Future<void> setBool(String key, bool value) async {
    _buffer.remove(key);
    platformWrites++;
    if (_prefs != null) {
      await _prefs.setBool(key, value);
      return;
    }
    _fallback[key] = value;
  }

  double getDouble(String key, {double def = 0.0}) {
    final v = _raw(key);
    return v is double ? v : def;
  }

  /// See the note on [setInt].
  Future<void> setDouble(String key, double value) async {
    _buffer.remove(key);
    platformWrites++;
    if (_prefs != null) {
      await _prefs.setDouble(key, value);
      return;
    }
    _fallback[key] = value;
  }

  String? getString(String key) {
    final v = _raw(key);
    return v is String ? v : null;
  }

  /// See the note on [setInt].
  Future<void> setString(String key, String value) async {
    _buffer.remove(key);
    platformWrites++;
    if (_prefs != null) {
      await _prefs.setString(key, value);
      return;
    }
    _fallback[key] = value;
  }

  /// Reads a JSON list (unlike the CSV-join pattern of other keys in this
  /// file) — used for keys that need to store a list of strings instead of
  /// a single value.
  List<String> getStringList(String key) {
    final raw = getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> setStringList(String key, List<String> value) =>
      setString(key, jsonEncode(value));

  Future<void> remove(String key) async {
    // Xoá cả bản đang đệm, nếu không thì giá trị chưa flush sẽ "sống lại"
    // ở lần đọc kế tiếp dù key đã bị xoá khỏi đĩa.
    _buffer.remove(key);
    if (_prefs != null) {
      await _prefs.remove(key);
      return;
    }
    _fallback.remove(key);
  }

  /// Every key currently in storage. Same reasoning as [exportAll] — uses
  /// the generic API instead of hand-listing `StorageKeys`, so there's no
  /// place that must remember to update a hand-written list every time a
  /// new key is added (that kind of hand-written list drifts out of date
  /// very easily across a few rounds of code review).
  Set<String> allKeys() => {
    ...?_prefs?.getKeys(),
    ..._fallback.keys,
    ..._buffer.keys,
  };

  /// Dumps all current storage into a map — uses SharedPreferences's
  /// generic API (getKeys/get) instead of hand-listing every StorageKeys
  /// entry, so this list doesn't need updating every time a new key is added.
  Map<String, Object> exportAll() {
    final prefs = _prefs;
    // Giá trị đang đệm phải đè lên bản trên đĩa — backup/export đọc qua
    // đây và cần trạng thái mới nhất, kể cả phần chưa flush.
    if (prefs == null) return {..._fallback, ..._buffer};
    return {
      for (final k in prefs.getKeys()) k: prefs.get(k) as Object,
      ..._buffer,
    };
  }

  /// Overwrites storage from an exported map. Values can only be
  /// int/bool/double/String (StorageService never sets a List directly on
  /// SharedPreferences — [setStringList] JSON-encodes it to a String itself).
  Future<void> importAll(Map<String, Object?> data) async {
    if (data.values.any(
      (value) =>
          value is! int &&
          value is! bool &&
          value is! double &&
          value is! String,
    )) {
      throw const FormatException('Unsupported backup value type');
    }
    final normalized = <String, Object>{
      for (final entry in data.entries) entry.key: entry.value!,
    };
    final previous = exportAll();
    // Import ghi đè toàn bộ profile — mọi giá trị đang đệm không còn ý
    // nghĩa và sẽ ghi đè ngược lên dữ liệu vừa khôi phục nếu flush sau đó.
    _buffer.clear();
    try {
      await _replaceAll(normalized);
    } catch (error) {
      // SharedPreferences has no transaction primitive. Re-apply the
      // snapshot so a partial write cannot leave a half-restored profile.
      try {
        await _replaceAll(previous);
      } catch (rollbackError) {
        // Preserve the original failure; callers still show a restore error.
        dlog('roy93~ importAll rollback thất bại: $rollbackError');
      }
      rethrow;
    }
  }

  Future<void> _replaceAll(Map<String, Object> data) async {
    final prefs = _prefs;
    if (prefs != null) {
      for (final key in prefs.getKeys().toList()) {
        await prefs.remove(key);
      }
    } else {
      _fallback.clear();
    }
    for (final entry in data.entries) {
      final value = entry.value;
      switch (value) {
        case int v:
          await setInt(entry.key, v);
        case bool v:
          await setBool(entry.key, v);
        case double v:
          await setDouble(entry.key, v);
        case String v:
          await setString(entry.key, v);
      }
    }
  }
}
