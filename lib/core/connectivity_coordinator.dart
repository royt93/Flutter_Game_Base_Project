import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'utils/clamped_clock.dart';
import 'utils/retry_policy.dart';

/// Raw OS-level "does a network interface exist" signal (WiFi/cellular up)
/// — deliberately separate from actual Internet reachability. An interface
/// can be up with zero real connectivity (captive portal, DNS failure),
/// which is exactly what [ReachabilityProbe] below is for.
abstract class ConnectivitySignal {
  /// Emits `true`/`false` each time an interface appears or disappears.
  Stream<bool> get hasInterfaceStream;

  /// Current interface state; read at coordinator construction and again when
  /// a debug override is cleared.
  bool get hasInterfaceNow;
}

/// In-memory test double — a consuming app's own tests (or this kit's) can
/// push interface transitions directly via [setHasInterface] instead of
/// depending on a real platform channel.
class FakeConnectivitySignal implements ConnectivitySignal {
  /// [initialHasInterface] is what [hasInterfaceNow] reports until the first
  /// [setHasInterface] call.
  FakeConnectivitySignal({bool initialHasInterface = false})
    : _hasInterface = initialHasInterface;

  bool _hasInterface;
  final _controller = StreamController<bool>.broadcast();

  @override
  bool get hasInterfaceNow => _hasInterface;

  @override
  Stream<bool> get hasInterfaceStream => _controller.stream;

  /// Updates [hasInterfaceNow] and emits [value] on [hasInterfaceStream]
  /// (even if it equals the previous value).
  void setHasInterface(bool value) {
    _hasInterface = value;
    _controller.add(value);
  }

  /// Closes [hasInterfaceStream]; call from test teardown.
  void dispose() => _controller.close();
}

/// Actual reachability probe an app injects (e.g. a HEAD request to a
/// known-good endpoint) — returns true only when the Internet is genuinely
/// usable, not just "an interface exists".
typedef ReachabilityProbe = Future<bool> Function();

/// What [ConnectivityCoordinator] currently believes about Internet access.
enum ConnectivityState {
  /// No network interface at all.
  offline,

  /// Interface just appeared (or a periodic re-probe just started) — no
  /// confirmed reachability result yet for this transition.
  checking,

  /// Interface up and the most recent probe succeeded.
  online,

  /// Interface up, but the probe just failed once — not yet enough
  /// consecutive failures to declare [offline] (hysteresis), so a
  /// transient single failure doesn't flip the UI straight to "No
  /// internet connection" and back a second later.
  degraded,
}

/// One retryable, idempotent unit of work queued while offline.
class QueuedTask {
  /// [idempotencyKey] identifies the task for replacement; [run] is retried
  /// per the coordinator's retry policy; [expiresAtMs] is an optional
  /// deadline in [nowMsClamped] milliseconds.
  QueuedTask({
    required this.idempotencyKey,
    required this.run,
    this.priority = 0,
    this.expiresAtMs,
  });

  /// Enqueuing a second task with the same key replaces the first rather
  /// than running both — e.g. re-submitting the same score sync while the
  /// first submission is still queued shouldn't double-send it.
  final String idempotencyKey;

  /// The work to perform once online; a throw counts as a failed attempt.
  final Future<void> Function() run;

  /// Higher drains first. Ties keep insertion order.
  final int priority;

  /// Checked against [nowMsClamped] at drain time — an expired task is
  /// dropped without running, never attempted.
  final int? expiresAtMs;
}

