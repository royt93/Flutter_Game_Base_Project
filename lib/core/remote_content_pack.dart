import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'save_integrity.dart';
import 'storage_service.dart';
import 'utils/clamped_clock.dart';
import 'utils/safe_json.dart';
import 'utils/sdk_result.dart';

/// One verified, previously-applied content revision (ENH-96) — metadata
/// only, by design: never the content body itself. Exposed via
/// [RemoteContentPack.history] / [RemoteContentPack.diagnosticsSummary] so a
/// support/live-ops investigation can answer "which content version was
/// active when this happened" without ever handing back a player's actual
/// game data (a level layout, a shop catalog, whatever `T` represents).
class ContentPackHistoryEntry {
  const ContentPackHistoryEntry({
    required this.schemaVersion,
    required this.contentVersion,
    required this.checksum,
    required this.appliedAtMs,
  });

  final int schemaVersion;
  final int contentVersion;
  final String checksum;
  final int appliedAtMs;
}

/// Internal pairing of a [ContentPackHistoryEntry]'s metadata with the
/// actual validated+migrated JSON it was applied from — the metadata alone
/// (what [ContentPackHistoryEntry] exposes publicly) isn't enough to
/// reactivate a historical revision via rollback, but the full `json` must
/// never leak into a public getter/diagnostics summary.
class _HistoryRecord {
  const _HistoryRecord({
    required this.schemaVersion,
    required this.contentVersion,
    required this.checksum,
    required this.appliedAtMs,
    required this.json,
  });

  final int schemaVersion;
  final int contentVersion;
  final String checksum;
  final int appliedAtMs;
  final Map<String, Object?> json;

  ContentPackHistoryEntry toEntry() => ContentPackHistoryEntry(
    schemaVersion: schemaVersion,
    contentVersion: contentVersion,
    checksum: checksum,
    appliedAtMs: appliedAtMs,
  );

  Map<String, Object?> toStorageJson() => {
    'schemaVersion': schemaVersion,
    'contentVersion': contentVersion,
    'checksum': checksum,
    'appliedAtMs': appliedAtMs,
    'json': json,
  };

  static _HistoryRecord? fromStorageJson(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<String, Object?>();
    final json = map['json'];
    final checksum = map['checksum'];
    if (json is! Map || checksum is! String) return null;
    return _HistoryRecord(
      schemaVersion: asIntOr(map['schemaVersion'], 0),
      contentVersion: asIntOr(map['contentVersion'], 0),
      checksum: checksum,
      appliedAtMs: asIntOr(map['appliedAtMs'], 0),
      json: json.cast<String, Object?>(),
    );
  }
}

