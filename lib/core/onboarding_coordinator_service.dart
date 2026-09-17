import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'storage_service.dart';
import 'versioned_json_store.dart';

/// Decides WHICH onboarding/tutorial flow should run next and WHETHER a
/// given one has already been seen — the coordination layer this package's
/// tutorial widgets (`TutorialSequence`, `SpotlightOverlay`, IDEA-35's
/// JSON-authored flows) never had. Those widgets only know how to RENDER
/// one flow once told to; this service never renders anything itself, has
/// no `BuildContext`/`GlobalKey`/`Navigator` dependency, and doesn't call
/// into those widgets — a caller still owns showing the actual UI, this
/// only answers "which `flowId`, if any, should run right now".
///
/// A real casual game has several onboarding moments across its lifetime
/// (first-ever launch, a new-feature spotlight after an update, a
/// first-visit shop tip) — without one place tracking "seen" state and
/// priority, every screen re-invents its own flag and 2 flows can end up
/// racing to show at once, or a flow the caller forgot to mark seen
/// replays every session.
class OnboardingCoordinatorService extends GetxService {
  OnboardingCoordinatorService({String? storageKey})
    : _storageKey = storageKey ?? 'onboarding_seen_v1';

  // ENH-71: instance field (was `static const`) so 2 instances can point
  // at 2 independent "seen" tables — e.g. 1 per SaveSlotManager slot via
  // its `keyFor(slotId, suffix)` (same pattern ENH-69 used for
  // LocalScoreboardService). Defaulting to the same literal every prior
  // release used keeps an existing consumer app's save reading exactly the
  // same table it always did.
  final String _storageKey;

  /// In-memory only, re-declared every app boot via [registerFlow] — same
  /// convention as `AchievementService._thresholds`: cheap caller-supplied
  /// metadata, not persisted data.
  final List<_FlowRegistration> _registrations = [];
  Map<String, int>? _seen;

  /// Gets the instance if already registered (safe to call from
  /// game/widget tests).
  static OnboardingCoordinatorService? get maybe =>
      Get.isRegistered<OnboardingCoordinatorService>()
      ? Get.find<OnboardingCoordinatorService>()
      : null;

  VersionedJsonStore<Map<String, int>> get _store =>
      VersionedJsonStore<Map<String, int>>(
        storage: StorageService.to,
        key: _storageKey,
        schemaVersion: 1,
        toJson: (value) => value,
        fromJson: _parseSeen,
        migrate: (fromVersion, json) => json,
      );

  // Lazily hydrated on first touch, not in a constructor/onInit — avoids
  // depending on StorageService already being Get.put'd before this
  // service is constructed (same reason as AchievementService/EnergyService).
  Map<String, int> get _seenMap {
    if (_seen != null) return _seen!;
    try {
      _seen = _store.load() ?? <String, int>{};
    } catch (_) {
      // Domain fields are untrusted even after the envelope is valid — a
      // corrupt entry must never prevent the app from booting.
      _seen = <String, int>{};
    }
    return _seen!;
  }

  Map<String, int> _parseSeen(Map<String, Object?> json) {
    final result = <String, int>{};
    for (final entry in json.entries) {
      final id = entry.key.trim();
      final value = entry.value;
      if (id.isEmpty || value is! int || value < 0) continue;
      result[id] = value;
    }
    return result;
  }

  // Serializes every save behind the currently in-flight one (same
  // BUG-17/BUG-18 pattern as AchievementService/DailyLoginService) — 2
  // rapid markFlowSeen calls for different flowIds racing their disk
  // writes could otherwise let an older, already-superseded snapshot land
  // on disk LAST and silently roll back a completion on next restart.
  bool _saving = false;
  Future<void> _saveChain = Future.value();

  Future<void> _runSave(VersionedJsonStore<Map<String, int>> store) async {
    _saving = true;
    try {
      await store.save(_seenMap);
    } catch (_) {
      // Swallow — a transient save failure must not wedge every
      // subsequent markFlowSeen's save behind a permanently-rejected chain.
    } finally {
      _saving = false;
    }
  }

  /// Awaits every save queued so far — lets a test deterministically wait
  /// for a burst of rapid `markFlowSeen` calls to fully settle instead of
  /// guessing a delay.
  @visibleForTesting
  Future<void> get debugPendingSaves => _saveChain;

  /// Declares [flowId] as a flow that MAY run, with [priority] (higher
  /// runs first) and the [version] a caller must have seen to count as
  /// "done". Safe to call again for the same id every app boot (only
  /// updates priority/version bookkeeping; never touches persisted
  /// "seen" state) — same re-declare-every-run convention as
  /// `AchievementService.register`.
  void registerFlow(String flowId, {int priority = 0, int version = 1}) {
    _validateId(flowId);
    if (version <= 0) {
      throw ArgumentError.value(version, 'version', 'must be greater than 0');
    }
    _registrations.removeWhere((r) => r.flowId == flowId);
    _registrations.add(
      _FlowRegistration(flowId: flowId, priority: priority, version: version),
    );
  }

  /// `true` if [flowId] was marked seen at [version] or newer. `false`
  /// (never throws) for a flow never marked seen — including one that was
  /// never [registerFlow]-ed, since a caller may check this before ever
  /// registering anything.
  bool isFlowSeen(String flowId, {int version = 1}) {
    _validateId(flowId);
    return (_seenMap[flowId] ?? 0) >= version;
  }

  /// Records [flowId] as completed at [version]. Monotonic — never lowers
  /// an already-recorded newer version (guards against a stale caller
  /// accidentally "un-seeing" a flow by marking an older version after a
  /// newer one already landed).
  void markFlowSeen(String flowId, {int version = 1}) {
    _validateId(flowId);
    if (version <= 0) {
      throw ArgumentError.value(version, 'version', 'must be greater than 0');
    }
    final current = _seenMap[flowId] ?? 0;
    if (version > current) {
      _seenMap[flowId] = version;
      final store = _store;
      _saveChain = _saving
          ? _saveChain.then((_) => _runSave(store))
          : _runSave(store);
    }
  }

  /// The single highest-priority [registerFlow]-ed flow not yet
  /// [isFlowSeen] at its registered version — ties broken by registration
  /// order (whichever was `registerFlow`-ed first runs first). `null` if
  /// every registered flow is already seen (or none were ever registered).
  ///
  /// Only ever returns ONE flow — never a queue of several — so 2 flows
  /// can't end up shown at once; a caller re-calls this after marking the
  /// returned flow seen to chain into the next one, if any.
  String? nextEligibleFlow() {
    _FlowRegistration? best;
    for (final registration in _registrations) {
      if (isFlowSeen(registration.flowId, version: registration.version)) {
        continue;
      }
      if (best == null || registration.priority > best.priority) {
        best = registration;
      }
    }
    return best?.flowId;
  }

  void _validateId(String flowId) {
    if (flowId.trim().isEmpty) {
      throw ArgumentError.value(flowId, 'flowId', 'must not be empty');
    }
  }
}

class _FlowRegistration {
  const _FlowRegistration({
    required this.flowId,
    required this.priority,
    required this.version,
  });

  final String flowId;
  final int priority;
  final int version;
}
