import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:roy_casual_kit/roy_casual_kit.dart';

/// Demo screen for the Flame starter template (FEAT-14). Also the one place
/// in this example app that shows `NeonDialog.overlay` doing the job its
/// doc comment (`lib/presentation/widgets/neon_dialog.dart`) describes: a
/// dialog rendered ON TOP of a real full-screen `GameWidget`, where
/// `Get.dialog`/`showDialog` would be a no-op there (nothing to push a route
/// over a full-screen Flame game). Also demos `FlameTrackedOverlay` (IDEA-07):
/// a floating pill label glued to the `TappableCircle`'s world position, and
/// `PauseOverlay` (FEAT-53) — the pause FAB pauses `_session`, which is the
/// same in-tree-overlay-over-Flame pattern the info dialog above uses.
class GameDemoScreen extends StatefulWidget {
  const GameDemoScreen({super.key});

  @override
  State<GameDemoScreen> createState() => _GameDemoScreenState();
}

class _GameDemoScreenState extends State<GameDemoScreen> {
  // FEAT-88: created before `_game` (Dart initializes instance fields in
  // declaration order) so RoyGame's constructor can take it. Bridges
  // TappableCircle's tap — a Flame-world gameplay event — to 2 independent
  // business-logic services below, without RoyGame itself knowing either
  // one exists.
  final _eventBus = GameEventBus();
  late final _game = RoyGame(eventBus: _eventBus);
  final _gameWidgetKey = GlobalKey();
  bool _showInfo = false;
  // ENH-82: without `lifecycle:`, backgrounding the app while `playing`
  // left `_session.snapshot.phase` stuck at `playing` forever — Flame's
  // OWN `pauseWhenBackgrounded` (RoyGame's default, unchanged) already
  // paused the actual render/update loop correctly on the same OS
  // lifecycle event, but nothing told GameSessionController about it, so
  // any UI/logic branching on `GameSessionPhase` (this screen's own
  // `PauseOverlay` below) silently disagreed with what was actually
  // happening on screen. `GameSessionController` already has this exact
  // hook built in (see its own `RoyLifecycleCoordinator` wiring in
  // `onInit()`) — this demo just never passed one in.
  //
  // `Get.put()`, not a plain constructor call, is REQUIRED here: GetX only
  // ever calls a `GetxController`'s `onInit()` (where the lifecycle hook
  // above actually gets registered) as part of its OWN put/find
  // dependency-injection machinery — a `GameSessionController` built via
  // its bare constructor never has `onInit()` fire at all, so passing
  // `lifecycle:` alone (without this) would silently do nothing. `onClose()`
  // is still called manually in `dispose()` below rather than through
  // `Get.delete()`, matching this field's existing (pre-ENH-82) disposal
  // style.
  late final _session = Get.put<GameSessionController>(
    GameSessionController(lifecycle: RoyLifecycleCoordinator.maybe),
  )..markReady()..start();

  late final EconomyWallet _wallet;
  late final AchievementService _achievements;
  int _tapCount = 0;

  static const _tapAchievementId = 'game_demo_circle_tap_master';
  static const _tapAchievementThreshold = 10;

