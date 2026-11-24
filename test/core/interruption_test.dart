import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/checkpoint_coordinator.dart';
import 'package:roy_casual_kit/core/game_session_controller.dart';
import 'package:roy_casual_kit/core/lifecycle_coordinator.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/owned_storage.dart';

/// ENH-124: interruption matrix (component x interruption kind) for the host.
/// Each test is one cell that had no test before; the cells that already had
/// one are listed in `doc/task/done/ENH-124-*.md`.
///
/// "Kill" is simulated the only way a host test can: stop awaiting an
/// in-flight write, drop the instance, and build a new `StorageService` over
/// the same `SharedPreferences`.
class _GatedStorage extends StorageService {
  _GatedStorage(super.prefs);

  /// Set a key to make the NEXT `setString` for it wait for [release].
  String? gatedKey;
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> setString(String key, String value) async {
    if (key == gatedKey && !started.isCompleted) {
      started.complete();
      await release.future;
    }
    return super.setString(key, value);
  }
}

class _Lifecycle {
  _Lifecycle(this.coordinator);
  final RoyLifecycleCoordinator coordinator;

  Future<void> send(AppLifecycleState s) async {
    coordinator.didChangeAppLifecycleState(s);
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('GameSessionController x app lifecycle', () {
    late RoyLifecycleCoordinator coordinator;
    late _Lifecycle lifecycle;
    late GameSessionController session;

    setUp(() {
      coordinator = RoyLifecycleCoordinator();
      Get.put(coordinator);
      lifecycle = _Lifecycle(coordinator);
      session = GameSessionController(lifecycle: coordinator)
        ..onInit()
        ..markReady()
        ..start();
      addTearDown(session.dispose);
    });

    test('resume without a prior pause leaves a playing session untouched', () async {
      await lifecycle.send(AppLifecycleState.resumed);
      expect(session.snapshot.value.phase, GameSessionPhase.playing);
      expect(session.snapshot.value.pauseReasons, isEmpty);
    });

    test('repeated background/foreground cycles end playing with no stuck reason', () async {
      for (var i = 0; i < 5; i++) {
        await lifecycle.send(AppLifecycleState.paused);
        expect(session.snapshot.value.phase, GameSessionPhase.paused, reason: 'bg #$i');
        await lifecycle.send(AppLifecycleState.resumed);
        expect(session.snapshot.value.phase, GameSessionPhase.playing, reason: 'fg #$i');
      }
      expect(session.snapshot.value.pauseReasons, isEmpty);
    });

    test('inactive then hidden then paused is ONE pause, one resume restores it', () async {
      await lifecycle.send(AppLifecycleState.inactive);
      await lifecycle.send(AppLifecycleState.hidden);
      await lifecycle.send(AppLifecycleState.paused);
      expect(session.snapshot.value.phase, GameSessionPhase.paused);
      expect(session.snapshot.value.pauseReasons, {GamePauseReason.system});

      await lifecycle.send(AppLifecycleState.resumed);
      expect(session.snapshot.value.phase, GameSessionPhase.playing);
    });

    test('a player pause survives a background/foreground round trip', () async {
      session.pause(GamePauseReason.user);
      await lifecycle.send(AppLifecycleState.paused);
      await lifecycle.send(AppLifecycleState.resumed);
      expect(
        session.snapshot.value.phase,
        GameSessionPhase.paused,
        reason: 'the player had paused on purpose; returning to the app must not resume',
      );
      expect(session.snapshot.value.pauseReasons, {GamePauseReason.user});
    });

    test('detached (process going away) pauses once and a late resume is harmless', () async {
      await lifecycle.send(AppLifecycleState.detached);
      expect(session.snapshot.value.phase, GameSessionPhase.paused);
      await lifecycle.send(AppLifecycleState.resumed);
      expect(session.snapshot.value.phase, GameSessionPhase.playing);
    });

    test('background while the session is already won does not reopen it', () async {
      session.win();
      await lifecycle.send(AppLifecycleState.paused);
      await lifecycle.send(AppLifecycleState.resumed);
      expect(session.snapshot.value.phase, GameSessionPhase.won);
    });

    test('a controller disposed while backgrounded does not crash the next resume', () async {
      final other = GameSessionController.withHookName(
        lifecycle: coordinator,
        hookName: 'other_session',
      )..onInit();
      await lifecycle.send(AppLifecycleState.paused);
      other.dispose();
      await lifecycle.send(AppLifecycleState.resumed);
      expect(coordinator.failures, isEmpty);
      expect(session.snapshot.value.phase, GameSessionPhase.playing, reason: 'the other session must still resume');
    });
  });

  group('kill during a storage write', () {
    test('a completed unbuffered write survives a kill, a never-started one leaves the old value', () async {
      SharedPreferences.setMockInitialValues({'coins': 'old'});
      final prefs = await SharedPreferences.getInstance();
      final first = _GatedStorage(prefs);
      addTearDown(first.onClose);

      await first.setString('purchased', 'sword');
      first.gatedKey = 'coins';
      final inFlight = first.setString('coins', 'new');
      await first.started.future;

      // Process killed here: the gated write never reaches the platform.
      final afterKill = StorageService(prefs);
      addTearDown(afterKill.onClose);
      expect(afterKill.getString('purchased'), 'sword');
      expect(afterKill.getString('coins'), 'old');

      first.release.complete();
      await inFlight;
    });

    test('a buffered write that was not flushed is lost on kill (documented trade-off)', () async {
      final first = await ownedStorage({'score': 1});
      await first.setIntBuffered('score', 99);
      expect(first.getInt('score'), 99);

      final afterKill = StorageService(await SharedPreferences.getInstance());
      addTearDown(afterKill.onClose);
      expect(afterKill.getInt('score'), 1);
    });

    test('going to background flushes the buffer, so a kill right after loses nothing', () async {
      final storage = await ownedStorage({'score': 1});
      Get.put<StorageService>(storage);
      final coordinator = RoyLifecycleCoordinator();
      Get.put(coordinator);

      await storage.setIntBuffered('score', 99);
      await _Lifecycle(coordinator).send(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final afterKill = StorageService(await SharedPreferences.getInstance());
      addTearDown(afterKill.onClose);
      expect(afterKill.getInt('score'), 99);
    });

    test('checkpoint killed mid-commit: old checkpoint restores and the dirty flag is reported', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = _GatedStorage(prefs);
      addTearDown(first.onClose);

      final writer = CheckpointCoordinator(storage: first);
      var hp = 5;
      writer.registerParticipant('player', snapshot: () => {'hp': hp}, restore: (_) {});
      expect((await writer.requestCheckpoint(critical: true)).isSuccess, isTrue);

      hp = 1;
      first.gatedKey = StorageKeys.checkpointCoordinatorV1;
      final inFlight = writer.requestCheckpoint(critical: true);
      await first.started.future;

      // Killed after `_dirty=true` and the `_prev` copy, before the new value.
      final afterKill = StorageService(prefs);
      addTearDown(afterKill.onClose);
      final restarted = CheckpointCoordinator(storage: afterKill);
      expect(restarted.wasDirtyOnLoad, isTrue);

      Object? restored;
      restarted.registerParticipant('player', snapshot: () => {}, restore: (d) => restored = d);
      expect(restarted.restoreLatest().isSuccess, isTrue);
      expect(restored, {'hp': 5}, reason: 'the half-written commit must not replace the last good one');

      first.release.complete();
      await inFlight;
    });

    test('a checkpoint that finished before the kill is NOT reported dirty on the next boot', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = StorageService(prefs);
      addTearDown(first.onClose);
      final writer = CheckpointCoordinator(storage: first);
      writer.registerParticipant('player', snapshot: () => {'hp': 5}, restore: (_) {});
      expect((await writer.requestCheckpoint(critical: true)).isSuccess, isTrue);

      final afterKill = StorageService(prefs);
      addTearDown(afterKill.onClose);
      expect(CheckpointCoordinator(storage: afterKill).wasDirtyOnLoad, isFalse);
    });

    test('checkpoint killed AFTER a torn current write: the previous generation restores', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = StorageService(prefs);
      addTearDown(first.onClose);
      final writer = CheckpointCoordinator(storage: first);
      var hp = 5;
      writer.registerParticipant('player', snapshot: () => {'hp': hp}, restore: (_) {});
      await writer.requestCheckpoint(critical: true);
      hp = 1;
      await writer.requestCheckpoint(critical: true);

      // The second commit was torn on disk: `_prev` holds the first, the
      // current key holds garbage, and the dirty flag was never cleared.
      await prefs.setString(StorageKeys.checkpointCoordinatorV1, '{"version":1,"partic');
      await prefs.setBool('${StorageKeys.checkpointCoordinatorV1}_dirty', true);

      final afterKill = StorageService(prefs);
      addTearDown(afterKill.onClose);
      final restarted = CheckpointCoordinator(storage: afterKill);
      expect(restarted.wasDirtyOnLoad, isTrue);
      Object? restored;
      restarted.registerParticipant('player', snapshot: () => {}, restore: (d) => restored = d);
      expect(restarted.restoreLatest().isSuccess, isTrue);
      expect(restored, {'hp': 5});
    });
  });
}