/// Default [RemoteContentPack.contentVersionResolver] — reads
/// `contentVersion` first (the convention this feature introduces), falls
/// back to the older/shorter `version` key some already-authored content
/// may use, defaults to `0` if neither is present (same "untrusted input,
/// never crash" trust-boundary convention `asIntOr` itself documents).
int _defaultContentVersionResolver(Map<String, Object?> json) {
  if (json.containsKey('contentVersion')) {
    return asIntOr(json['contentVersion'], 0);
  }
  if (json.containsKey('version')) return asIntOr(json['version'], 0);
  return 0;
}

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
       historyCapacity = null,
       contentVersionResolver = null,
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
  }) : historyCapacity = null,
       contentVersionResolver = null,
       _bundle = bundle ?? rootBundle {
    if (cacheKey == null || cacheKey!.isEmpty) {
      throw ArgumentError.value(cacheKey, 'cacheKey', 'must not be empty');
    }
  }

  /// ENH-96: adds a bounded, persisted history of previously-applied
  /// VERIFIED revisions on top of [withCache]'s single-slot cache, plus
  /// downgrade rejection and explicit [rollbackToChecksum]/
  /// [rollbackToVersion] — a consumer that doesn't need rollback/audit
  /// history keeps using [withCache] unchanged; this is a strict superset,
  /// additive new constructor (same "new named constructor, never change
  /// an existing one" convention [withCache]'s own doc comment explains).
  ///
  /// Requires [contentSecret] — history/rollback only make sense for
  /// verified content; an unsigned pack has no integrity guarantee to
  /// audit or roll back to.
  RemoteContentPack.withHistory({
    required this.assetPath,
    required this.schemaVersion,
    required this.fromJson,
    required StorageService this.storage,
    required String this.cacheKey,
    required String this.contentSecret,
    this.migrate,
    this.fetchRemote,
    this.maxCacheAge,
    this.historyCapacity = 5,
    int Function(Map<String, Object?> json)? contentVersionResolver,
    AssetBundle? bundle,
  }) : contentVersionResolver =
           contentVersionResolver ?? _defaultContentVersionResolver,
       _bundle = bundle ?? rootBundle {
    if (cacheKey!.isEmpty) {
      throw ArgumentError.value(cacheKey, 'cacheKey', 'must not be empty');
    }
    if (historyCapacity! <= 0) {
      throw ArgumentError.value(
        historyCapacity,
        'historyCapacity',
        'must be > 0',
      );
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

  /// ENH-96 (`withHistory` only): max verified revisions kept in [history],
  /// oldest evicted first once exceeded. `null` for [RemoteContentPack]/
  /// [RemoteContentPack.withCache] — those constructors keep no history at
  /// all.
  final int? historyCapacity;

  /// ENH-96 (`withHistory` only): resolves a fetched envelope's content
  /// revision number — defaults to [_defaultContentVersionResolver]
  /// (`contentVersion`, then `version`, then `0`). Used to reject a
  /// downgrade (an incoming revision numbered lower than
  /// [currentContentVersion]) without touching [_current]/the cache/
  /// [history] at all.
  final int Function(Map<String, Object?> json)? contentVersionResolver;

  final List<_HistoryRecord> _history = [];

  /// Every verified revision currently retained, oldest first, capped at
  /// [historyCapacity] — metadata only (see [ContentPackHistoryEntry]'s
  /// doc), never the content body. Empty for [RemoteContentPack]/
  /// [RemoteContentPack.withCache].
  List<ContentPackHistoryEntry> get history =>
      List.unmodifiable(_history.map((r) => r.toEntry()));

  /// The content revision number of whatever [current] holds right now —
  /// `0` before any verified fetch has ever been applied (`withHistory`
  /// only; always `0` for the other 2 constructors).
  int get currentContentVersion =>
      _history.isEmpty ? 0 : _history.last.contentVersion;

  /// The checksum of whatever [current] holds right now — `null` before
  /// any verified fetch has ever been applied, or for a constructor that
  /// doesn't track history.
  String? get currentChecksum =>
      _history.isEmpty ? null : _history.last.checksum;

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

  /// ENH-96 (`withHistory` only): where [_history] is persisted —
  /// deliberately a DIFFERENT key than [cacheKey] (`${cacheKey}_history_v1`)
  /// so an existing [withCache] consumer's cache entry is never touched by
  /// upgrading to [withHistory], and a `withHistory` pack's own single-slot
  /// cache (still written by [_writeCache], unchanged) stays exactly
  /// compatible with [withCache]'s format too.
  String? get _historyStorageKey {
    final key = cacheKey;
    if (key == null || historyCapacity == null) return null;
    return '${key}_history_v1';
  }

  bool _historyLoaded = false;

  void _ensureHistoryLoaded() {
    if (_historyLoaded) return;
    _historyLoaded = true;
    final store = storage;
    final key = _historyStorageKey;
    if (store == null || key == null) return;
    final raw = store.getString(key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final entry in decoded) {
        final record = _HistoryRecord.fromStorageJson(entry);
        if (record != null) _history.add(record);
      }
    } catch (_) {
      // Corrupt/malformed history blob → start from an empty history
      // rather than crash boot (same trust-boundary posture every other
      // persisted JSON blob in this package uses).
      _history.clear();
    }
  }

  Future<void> _persistHistory() async {
    final store = storage;
    final key = _historyStorageKey;
    if (store == null || key == null) return;
    await store.setString(
      key,
      jsonEncode([for (final r in _history) r.toStorageJson()]),
    );
  }

  void _appendHistory(_HistoryRecord record) {
    _history.add(record);
    final capacity = historyCapacity;
    if (capacity != null && _history.length > capacity) {
      _history.removeRange(0, _history.length - capacity);
    }
  }

  Future<T?> load() async {
    _ensureHistoryLoaded();
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

      // ENH-96: a history-tracking pack rejects a downgrade outright —
      // `_current`/the cache/`_history` all stay exactly as they were.
      // Checked against the validated+migrated shape (not the raw
      // envelope) so `contentVersionResolver` always sees the SAME shape
      // `fromJson` itself will receive.
      final resolver = contentVersionResolver;
      if (resolver != null && _history.isNotEmpty) {
        final incomingVersion = resolver(validated);
        if (incomingVersion < currentContentVersion) return;
      }

      // ENH-94: cache write happens BEFORE `_current` is swapped in — an
      // atomic swap in the sense the task asked for ("ghi xong mới trỏ
      // _current"). If the write throws, this whole try block's catch
      // below catches it too, so `_current` is left untouched rather than
      // pointing at content the disk doesn't actually have a record of.
      await _writeCache(validated);
      if (resolver != null) {
        final checksum = envelope[checksumKey];
        _appendHistory(
          _HistoryRecord(
            schemaVersion: schemaVersion,
            contentVersion: resolver(validated),
            checksum: checksum is String ? checksum : '',
            appliedAtMs: nowMsClamped(storage),
            json: validated,
          ),
        );
        await _persistHistory();
      }
      _current = fromJson(validated);
    } catch (_) {
      // Network failure, bad signature/schema, a fromJson throw on a
      // wrong-typed field, or a cache-write failure → keep whatever
      // _current already was.
    }
  }

  /// ENH-96 (`withHistory` only): re-activates the verified revision whose
  /// checksum is [checksum] — re-verifies it was indeed in [history] (never
  /// trusts an caller-supplied checksum blindly), persists it as the
  /// current cache entry, appends a fresh history entry recording WHEN the
  /// rollback itself happened (so the audit trail shows the rollback as
  /// its own event, not a silent rewrite of the original entry's
  /// timestamp), and only then swaps [_current]. Returns [SdkFailure] (no
  /// mutation at all) if no history entry matches.
  Future<SdkResult<T>> rollbackToChecksum(String checksum) async {
    _ensureHistoryLoaded();
    final match = _history.cast<_HistoryRecord?>().lastWhere(
      (r) => r!.checksum == checksum,
      orElse: () => null,
    );
    if (match == null) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'No history entry matches that checksum',
      );
    }
    return _activateHistoryRecord(match);
  }

  /// ENH-96 (`withHistory` only): re-activates [contentVersion] — if more
  /// than one history entry shares that version number (same version
  /// re-applied more than once), the most-recently-applied one wins, same
  /// "latest wins" convention [currentContentVersion] itself uses. Returns
  /// [SdkFailure] (no mutation) if no history entry matches.
  Future<SdkResult<T>> rollbackToVersion(int contentVersion) async {
    _ensureHistoryLoaded();
    final matches = _history
        .where((r) => r.contentVersion == contentVersion)
        .toList();
    if (matches.isEmpty) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'No history entry matches that content version',
      );
    }
    matches.sort((a, b) => a.appliedAtMs.compareTo(b.appliedAtMs));
    return _activateHistoryRecord(matches.last);
  }

  Future<SdkResult<T>> _activateHistoryRecord(_HistoryRecord record) async {
    try {
      await _writeCache(record.json);
      _appendHistory(
        _HistoryRecord(
          schemaVersion: record.schemaVersion,
          contentVersion: record.contentVersion,
          checksum: record.checksum,
          appliedAtMs: nowMsClamped(storage),
          json: record.json,
        ),
      );
      await _persistHistory();
      _current = fromJson(record.json);
      return SdkSuccess(_current as T);
    } catch (error, stack) {
      return SdkFailure(
        kind: SdkErrorKind.storage,
        message: 'Rollback failed to persist',
        cause: error,
        stackTrace: stack,
      );
    }
  }

  /// ENH-96 (`withHistory` only): metadata-only snapshot safe to paste into
  /// a support ticket / log line / `DiagnosticsExportBundle` section — NEVER
  /// the content body (a level layout, a shop catalog, whatever `T`
  /// represents), matching this package's existing default-deny diagnostics
  /// convention (`DiagnosticsExportBundle.build`'s `configAllowedKeys`).
  Map<String, Object?> diagnosticsSummary() {
    _ensureHistoryLoaded();
    return {
      'schemaVersion': schemaVersion,
      'contentVersion': currentContentVersion,
      'checksum': currentChecksum,
      'appliedAtMs': _history.isEmpty ? null : _history.last.appliedAtMs,
      'historyCount': _history.length,
    };
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
