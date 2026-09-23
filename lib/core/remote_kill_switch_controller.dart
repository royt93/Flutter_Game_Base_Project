import 'package:get/get.dart';

import 'remote_config_service.dart';
import 'utils/safe_json.dart';

/// Where a [KillSwitchState] decision actually came from — surfaced so a
/// debug overlay/health report can tell "ops explicitly killed this"
/// apart from "we couldn't reach a fresh answer and fell back".
enum KillSwitchSource {
  /// A client-side caller (FEAT-90's `ShadowActivationController`, or any
  /// other local guardrail) force-killed this feature via
  /// [RemoteKillSwitchController.forceKillLocally] — takes priority over
  /// every remote-driven source below, since it exists precisely to react
  /// FASTER than waiting for the next remote-config poll. Cleared only by
  /// an explicit [RemoteKillSwitchController.clearLocalOverride] call.
  localOverride,

  /// The current [RemoteConfigService] snapshot has a validly-shaped
  /// value for this feature right now.
  remoteValid,

  /// The remote value is missing or malformed on this read, but an
  /// earlier read for the same feature WAS valid — that earlier decision
  /// is kept as-is rather than reverting to any other default. This is
  /// the "invalid remote never opens a feature back up" guarantee: a
  /// corrupt payload can never flip a previously-killed feature back to
  /// enabled just by being garbage.
  cachedLastKnownGood,

  /// No valid remote value has ever been read for this feature — falls
  /// back to the caller-supplied bundled default (or `false`/"not
  /// killed" if the feature isn't in that map at all).
  assetDefault,
}

/// One feature's current kill-switch decision — [reason]/[version] are
/// the audit trail ("why was this killed, and which rollout"), populated
/// from the remote payload when it's the richer
/// `{killed, reason, version}` shape (a bare `bool` leaves them at their
/// defaults, `''`/`0`).
class KillSwitchState {
  const KillSwitchState({
    required this.featureId,
    required this.killed,
    required this.reason,
    required this.version,
    required this.source,
    required this.decidedAtMs,
  });

  final String featureId;
  final bool killed;
  final String reason;
  final int version;
  final KillSwitchSource source;
  final int decidedAtMs;

  @override
  String toString() =>
      'KillSwitchState($featureId: killed=$killed, reason="$reason", '
      'version=$version, source=$source)';
}

class _ParsedKillSwitch {
  const _ParsedKillSwitch({
    required this.killed,
    required this.reason,
    required this.version,
  });
  final bool killed;
  final String reason;
  final int version;
}

/// Emergency remote kill switch for a feature/event/shop/animation —
/// built on top of [RemoteConfigService] (FEAT-39/ENH-58 already give it
/// asset-fallback + partial-merge + last-known-good semantics at the
/// config-value level; this controller adds the kill-switch-specific
/// safety policy ON TOP: **an invalid or missing remote value can never
/// flip a feature from killed back to enabled** — see [KillSwitchSource]
/// for the exact resolution order).
///
/// Reactive: [states] is an `RxMap`, so any widget wrapped in `Obx`
/// watching `states[featureId]` rebuilds the moment [isKilled] (or
/// [refreshAll]) resolves a new decision for that feature — a screen
/// already open when ops flips a switch remotely reacts without needing
/// to be rebuilt/reopened, and without touching whatever it's currently
/// doing (no crash, since it's just watching a value, not being torn
/// down).
class RemoteKillSwitchController extends GetxService {
  RemoteKillSwitchController({
    required this.remoteConfig,
    this.assetDefaults = const {},
    this.keyPrefix = 'kill_switch_',
    int Function()? nowMs,
  }) : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final RemoteConfigService remoteConfig;

  /// Bundled fallback kill state per feature, used only when no valid
  /// remote value has EVER been seen for that feature (see
  /// [KillSwitchSource.assetDefault]) — a feature absent from this map
  /// defaults to `false` (not killed, normal operation).
  final Map<String, bool> assetDefaults;

  /// The remote config key for `featureId` is `'$keyPrefix$featureId'`.
  final String keyPrefix;
  final int Function() _nowMs;

  static RemoteKillSwitchController? get maybe =>
      Get.isRegistered<RemoteKillSwitchController>()
      ? Get.find<RemoteKillSwitchController>()
      : null;

  /// Reactive last-resolved state per feature — read-through by
  /// [isKilled]/[refreshAll], never written directly by a caller.
  final RxMap<String, KillSwitchState> states = <String, KillSwitchState>{}.obs;

  final _lastKnownGood = <String, KillSwitchState>{};
  final _localOverrides = <String, String>{};
  final _auditLog = <KillSwitchState>[];