  @override
  void initState() {
    super.initState();
    _wallet =
        EconomyWallet.maybe ??
        Get.put(EconomyWallet(storage: StorageService.to), permanent: true);
    _achievements =
        AchievementService.maybe ??
        Get.put(AchievementService(), permanent: true);
    _achievements.register(_tapAchievementId, _tapAchievementThreshold);
    // `earn()` is async (writes to real storage — no guaranteed-synchronous
    // completion on a real device, unlike the fast microtask-only path a
    // mocked SharedPreferences test can hit). Awaiting it before the
    // trailing setState() below is what a device smoke test caught: firing
    // it with `unawaited()` and calling setState() immediately after would
    // rebuild the badge with the STALE gem balance on a real device.
    _eventBus.subscribe<CircleTappedEvent>((_) async {
      _tapCount++;
      await _wallet.earn(
        currency: 'gems',
        amount: 1,
        transactionId: 'game_demo_circle_tap_$_tapCount',
      );
      if (!_achievements.isCompleted(_tapAchievementId)) {
        _achievements.incrementProgress(_tapAchievementId, 1);
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // ENH-82: `_session` is now `Get.put()`'d (required for its own
    // `onInit()`/lifecycle hook to ever run — see the field's own doc
    // comment), so its disposal now goes through `Get.delete()` — this
    // calls `_session.onClose()` internally (GetX's own `onDelete()` ->
    // `onClose()` chain), so a separate direct `_session.onClose()` call
    // here would double-invoke it. Matches this codebase's established
    // "always clean up your own Get registrations on dispose" convention
    // (see BUG-64/BUG-62's own fixes) — without this, re-opening this
    // screen would just silently replace the registry entry each time
    // rather than leaking, but leaving a disposed controller findable via
    // `Get.find` in the meantime is its own footgun.
    Get.delete<GameSessionController>(force: true);
    unawaited(_eventBus.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // SizedBox.expand forces tight constraints on the Stack below, so
        // its size doesn't depend on the max size of its non-positioned
        // children. Needed because FlameTrackedOverlay is a non-positioned
        // Stack child while its tracked position isn't ready yet (it builds
        // a zero-size SizedBox.shrink() during that window) — without this,
        // that transiently flips the Stack from "all children Positioned"
        // (which fills available space) to "has a non-positioned child"
        // (which sizes to that child's max, i.e. zero), collapsing the
        // whole screen — see the FEAT-14 regression comment in
        // game_demo_screen_test.dart for the same class of bug.
        child: SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: GameWidget(key: _gameWidgetKey, game: _game),
              ),
              FlameTrackedOverlay(
                game: _game,
                gameWidgetKey: _gameWidgetKey,
                worldPositionOf: () => _game.circle.position,
                childAnchor: Alignment.bottomCenter,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: NeonTheme.purple,
                    borderRadius: BorderRadius.circular(NeonTheme.s16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NeonTheme.s16,
                      vertical: NeonTheme.s8,
                    ),
                    child: const StrokeText('Circle', fontSize: 14),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: NeonAppBar(title: 'game_demo'.tr, onBack: Get.back),
              ),
              // FEAT-88: live proof the GameEventBus subscriber wiring
              // actually reached both EconomyWallet AND AchievementService
              // from a single CircleTappedEvent, not just "didn't throw".
              Positioned(
                top: kToolbarHeight + NeonTheme.s16,
                left: NeonTheme.s16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: NeonTheme.card,
                    borderRadius: BorderRadius.circular(NeonTheme.s16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NeonTheme.s16,
                      vertical: NeonTheme.s8,
                    ),
                    child: Text(
                      'gems: ${_wallet.balanceOf('gems')} | '
                      'tap: ${_achievements.progressOf(_tapAchievementId)}'
                      '/$_tapAchievementThreshold',
                      style: TextStyle(color: NeonTheme.ink),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: NeonTheme.s16,
                bottom: NeonTheme.s16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      heroTag: 'pause',
                      onPressed: () => _session.pause(GamePauseReason.user),
                      backgroundColor: NeonTheme.cyan,
                      child: const Icon(Icons.pause, color: Colors.white),
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    FloatingActionButton(
                      heroTag: 'info',
                      onPressed: () => setState(() => _showInfo = true),
                      backgroundColor: NeonTheme.purple,
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // ENH-82: `showForSystemPause: true` so this demo actually
              // shows the pause panel when the OS-background pause kicks
              // in (via `_session`'s lifecycle hook above), not just for
              // the pause FAB's user-initiated pause — the whole point of
              // this demo is illustrating that flow to a consumer copying
              // it, not just making the internal phase correct invisibly.
              PauseOverlay(
                session: _session,
                showForSystemPause: true,
                onQuit: Get.back,
              ),
              if (_showInfo)
                Positioned.fill(
                  child: NeonDialog.overlay(
                    onBarrier: () => setState(() => _showInfo = false),
                    panel: NeonDialog.panel(
                      title: 'game_demo'.tr,
                      color: NeonTheme.purple,
                      actions: [
                        NeonDialogAction(
                          label: 'ok'.tr,
                          color: NeonTheme.purple,
                          onTap: () => setState(() => _showInfo = false),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