/// Reactive Internet-reachability coordinator with a bounded, idempotent
/// retry queue for tasks an app wants to run once back online.
///
/// **Interface vs. reachability**: [ConnectivityState.online] is reported
/// **only** after [probe] itself succeeds — a [ConnectivitySignal] reporting
/// an interface is up is never, by itself, treated as "online" (a captive
/// portal or DNS outage would otherwise report a false positive).
///
/// **Debounce + hysteresis**: rapid interface flapping is debounced
/// ([debounceWindow]) before a transition is even evaluated, and a single
/// failed probe while previously online moves to [ConnectivityState.degraded]
/// rather than straight to [ConnectivityState.offline] — only
/// [failuresToGoOffline] *consecutive* failures declare it truly offline.
/// Both guards exist so flapping connectivity doesn't spam the UI or a
/// retry storm.
///
/// **Queue**: [enqueue] is capped at [maxQueueSize] (evicts the
/// lowest-priority entry once full), keyed by [QueuedTask.idempotencyKey]
/// (a duplicate key replaces, never duplicates), and drains automatically
/// once [state] reaches [ConnectivityState.online] — highest [QueuedTask.priority]
/// first. Each task runs through an injected [RetryExecutor]/[retryPolicy];
/// one task exhausting its retries is dropped and logged, never blocking
/// the rest of the queue. A mid-drain drop back offline stops the drain
/// immediately — whatever's left stays queued for the next `online`.
class ConnectivityCoordinator extends GetxService {
  /// [signal] and [probe] are required. [debounceWindow] delays acting on an
  /// interface change; [probeInterval] is the re-probe period while an
  /// interface is up; [failuresToGoOffline] consecutive failed probes are
  /// needed to report offline; [maxQueueSize] caps [enqueue]d tasks. Throws
  /// [ArgumentError] if [failuresToGoOffline] or [maxQueueSize] is `<= 0`.
  /// Schedules an evaluation of the current interface state right away; it
  /// takes effect after [debounceWindow].
  ConnectivityCoordinator({
    required this.signal,
    required this.probe,
    this.debounceWindow = const Duration(milliseconds: 400),
    this.probeInterval = const Duration(seconds: 15),
    this.failuresToGoOffline = 2,
    this.maxQueueSize = 50,
    this.retryPolicy = const RetryPolicy(maxAttempts: 3),
    RetryExecutor? retryExecutor,
    Timer Function(Duration delay, void Function() callback)? createTimer,
  }) : _retryExecutor = retryExecutor ?? RetryExecutor(),
       _createTimer = createTimer ?? Timer.new {
    if (failuresToGoOffline <= 0) {
      throw ArgumentError.value(
        failuresToGoOffline,
        'failuresToGoOffline',
        'must be > 0',
      );
    }
    if (maxQueueSize <= 0) {
      throw ArgumentError.value(maxQueueSize, 'maxQueueSize', 'must be > 0');
    }
    _stateController = StreamController<ConnectivityState>.broadcast();
    _sub = signal.hasInterfaceStream.listen(_scheduleInterfaceEvaluation);
    _scheduleInterfaceEvaluation(signal.hasInterfaceNow);
  }

  /// Source of raw interface up/down events.
  final ConnectivitySignal signal;

  /// Real reachability check; a throw is treated as a failed probe.
  final ReachabilityProbe probe;

  /// Quiet period after an interface event before it is evaluated.
  final Duration debounceWindow;

  /// How often [probe] re-runs while an interface is up.
  final Duration probeInterval;

  /// Consecutive failed probes required to move to [ConnectivityState.offline].
  final int failuresToGoOffline;

  /// Maximum queued tasks; see [enqueue] for what is evicted.
  final int maxQueueSize;

  /// Retry settings applied to each queued task while draining.
  final RetryPolicy retryPolicy;
  final RetryExecutor _retryExecutor;
  final Timer Function(Duration delay, void Function() callback) _createTimer;

  /// The registered coordinator, or `null` if none is registered.
  static ConnectivityCoordinator? get maybe =>
      Get.isRegistered<ConnectivityCoordinator>()
      ? Get.find<ConnectivityCoordinator>()
      : null;

  ConnectivityState _state = ConnectivityState.offline;

  /// Current state; stays [ConnectivityState.offline] until the first
  /// debounced evaluation runs.
  ConnectivityState get state => _state;

  late final StreamController<ConnectivityState> _stateController;

  /// Broadcast stream of state changes; emits only when [state] actually
  /// changes, and does not replay the current value to new listeners.
  Stream<ConnectivityState> get stateStream => _stateController.stream;

  /// Bridges directly into `NetworkStatusBanner.stream` — `true` for
  /// [ConnectivityState.online]/[ConnectivityState.degraded] (a real
  /// interface has been reachable at least recently), `false` for
  /// [ConnectivityState.offline]/[ConnectivityState.checking].
  Stream<bool> get connectedStream => stateStream.map(
    (s) => s == ConnectivityState.online || s == ConnectivityState.degraded,
  );

  StreamSubscription<bool>? _sub;
  Timer? _debounceTimer;
  Timer? _probeTimer;
  int _consecutiveFailures = 0;
  bool _probeInFlight = false;
  bool _draining = false;
  bool _isClosed = false;
  final _queue = <QueuedTask>[];

  /// Number of tasks still waiting to run.
  int get queueLength => _queue.length;

  // FEAT-93: DebugQaOverlay's "Network Simulator" tab — lets a QA tester
  // force offline/degraded without touching the device's real WiFi/
  // cellular. Always `null` in a release build (nothing sets it outside
  // an already debug-gated UI, and [debugForceState] itself no-ops
  // outside `kDebugMode`/`kProfileMode`).
  ConnectivityState? _debugForcedState;

  /// Forces [state]/[stateStream] to report [state] regardless of what
  /// real signal/probe evaluations find, until cleared with `null` — a
  /// no-op outside `kDebugMode`/`kProfileMode` (same posture as [dlog]).
  /// Real probes keep running in the background the whole time (so
  /// forcing `online` while genuinely offline can still trigger a REAL
  /// [enqueue]d task drain attempt — a deliberate way to test drain
  /// behavior on-device without needing actual connectivity); clearing
  /// the override (`null`) immediately re-evaluates real connectivity
  /// instead of waiting for the next signal/probe event.
  void debugForceState(ConnectivityState? state) {
    if (_isClosed) return;
    if (!kDebugMode && !kProfileMode) return;
    _debugForcedState = state;
    if (state != null) {
      _setState(state);
    } else {
      _scheduleInterfaceEvaluation(signal.hasInterfaceNow);
    }
  }

