import 'package:flutter/foundation.dart';

import 'sdk_health_report.dart';

/// What kind of disposable resource a [WatchdogEntry] tracks — the 5
/// categories this task's own user story names (ticker/controller/
/// overlay/subscription/Flame component); `custom` covers anything else
/// a consumer app wants to track through the same mechanism.
enum WatchdogKind {
  ticker,
  controller,
  overlay,
  subscription,
  flameComponent,
  custom,
}

/// One still-live tracked resource — [owner] is free text (typically a
/// `runtimeType.toString()` or a widget's debug label), not a live
/// reference to the resource itself: this class never holds the actual
/// `Ticker`/`AnimationController`/etc, only metadata about it, so tracking
/// something can never itself keep it alive or leak it further.
class WatchdogEntry {
  const WatchdogEntry({
    required this.id,
    required this.kind,
    required this.owner,
    required this.label,
    required this.createdAtMs,
  });

  final int id;
  final WatchdogKind kind;
  final String owner;

  /// Optional caller-chosen name — this is what [MemoryWatchdog.allow]
  /// matches against, so a caller wanting an allowlist exemption must
  /// give a stable, deliberate label (not rely on [owner] alone, which
  /// might be shared by many unrelated instances of the same class).
  final String? label;
  final int createdAtMs;
}

/// A [WatchdogEntry] that was properly released, kept in a short bounded
/// history for debugging ("did X actually get disposed, and when") —
/// separate from [MemoryWatchdog.orphans], which only ever looks at
/// still-live entries.
class DisposedWatchdogEntry {
  const DisposedWatchdogEntry({
    required this.entry,
    required this.disposedAtMs,
  });

  final WatchdogEntry entry;
  final int disposedAtMs;
}

/// Debug-only tracker for disposable resources (tickers, controllers,
/// overlay entries, stream subscriptions, Flame components) that are easy
/// to forget to dispose — a widget/service calls [track] when it CREATES
/// one and [release] when it properly disposes it; anything still tracked
/// when [orphans] is called (typically at the end of a test, or from a
/// debug overlay/health report during a real session) is a leak
/// candidate.
///
/// **Ships zero overhead in release** — every method short-circuits on
/// `!kDebugMode` before touching any state, the same convention
/// `lib/core/debug_log.dart`'s `dlog()` already uses; `kDebugMode` is a
/// compile-time-foldable constant, so an AOT release build's compiler
/// dead-code-eliminates everything past that check. This can't be
/// verified by a normal `flutter test` run (which always runs in debug
/// mode) — same untestable-by-construction situation `dlog()` is already
/// in, so this file has no dedicated "release is a no-op" test either.
///
/// **This is a leak DETECTOR, not a leak PREVENTER**: it never holds a
/// reference to the tracked resource, so it cannot dispose one for you or
/// keep one alive by tracking it.
class MemoryWatchdog {
  MemoryWatchdog._();

  /// Injectable for deterministic tests — same pattern as
  /// `ClampedClock`/`ReplayRecorder`'s own clock seams.
  static int Function() nowMs = () => DateTime.now().millisecondsSinceEpoch;

  static final Map<int, WatchdogEntry> _live = {};
  static final List<DisposedWatchdogEntry> _recentlyDisposed = [];
  static final Set<String> _allowlist = {};
  static int _nextId = 0;

  /// Cap on [_recentlyDisposed] — a bounded ring, same reasoning as
  /// `ReplayRecorder`'s `capacity`: a long debug session shouldn't grow
  /// this list forever.
  static const int _disposedHistoryCapacity = 200;

  /// Exempts every future (and already-tracked) entry carrying [label]
  /// from [orphans] — for a resource that is deliberately permanent by
  /// design, not a bug. The canonical real example in this codebase:
  /// `NeonBg`'s permanent background-animation `Ticker` (see
  /// `lib/presentation/widgets/neon_bg.dart` and the "Testing gotcha"
  /// note in `CLAUDE.md`) — without an allowlist, a watchdog would
  /// forever flag it as a leak.
  static void allow(String label) {
    if (!kDebugMode) return;
    _allowlist.add(label);
  }

  static void disallow(String label) {
    if (!kDebugMode) return;
    _allowlist.remove(label);
  }

  /// Records a newly-created resource, returning an id to pass back to
  /// [release] — the id is `-1` outside debug mode (a harmless sentinel;
  /// [release] treats any unknown id as a no-op).
  static int track(WatchdogKind kind, {required String owner, String? label}) {
    if (!kDebugMode) return -1;
    final id = _nextId++;
    _live[id] = WatchdogEntry(
      id: id,
      kind: kind,
      owner: owner,
      label: label,
      createdAtMs: nowMs(),
    );
    return id;
  }

  /// Marks [id] as properly disposed — idempotent (releasing an unknown
  /// or already-released id is a safe no-op, not an error, since a
  /// `dispose()` method can legitimately run more than once in some
  /// Flutter widget lifecycles).
  static void release(int id) {
    if (!kDebugMode) return;
    final entry = _live.remove(id);
    if (entry == null) return;
    _recentlyDisposed.add(
      DisposedWatchdogEntry(entry: entry, disposedAtMs: nowMs()),
    );
    while (_recentlyDisposed.length > _disposedHistoryCapacity) {
      _recentlyDisposed.removeAt(0);
    }
  }

  /// Every still-live entry that is neither allowlisted (via [allow]) nor
  /// younger than [minAge] (when given) — the actual "leak candidates"
  /// report. `[]` outside debug mode.
  static List<WatchdogEntry> orphans({Duration? minAge}) {
    if (!kDebugMode) return const [];
    final cutoff = minAge == null ? null : nowMs() - minAge.inMilliseconds;
    return _live.values.where((e) {
      if (e.label != null && _allowlist.contains(e.label)) return false;
      if (cutoff != null && e.createdAtMs > cutoff) return false;
      return true;
    }).toList();
  }

  /// The bounded recently-disposed history, newest last.
  static List<DisposedWatchdogEntry> recentlyDisposed() =>
      List.unmodifiable(_recentlyDisposed);

  /// Clears all state — for test isolation between cases (mirrors
  /// `RoyCasualKit.resetForTesting()`'s role for the bootstrap module).
  static void reset() {
    _live.clear();
    _recentlyDisposed.clear();
    _allowlist.clear();
    _nextId = 0;
  }
}

/// Opt-in `SdkHealthReport` (FEAT-39) section reporting the current
/// orphan count/kinds — a consumer app registers this itself (`report
/// ..register(memoryWatchdogHealthCollector())`), it's not part of
/// `defaultHealthCollectors()` since, unlike audio/performance/
/// remoteConfig, this isn't a runtime module a consumer "has registered
/// or not" — it's always available, opt-in by nature of being a debug
/// diagnostic.
HealthCollectorSpec memoryWatchdogHealthCollector() => HealthCollectorSpec(
  name: 'memoryWatchdog',
  allowedKeys: const {'orphanCount', 'orphanKinds'},
  collect: () {
    final orphans = MemoryWatchdog.orphans();
    return {
      'orphanCount': orphans.length,
      'orphanKinds': (orphans.map((e) => e.kind.name).toSet().toList()..sort()),
    };
  },
);
