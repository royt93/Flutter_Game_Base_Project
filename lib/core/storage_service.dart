import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'debug_log.dart';

class StorageKeys {
  StorageKeys._();

  static const String localeCode = 'locale_code';
  static const String audioMuted = 'audio_muted';
  static const String themeDark = 'theme_dark';
  static const String colorBlindSafe = 'color_blind_safe';
  static const String wakeLockEnabled = 'wake_lock_enabled';

  // 4 extra keys beyond the base project's own 3: lib/core/haptics.dart and
  // lib/core/utils/clamped_clock.dart read/write them directly.
  static const String hapticsEnabled = 'haptics_enabled';
  static const String hapticSoftMode = 'haptic_soft_mode';
  static const String maxEpochDaySeen = 'max_epoch_day_seen';
  static const String maxMsSeen = 'max_ms_seen';

  // lib/core/energy_service.dart reads/writes these directly.
  //
  // energyCount/energyLastMs are the LEGACY (pre-BUG-19) two-key format —
  // kept only so EnergyService can migrate an old save on first read. New
  // writes go to energyStateV1 (one JSON blob, one write — see BUG-19: two
  // separate fire-and-forget writes for count/lastMs could leave a mixed
  // checkpoint if the app died between them).
  static const String energyCount = 'energy_count';
  static const String energyLastMs = 'energy_last_ms';
  static const String energyStateV1 = 'energy_state_v1';
  static const String energyInfiniteUntilMs = 'energy_infinite_until_ms';

  // lib/core/offline_progression_service.dart reads/writes this directly.
  static const String offlineLastClaimedMs = 'offline_last_claimed_ms';

  // lib/core/in_app_review_helper.dart reads/writes this directly.
  static const String reviewLastAskedMs = 'review_last_asked_ms';

  // lib/core/experiment_bucketing_service.dart reads/writes this directly.
  static const String experimentAnonId = 'experiment_anon_id';

  // lib/core/utils/trusted_clock.dart reads/writes these directly.
  static const String trustedClockBaselineMs = 'trusted_clock_baseline_ms';
  static const String trustedClockPrevWallMs = 'trusted_clock_prev_wall_ms';
  static const String trustedClockPrevMonotonicMs =
      'trusted_clock_prev_monotonic_ms';

  // lib/core/persistent_cooldown_service.dart reads/writes this directly.
  static const String cooldownStateV1 = 'cooldown_state_v1';

  // lib/core/consent_state_service.dart reads/writes this directly.
  static const String consentStateV1 = 'consent_state_v1';

  // lib/core/app_version_gate.dart reads/writes this directly.
  static const String appVersionSoftPromptLastMs =
      'app_version_soft_prompt_last_ms';