  void _scheduleInterfaceEvaluation(bool hasInterface) {
    if (_isClosed) return;
    _debounceTimer?.cancel();
    _debounceTimer = _createTimer(
      debounceWindow,
      () => _handleInterfaceChange(hasInterface),
    );
  }

  void _handleInterfaceChange(bool hasInterface) {
    if (_isClosed) return;
    _probeTimer?.cancel();
    if (!hasInterface) {
      _consecutiveFailures = 0;
      _setState(ConnectivityState.offline);
      return;
    }
    _setState(ConnectivityState.checking);
    unawaited(_runProbe());
    if (_isClosed) return;
    _probeTimer = _createTimer(probeInterval, _periodicProbe);
  }

  void _periodicProbe() {
    if (_isClosed) return;
    unawaited(_runProbe());
    if (_isClosed) return;
    _probeTimer = _createTimer(probeInterval, _periodicProbe);
  }

  Future<void> _runProbe() async {
    if (_isClosed || _probeInFlight) return;
    _probeInFlight = true;
    try {
      // BUG-43: `probe` is consumer-supplied (a real HTTP HEAD/socket check)
      // and routinely throws (SocketException/TimeoutException) when the
      // network is actually down — that's exactly the "no connectivity"
      // signal, not a bug in the probe. Treat it the same as `ok == false`
      // rather than letting it escape this `unawaited(_runProbe())` call as
      // an unhandled async error, which would also skip the state update
      // below and leave the coordinator stuck on its last known state.
      bool ok;
      try {
        ok = await probe();
      } catch (_) {
        ok = false;
      }
      if (_isClosed) return;
      if (ok) {
        _consecutiveFailures = 0;
        _setState(ConnectivityState.online);
        unawaited(_drainQueue());
      } else {
        _consecutiveFailures++;
        _setState(
          _consecutiveFailures >= failuresToGoOffline
              ? ConnectivityState.offline
              : ConnectivityState.degraded,
        );
      }
    } finally {
      _probeInFlight = false;
    }
  }

  void _setState(ConnectivityState next) {
    if (_isClosed) return;
    // A forced debug state wins over whatever the real signal/probe path
    // just computed — see [debugForceState].
    final effective = _debugForcedState ?? next;
    if (_state == effective) return;
    _state = effective;
    if (!_stateController.isClosed) {
      _stateController.add(effective);
    }
  }

  /// Queues [task] to run once [state] is [ConnectivityState.online] (starts
  /// draining immediately if it already is). A queued task with the same
  /// [QueuedTask.idempotencyKey] is replaced; if the queue is full, the
  /// lowest-priority entry (the earliest one on a tie) is evicted first.
  /// Ignored after the coordinator is closed.
  void enqueue(QueuedTask task) {
    if (_isClosed) return;
    _queue.removeWhere((t) => t.idempotencyKey == task.idempotencyKey);
    if (_queue.length >= maxQueueSize) {
      var lowestIndex = 0;
      for (var i = 1; i < _queue.length; i++) {
        if (_queue[i].priority < _queue[lowestIndex].priority) {
          lowestIndex = i;
        }
      }
      _queue.removeAt(lowestIndex);
    }
    _queue.add(task);
    if (_state == ConnectivityState.online) unawaited(_drainQueue());
  }

  Future<void> _drainQueue() async {
    if (_isClosed || _draining) return;
    _draining = true;
    try {
      final ordered = [..._queue]
        ..sort((a, b) => b.priority.compareTo(a.priority));
      for (final task in ordered) {
        if (_isClosed || _state != ConnectivityState.online) break;
        if (!_queue.contains(task)) continue;
        final expiresAt = task.expiresAtMs;
        if (expiresAt != null && nowMsClamped() > expiresAt) {
          _queue.remove(task);
          continue;
        }
        // RetryExecutor.run reports failure via SdkResult rather than
        // throwing, so one task exhausting its retries can never abort
        // this loop for the rest of the queue — the result is discarded
        // on purpose, a permanently-failed task is simply dropped.
        await _retryExecutor.run(task.run, policy: retryPolicy);
        if (_isClosed) break;
        _queue.remove(task);
      }
    } finally {
      _draining = false;
    }
  }

  @override
  void onClose() {
    _isClosed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _probeTimer?.cancel();
    _probeTimer = null;
    unawaited(_sub?.cancel());
    unawaited(_stateController.close());
    super.onClose();
  }
}