  /// Force-kills [featureId] immediately, CLIENT-SIDE, without waiting for
  /// the next [remoteConfig] poll — see [KillSwitchSource.localOverride].
  /// [reason] is required (unlike the remote/asset paths, where it's
  /// optional) since a local override always needs an audit trail
  /// explaining why THIS device decided to kill a feature on its own.
  ///
  /// Idempotent: calling this again for an already-overridden
  /// [featureId] just replaces the recorded [reason].
  void forceKillLocally(String featureId, {required String reason}) {
    _localOverrides[featureId] = reason;
    isKilled(featureId);
  }

  /// Removes a prior [forceKillLocally] override for [featureId] — the
  /// next [isKilled]/[refreshAll] call falls back through to the normal
  /// remote/cached/asset resolution order again.
  void clearLocalOverride(String featureId) {
    _localOverrides.remove(featureId);
    isKilled(featureId);
  }

  /// Bounded audit history — same ring-buffer reasoning as
  /// `ReplayRecorder`/`MemoryWatchdog`'s own capped lists.
  static const int _auditCapacity = 200;

  /// Every decision ever made, oldest first, capped at
  /// [_auditCapacity] — "audit reason/version" over time, not just the
  /// current snapshot.
  List<KillSwitchState> get auditLog => List.unmodifiable(_auditLog);

  /// Resolves [featureId]'s current kill state (updating [states] and
  /// [auditLog] as a side effect) and returns whether it's killed.
  bool isKilled(String featureId) {
    final state = _resolve(featureId);
    states[featureId] = state;
    if (state.source == KillSwitchSource.remoteValid) {
      _lastKnownGood[featureId] = state;
    }
    _auditLog.add(state);
    while (_auditLog.length > _auditCapacity) {
      _auditLog.removeAt(0);
    }
    return state.killed;
  }

  /// Re-resolves every id in [featureIds] — for a periodic/lifecycle-
  /// resume hook that wants every tracked switch's [states] entry fresh
  /// even for features no widget has directly asked about yet.
  void refreshAll(Iterable<String> featureIds) {
    for (final id in featureIds) {
      isKilled(id);
    }
  }

  /// Runs [action] and returns its result — but ONLY if [featureId] is
  /// not currently killed; returns `null` and never calls [action]
  /// otherwise. Makes "don't grant/execute a killed feature" the path of
  /// least resistance instead of relying on every call site remembering
  /// its own `if (!isKilled(...))` guard.
  T? runIfEnabled<T>(String featureId, T Function() action) {
    if (isKilled(featureId)) return null;
    return action();
  }

  KillSwitchState _resolve(String featureId) {
    final localReason = _localOverrides[featureId];
    if (localReason != null) {
      return KillSwitchState(
        featureId: featureId,
        killed: true,
        reason: localReason,
        version: 0,
        source: KillSwitchSource.localOverride,
        decidedAtMs: _nowMs(),
      );
    }

    final raw = remoteConfig.snapshot['$keyPrefix$featureId'];
    final parsed = _parseRaw(raw);
    if (parsed != null) {
      return KillSwitchState(
        featureId: featureId,
        killed: parsed.killed,
        reason: parsed.reason,
        version: parsed.version,
        source: KillSwitchSource.remoteValid,
        decidedAtMs: _nowMs(),
      );
    }

    final cached = _lastKnownGood[featureId];
    if (cached != null) {
      return KillSwitchState(
        featureId: featureId,
        killed: cached.killed,
        reason: cached.reason,
        version: cached.version,
        source: KillSwitchSource.cachedLastKnownGood,
        decidedAtMs: _nowMs(),
      );
    }

    return KillSwitchState(
      featureId: featureId,
      killed: assetDefaults[featureId] ?? false,
      reason: '',
      version: 0,
      source: KillSwitchSource.assetDefault,
      decidedAtMs: _nowMs(),
    );
  }

  /// A bare `bool` (`true`/`false`) or a `{killed: bool, reason?:
  /// string, version?: int}` map are the only 2 accepted shapes —
  /// anything else (missing key, wrong type, a map without a `bool`
  /// `killed` field) returns `null`, meaning "reject this remote value
  /// entirely," never a best-effort guess.
  _ParsedKillSwitch? _parseRaw(Object? raw) {
    if (raw is bool) {
      return _ParsedKillSwitch(killed: raw, reason: '', version: 0);
    }
    if (raw is Map) {
      final killedValue = raw['killed'];
      if (killedValue is! bool) return null;
      return _ParsedKillSwitch(
        killed: killedValue,
        reason: asStringOr(raw['reason'], ''),
        version: asIntOr(raw['version'], 0),
      );
    }
    return null;
  }
}
