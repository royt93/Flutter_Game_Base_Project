import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'save_integrity.dart';
import 'storage_service.dart';
import 'utils/clamped_clock.dart';
import 'utils/safe_json.dart';

/// A typed, signed remote content slot — live-ops content (a level
/// definition, a shop catalog page, an event schedule) pushed from a
/// server without an app-store review cycle, built on the same 3 pieces
/// [RemoteConfigService], [VersionedJsonStore] and `save_integrity.dart`
/// already provide separately (IDEA-37): asset-fallback-then-fetch,
/// schema-version migration, and HMAC signing.
///
/// [load] always resolves from the bundled asset first — never network-
/// gated — so [current] has something usable the instant [load] returns.
/// If [fetchRemote] is given, a fetch is kicked off in the background and
/// [current] is swapped in-place once it resolves; callers that care
/// about that exact moment (mostly tests) can await [refreshed].
///
/// A fetched envelope is rejected — silently, keeping whatever [current]
/// already was — instead of applied when: the signature doesn't verify
/// (or [contentSecret] wasn't supplied at all, in which case an envelope
/// carrying a signature can never be trusted since there's no key
/// configured to check it against), its `schemaVersion` is newer than
/// this pack's own (a downgraded app being handed a shape it can't read),
/// or [fromJson] throws on it (a right-shaped-but-wrong-typed field).
/// Never crashes and never applies unverified content.
class RemoteContentPack<T> {
  /// Legacy/source-compatible constructor — cache disabled, byte-for-byte
  /// the same public signature and behavior as before ENH-94. Use
  /// [RemoteContentPack.withCache] to opt into persistence.
  RemoteContentPack({
    required this.assetPath,
    required this.schemaVersion,
    required this.fromJson,
    this.migrate,
    this.contentSecret,
    this.fetchRemote,
    AssetBundle? bundle,
  }) : storage = null,
       cacheKey = null,
       maxCacheAge = null,
       _bundle = bundle ?? rootBundle;

