import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';

import 'lifecycle_coordinator.dart';
import 'storage_service.dart';
import 'utils/async_action_guard.dart';
import 'utils/sdk_result.dart';

typedef _Participant = ({
  Object? Function() snapshot,
  void Function(Object? data) restore,
});

/// Coalesces multiple game systems' state into one atomic, versioned save
/// checkpoint on top of [StorageService] — one JSON blob under one key, so a
/// commit is never observably "half applied" across participants (unlike
/// each participant writing its own separate key, where a kill between 2
/// writes leaves a mixed save).
///
/// Register each system once via [registerParticipant]; [requestCheckpoint]
/// coalesces frequent calls (position updates, score ticks) into one flush
/// after [debounceWindow] of quiet, while `critical: true` (level complete,
/// a purchase) flushes immediately and cancels any pending debounce. A
/// [RoyLifecycleCoordinator] hook flushes immediately when the app
/// backgrounds, subject to that coordinator's own hook timeout.
///
/// A flush keeps the previous commit as a fallback generation
/// (`'$_key\_prev'`) — [restoreLatest] tries the current commit first, then
/// that fallback, so a single corrupted/tampered write (bad flash, a
/// hand-edited save) doesn't lose the whole checkpoint. [wasDirtyOnLoad]
/// reports whether the very last flush attempt (before this instance was
/// created) may not have completed — informational, since the fallback
/// generation is what actually protects [restoreLatest].
class CheckpointCoordinator extends GetxService {
  CheckpointCoordinator({
    required this.storage,
    this.debounceWindow = const Duration(seconds: 2),
    AsyncActionGuard? guard,
    String? storageKey,
    RoyLifecycleCoordinator? lifecycle,
    Timer Function(Duration delay, void Function() callback)? createTimer,
  }) : _guard = guard ?? AsyncActionGuard(),
       _key = storageKey ?? StorageKeys.checkpointCoordinatorV1,
       _createTimer = createTimer ?? Timer.new {
    wasDirtyOnLoad = storage.getBool('${_key}_dirty');
    final coordinator = lifecycle ?? RoyLifecycleCoordinator.maybe;
    if (coordinator != null) {
      _lifecycle = coordinator;
      coordinator.registerHook(_hookName, (event) async {
        if (event == RoyLifecycleEvent.background) {
          await flushNow();
        }
      });
    }
  }

  final StorageService storage;
  final Duration debounceWindow;
  final AsyncActionGuard _guard;
  final String _key;
  final Timer Function(Duration delay, void Function() callback) _createTimer;
  final _participants = <String, _Participant>{};
  // BUG-42: every non-critical requestCheckpoint() call pending in the
  // CURRENT debounce window — not just the most recent one. Coalescing 2+
  // calls into 1 flush must still resolve every one of their returned
  // futures with that flush's result, or an earlier caller's `await`
  // hangs forever once a later call cancels the timer it was waiting on.
  final _pendingCompleters = <Completer<SdkResult<int>>>[];
  Timer? _debounceTimer;
  RoyLifecycleCoordinator? _lifecycle;
  bool _isClosed = false;
  static const _hookName = 'checkpoint_coordinator';

  /// Whether `${_key}_dirty` was already `true` when this instance was
  /// constructed — i.e. the previous process was killed/crashed mid-flush.
  late final bool wasDirtyOnLoad;

  static CheckpointCoordinator? get maybe =>
      Get.isRegistered<CheckpointCoordinator>()
      ? Get.find<CheckpointCoordinator>()
      : null;

  void registerParticipant(
    String id, {
    required Object? Function() snapshot,
    required void Function(Object? data) restore,
  }) {
    _participants[id] = (snapshot: snapshot, restore: restore);
  }

  void removeParticipant(String id) => _participants.remove(id);

  /// Requests a checkpoint. A non-critical call coalesces with any other
  /// non-critical call within [debounceWindow] into a single later flush —
  /// its returned future only completes once that eventual flush runs
  /// (useful for tests; a real caller usually ignores it for the common
  /// hot-path case). `critical: true` cancels that pending debounce and
  /// flushes immediately instead.
  Future<SdkResult<int>> requestCheckpoint({bool critical = false}) {
    if (_isClosed) {
      return Future.value(
        const SdkFailure(
          kind: SdkErrorKind.unknown,
          message: 'CheckpointCoordinator is closed',
        ),
      );
    }
    if (critical) {
      // flushNow() itself synchronously cancels any pending debounce and
      // captures whatever's currently in `_pendingCompleters` (see its own
      // doc comment) — no separate handling needed here.
      return flushNow();
    }
    _debounceTimer?.cancel();
    final completer = Completer<SdkResult<int>>();
    _pendingCompleters.add(completer);
    _debounceTimer = _createTimer(debounceWindow, () {
      if (_isClosed) return;
      flushNow();
    });
    return completer.future;
  }