  // lib/core/app_session_tracker.dart reads/writes these directly.
  static const String appSessionInstallTimeMs = 'app_session_install_time_ms';
  static const String appSessionSequence = 'app_session_sequence';
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
  ///
  /// Writes go straight to `_prefs`/`_fallback` here — **never** through the
  /// public `setInt`/`setString`/... setters, which unconditionally clear
  /// `_buffer[key]` as their first step (correct for a real direct write,
  /// which must always win over a stale buffered value). If flush's own
  /// write for key A used those setters, and a NEW `setXBuffered` call for a
  /// later key B in this same batch lands while A's disk write is still
  /// awaiting, the loop would reach B's `setX` call, unconditionally wipe
  /// that brand-new buffered value from `_buffer`, then persist the STALE
  /// snapshot taken before this flush started — silently losing the update.
  /// Writing directly here means `_buffer` (already cleared above) is never
  /// touched again mid-flush, so any value buffered during a flush simply
  /// survives untouched for the next flush to pick up.
  Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final pending = Map<String, Object>.from(_buffer);
    _buffer.clear();
    for (final entry in pending.entries) {
      await _writeDirect(entry.key, entry.value);
    }
  }

  Future<void> _writeDirect(String key, Object value) async {
    platformWrites++;
    final prefs = _prefs;
    if (prefs != null) {
      switch (value) {
        case int v:
          await prefs.setInt(key, v);
        case String v:
          await prefs.setString(key, v);
        case bool v:
          await prefs.setBool(key, v);
        case double v:
          await prefs.setDouble(key, v);
      }
      return;
    }
    _fallback[key] = value;
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
        dlog('importAll rollback thất bại: $rollbackError');
      }
      rethrow;
    }
  }

  /// Wipes every key currently in storage — the classic "Reset progress"
  /// Settings action. A thin, self-explanatory name over what
  /// `importAll(const {})` already did silently: [importAll] REPLACES the
  /// whole profile (see [_replaceAll]), so an empty map means "keep
  /// nothing" — but a consumer app had to know that trick rather than see
  /// an API that says what it does. Same rollback-on-error guarantee as
  /// [importAll]: a failure partway through leaves storage exactly as it
  /// was before this call, never half-erased.
  Future<void> eraseAll() => importAll(const {});

  /// Removes every key currently in storage that starts with [prefix] —
  /// e.g. deleting one save slot's namespaced keys (IDEA-56) without
  /// touching any other slot's.
  ///
  /// BUG-39: this used to go through [importAll]/[_replaceAll], which
  /// erases and rewrites EVERY key in storage (not just ones matching
  /// [prefix]) to reach the "current data minus the matching keys"
  /// end-state — an OS low-memory-kill or hardware crash partway through
  /// that native delete loop could wipe the WHOLE profile, not just the
  /// one slot being removed (rollback-on-error only survives a thrown
  /// Dart exception, never a killed process — see [importAll]'s doc and
  /// `doc/task/done/IDEA-55-storage-service-erase-all.md`). Removing only
  /// the matching keys directly makes the blast radius of that same
  /// unrecoverable failure exactly the [prefix] being deleted, same as
  /// before this call was ever made.
  ///
  /// [prefix] must not be empty — an empty prefix would match every key,
  /// silently behaving like [eraseAll] under a name that doesn't say so;
  /// callers that actually want that should call [eraseAll] explicitly.
  Future<void> removeAllWithPrefix(String prefix) async {
    if (prefix.isEmpty) {
      throw ArgumentError.value(prefix, 'prefix', 'must not be empty');
    }
    _buffer.removeWhere((key, _) => key.startsWith(prefix));
    final prefs = _prefs;
    if (prefs != null) {
      for (final key
          in prefs.getKeys().where((k) => k.startsWith(prefix)).toList()) {
        await prefs.remove(key);
      }
    } else {
      _fallback.removeWhere((key, _) => key.startsWith(prefix));
    }
  }

  /// Every key currently in storage that starts with [prefix] — e.g.
  /// backing up/cloud-syncing just one save slot's namespaced keys
  /// (IDEA-56) without capturing any other slot's. [prefix] must not be
  /// empty — same reasoning as [removeAllWithPrefix]: an empty prefix
  /// would just be [exportAll] under a name that doesn't say so.
  Map<String, Object> exportWithPrefix(String prefix) {
    if (prefix.isEmpty) {
      throw ArgumentError.value(prefix, 'prefix', 'must not be empty');
    }
    return {
      for (final entry in exportAll().entries)
        if (entry.key.startsWith(prefix)) entry.key: entry.value,
    };
  }

  /// Restores [data] as the complete set of keys under [prefix], leaving
  /// every OTHER key untouched — the write-side counterpart of
  /// [exportWithPrefix]. A key already under [prefix] but missing from
  /// [data] is removed (mirrors [importAll] REPLACING a profile, scoped
  /// to just this prefix). Every key in [data] must start with [prefix]
  /// — guards against a caller accidentally restoring another slot's
  /// backup into this one. Built on [importAll], so the same
  /// rollback-on-error guarantee applies.
  Future<void> importWithPrefix(String prefix, Map<String, Object?> data) {
    if (prefix.isEmpty) {
      throw ArgumentError.value(prefix, 'prefix', 'must not be empty');
    }
    if (data.keys.any((key) => !key.startsWith(prefix))) {
      throw ArgumentError.value(
        data,
        'data',
        'every key must start with $prefix',
      );
    }
    final merged = <String, Object?>{
      for (final entry in exportAll().entries)
        if (!entry.key.startsWith(prefix)) entry.key: entry.value,
      ...data,
    };
    return importAll(merged);
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