  /// ENH-94: same signed/typed content pack with a durable verified cache.
  /// Kept as a NAMED constructor (instead of changing [RemoteContentPack]'s
  /// existing signature by adding optional params) so every pre-existing
  /// consumer remains 100% API-gate compatible — additive only, no major
  /// version bump/BREAKING changelog required.
  RemoteContentPack.withCache({
    required this.assetPath,
    required this.schemaVersion,
    required this.fromJson,
    required this.storage,
    required this.cacheKey,
    this.migrate,
    this.contentSecret,
    this.fetchRemote,
    this.maxCacheAge,
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle {
    if (cacheKey == null || cacheKey!.isEmpty) {
      throw ArgumentError.value(cacheKey, 'cacheKey', 'must not be empty');
    }
  }

  final String assetPath;
  final int schemaVersion;
  final T Function(Map<String, Object?> json) fromJson;

  /// Upgrades a JSON map saved under an older [fromVersion] to a shape
  /// [fromJson] can read. Defaults to identity (no-op) — a pack that
  /// never changes shape doesn't need to supply one.
  final Map<String, Object?> Function(
    int fromVersion,
    Map<String, Object?> json,
  )?
  migrate;

  /// Shared secret used to verify a fetched envelope's `_checksum` (see
  /// `save_integrity.dart`). `null` means "don't trust any remote content
  /// for this pack" — a fetched envelope is rejected outright regardless
  /// of what it contains, since there'd be no key to check its signature
  /// against.
  final String? contentSecret;

  final Future<Map<String, Object?>> Function()? fetchRemote;
  final AssetBundle _bundle;

  /// ENH-94: durable cache seam. `null` (default) disables the cache
  /// entirely — [load]/`_refreshFromRemote` behave byte-for-byte as before
  /// this feature existed.
  final StorageService? storage;

  /// Storage key the cache is written/read under. Required whenever
  /// [storage] is provided — see the constructor's `ArgumentError`. Not a
  /// named [StorageKeys] constant (unlike most storage keys in this repo)
  /// because a caller may construct several packs (different content
  /// types/asset paths) that each need their own cache slot; the caller
  /// picks a unique key the same way `SaveSlotManager`/`CheckpointCoordinator`
  /// let callers supply their own scoped key.
  final String? cacheKey;

  /// Optional TTL: a cache entry older than this (by [nowMsClamped]) is
  /// treated as invalid and [load] falls back to the bundled asset instead.
  /// `null` (default) means the cache never expires by age — only rejected
  /// for being tampered/malformed/a future schema version.
  final Duration? maxCacheAge;

  T? _current;

  /// The latest applied content: the asset fallback until (if ever) a
  /// verified fetch replaces it. `null` only if the asset itself was
  /// missing/invalid AND no fetch has applied anything yet.
  T? get current => _current;

  Future<void>? _refreshFuture;

  /// Resolves once the background fetch kicked off by the most recent
  /// [load] call has settled (applied or rejected). `null` if no
  /// [fetchRemote] was ever supplied. Production callers don't need this
  /// — [current] updates in place — it exists for tests that need to
  /// wait deterministically past the background refresh.
  Future<void> get refreshed => _refreshFuture ?? Future.value();

  Future<T?> load() async {
    // ENH-94: a verified cache entry always wins over the bundled asset —
    // it only ever exists after a signature-verified fetch, so its mere
    // presence-and-validity already implies it's live-ops content strictly
    // newer in provenance than what was compiled into the app, regardless
    // of any timestamp on either side (the asset carries none at all).
    if (!_tryLoadFromCache()) {
      try {
        final raw = await _bundle.loadString(assetPath);
        final decoded = jsonDecode(raw);
        final validated = _validateSchema(decoded);
        if (validated != null) _current = fromJson(validated);
      } catch (_) {
        // No bundled asset (or invalid JSON/shape) → _current stays
        // whatever it was (null on first load).
      }
    }

    final fetch = fetchRemote;
    if (fetch != null) _refreshFuture = _refreshFromRemote(fetch);
    return _current;
  }

  /// Returns `true` and applies the cached content to [_current] if a
  /// valid, non-expired cache entry exists — `false` (leaving [_current]
  /// untouched) for every other case: caching disabled, nothing cached
  /// yet, a future schema version, an expired entry, or a corrupt/
  /// wrong-typed entry. Never throws.
  bool _tryLoadFromCache() {
    final store = storage;
    final key = cacheKey;
    if (store == null || key == null) return false;
    final raw = store.getString(key);
    if (raw == null) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final json = decoded.cast<String, Object?>();
      final storedVersion = asIntOr(json['schemaVersion'], 0);
      // A cache entry is always written at exactly the pack's CURRENT
      // schemaVersion (see `_writeCache`) — a newer value here only means
      // the app was downgraded after a newer version wrote this cache.
      // Same "never hand a future shape to fromJson" rule as a fetched
      // envelope.
      if (storedVersion > schemaVersion) return false;
      final maxAge = maxCacheAge;
      if (maxAge != null) {
        final cachedAtMs = asIntOr(json['cachedAtMs'], 0);
        if (nowMsClamped(store) - cachedAtMs > maxAge.inMilliseconds) {
          return false;
        }
      }
      _current = fromJson(json);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Persists already-validated+migrated [json] (never a raw signed
  /// envelope) so a future cold start can skip straight to it instead of
  /// falling back to the bundled asset. Deliberately does NOT catch its own
  /// write failure — see [_refreshFromRemote]'s doc for why a write failure
  /// here must still block applying the new content to [_current].
  Future<void> _writeCache(Map<String, Object?> json) async {
    final store = storage;
    final key = cacheKey;
    if (store == null || key == null) return;
    await store.setString(
      key,
      jsonEncode({
        ...json,
        'schemaVersion': schemaVersion,
        'cachedAtMs': nowMsClamped(store),
      }),
    );
  }

  Future<void> _refreshFromRemote(
    Future<Map<String, Object?>> Function() fetch,
  ) async {
    try {
      final envelope = await fetch();
      final verified = _verifySignature(envelope);
      if (verified == null) return;
      final validated = _validateSchema(verified);
      if (validated == null) return;
      // ENH-94: cache write happens BEFORE `_current` is swapped in — an
      // atomic swap in the sense the task asked for ("ghi xong mới trỏ
      // _current"). If the write throws, this whole try block's catch
      // below catches it too, so `_current` is left untouched rather than
      // pointing at content the disk doesn't actually have a record of.
      await _writeCache(validated);
      _current = fromJson(validated);
    } catch (_) {
      // Network failure, bad signature/schema, a fromJson throw on a
      // wrong-typed field, or a cache-write failure → keep whatever
      // _current already was.
    }
  }

  /// Checks the HMAC on a fetched [envelope]. A pack with no
  /// [contentSecret] configured never trusts a signed envelope — there's
  /// no key to verify it against, so treating it as valid would let
  /// anyone who can intercept/host the response inject unverified content.
  Map<String, Object?>? _verifySignature(Map<String, Object?> envelope) {
    final secret = contentSecret;
    if (secret == null) return null;
    try {
      return verifyAndStrip(envelope, secret);
    } on FormatException {
      return null;
    }
  }

  /// Rejects a future schema version outright (this pack's [migrate], if
  /// any, was only ever written to upgrade FROM older versions); runs
  /// [migrate] when the stored version is older; passes through as-is
  /// when already current.
  Map<String, Object?>? _validateSchema(Object? decoded) {
    if (decoded is! Map) return null;
    final json = decoded.cast<String, Object?>();

    // BUG-37: default 0 for a missing field — matching VersionedJsonStore's
    // own trust-boundary convention exactly. An asset author easily forgets
    // to add schemaVersion on a first-ever authored file; treating "absent"
    // as "already current" (the old default here) would skip migrate
    // entirely and hand fromJson a possibly-stale shape with no signal
    // anything went wrong.
    final storedVersion = asIntOr(json['schemaVersion'], 0);
    if (storedVersion > schemaVersion) return null;
    if (storedVersion < schemaVersion) {
      final migrateFn = migrate;
      if (migrateFn == null) return null;
      return migrateFn(storedVersion, json);
    }
    return json;
  }
}