  /// Resolves only the [pending] waiters captured by one specific flush.
  /// Waiters added after that flush starts belong to the NEXT debounce/flush
  /// and must never receive an older snapshot's result.
  void _completePending(
    List<Completer<SdkResult<int>>> pending,
    Future<SdkResult<int>> result,
  ) {
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }
  }

  /// Gathers every participant's snapshot and commits them as one write.
  /// Serialized via [AsyncActionGuard] so an overlapping lifecycle-triggered
  /// flush and a debounce-triggered flush can never interleave. Any single
  /// participant's [_Participant.snapshot] throwing, or the aggregate not
  /// being JSON-encodable, aborts the WHOLE flush before anything is
  /// written — the previous checkpoint is left exactly as it was.
  ///
  /// BUG-82: this method is public and may be called directly while one or
  /// more non-critical [requestCheckpoint] calls are waiting on a debounce.
  /// It cancels that debounce, so it must also resolve those waiters with
  /// this exact flush's result — done SYNCHRONOUSLY, right here, before any
  /// async work starts. Capturing them only AFTER awaiting the write (as an
  /// earlier version of this fix did) has a real race: a request arriving
  /// WHILE that write is in flight would get swept into THIS flush's result
  /// even though its own state change may not even be part of the snapshot
  /// this flush already took — a false "saved" for data that was never
  /// written. Snapshotting the waiter list (and cancelling the timer) at
  /// call time instead means a request arriving during the write starts a
  /// genuinely separate cycle, exactly like the pre-BUG-82 critical branch
  /// already did correctly.
  Future<SdkResult<int>> flushNow() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final pending = List<Completer<SdkResult<int>>>.of(_pendingCompleters);
    _pendingCompleters.clear();
    final result = _guard.runExclusive(_hookName, _computeFlush);
    _completePending(pending, result);
    return result;
  }

  Future<SdkResult<int>> _computeFlush() async {
    if (_isClosed) {
      return const SdkFailure(
        kind: SdkErrorKind.unknown,
        message: 'CheckpointCoordinator is closed',
      );
    }

    final aggregate = <String, Object?>{};
    for (final entry in _participants.entries) {
      try {
        aggregate[entry.key] = entry.value.snapshot();
      } catch (error, stack) {
        return SdkFailure(
          kind: SdkErrorKind.unknown,
          message: 'Participant "${entry.key}" failed to snapshot',
          cause: error,
          stackTrace: stack,
        );
      }
    }

    final String encoded;
    try {
      encoded = jsonEncode({'version': 1, 'participants': aggregate});
    } catch (error, stack) {
      return SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Checkpoint is not JSON-encodable',
        cause: error,
        stackTrace: stack,
      );
    }

    try {
      await storage.setBool('${_key}_dirty', true);
      final previous = storage.getString(_key);
      if (previous != null) {
        await storage.setString('${_key}_prev', previous);
      }
      await storage.setString(_key, encoded);
      await storage.setBool('${_key}_dirty', false);
      return SdkSuccess(aggregate.length);
    } catch (error, stack) {
      return SdkFailure(
        kind: SdkErrorKind.storage,
        message: 'Checkpoint write failed',
        cause: error,
        stackTrace: stack,
      );
    }
  }

  /// Validates the current checkpoint, falling back to the previous
  /// generation if it's missing/corrupt, then — only once a whole valid
  /// aggregate is found — calls every registered participant's `restore`
  /// with its own slice. Never calls `restore` on any participant unless a
  /// fully valid aggregate was found (no partial apply).
  SdkResult<int> restoreLatest() {
    final decoded =
        _decode(storage.getString(_key)) ??
        _decode(storage.getString('${_key}_prev'));
    if (decoded == null) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'No valid checkpoint found',
      );
    }
    final participants = decoded['participants'];
    if (participants is! Map) {
      return const SdkFailure(
        kind: SdkErrorKind.validation,
        message: 'Malformed checkpoint',
      );
    }
    for (final entry in _participants.entries) {
      entry.value.restore(participants[entry.key]);
    }
    return SdkSuccess(_participants.length);
  }

  Map<String, Object?>? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['participants'] is! Map) return null;
      return Map<String, Object?>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  void onClose() {
    _isClosed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _lifecycle?.removeHook(_hookName);
    if (_pendingCompleters.isNotEmpty) {
      final pending = List<Completer<SdkResult<int>>>.of(_pendingCompleters);
      _pendingCompleters.clear();
      const failure = SdkFailure<int>(
        kind: SdkErrorKind.unknown,
        message:
            'CheckpointCoordinator closed before checkpoint could be written',
      );
      for (final completer in pending) {
        if (!completer.isCompleted) {
          completer.complete(failure);
        }
      }
    }
    super.onClose();
  }
}
