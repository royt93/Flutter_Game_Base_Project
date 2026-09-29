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
  const GameDemoScreen({super.key, this.eventBus});

  /// Optional test/demo seam. When omitted, this screen owns a fresh bus.
  final GameEventBus? eventBus;

  @override
  State<GameDemoScreen> createState() => _GameDemoScreenState();
}

class _GameDemoScreenState extends State<GameDemoScreen> {
  static const _sfxTap = 'audio/tap.ogg';
  static const _sfxVictory = 'audio/victory.ogg';
  static const _sfxError = 'audio/error.ogg';

  // FEAT-88: set in initState (before `_game`, which needs it in its own
  // constructor) rather than a field initializer, so a test can inject a
  // fake bus via widget.eventBus (BUG-93). Bridges TappableCircle's tap —
  // a Flame-world gameplay event — to 2 independent business-logic
  // services below, without RoyGame itself knowing either one exists.
  late final GameEventBus _eventBus;
  late final bool _ownsEventBus;
  final _haptics = HapticChoreographer();
  late final RoyGame _game;
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
  late final _session =
      Get.put<GameSessionController>(
          GameSessionController(lifecycle: RoyLifecycleCoordinator.maybe),
        )
        ..markReady()
        ..start();

  // BUG-91: `_session.pause/resume` used to be pure UI/session state — the
  // Flame engine underneath (`_game`, a real `FlameGame`) kept ticking
  // `BouncingOrb.update` under the pause overlay, so the "paused" UI lied
  // about whether gameplay simulation had actually stopped. Listening to
  // PHASE CHANGES (not to a specific pause/resume ACTION call site) catches
  // every source uniformly — the FAB below, AND `GameSessionController`'s
  // own `RoyLifecycleCoordinator` hook (registered in its `onInit()`) that
  // pauses/resumes with `GamePauseReason.system` directly, bypassing any
  // helper this screen could define. Same `ever()`/`Worker` pattern already
  // used in `lib/presentation/widgets/shader_ticker_layer.dart`.
  late final Worker _sessionPhaseWorker;

  late final EconomyWallet _wallet;
  late final EnergyService _energy;
  late final PlayerProgressionService _progression;
  late final LocalScoreboardService _scoreboard;
  late final AchievementService _achievements;
  int _tapCount = 0;
  int _roundTaps = 0;
  int _roundScore = 0;
  bool _roundActive = false;
  String _roundStatus = 'Spend 1 energy, then tap Circle 5 times to win.';
  int _confettiBurstKey = 0;
  bool _showConfetti = false;
  bool _showAchievementBanner = false;
  StreamSubscription<String>? _unlockSub;
  StreamSubscription<GameEvent>? _tapSub;

  static const _tapAchievementId = 'game_demo_circle_tap_master';
  static const _tapAchievementThreshold = 10;

  @override
  void initState() {
    super.initState();
    _ownsEventBus = widget.eventBus == null;
    _eventBus = widget.eventBus ?? GameEventBus();
    _game = RoyGame(eventBus: _eventBus);
    _sessionPhaseWorker = ever<GameSessionSnapshot>(_session.snapshot, (
      snapshot,
    ) {
      if (snapshot.phase == GameSessionPhase.paused && !_game.paused) {
        _game.pauseEngine();
      } else if (snapshot.phase == GameSessionPhase.playing && _game.paused) {
        _game.resumeEngine();
      }
    });
    _wallet =
        EconomyWallet.maybe ??
        Get.put(EconomyWallet(storage: StorageService.to), permanent: true);
    _energy =
        EnergyService.maybe ??
        Get.put(
          EnergyService(
            maxEnergy: 5,
            refillInterval: const Duration(minutes: 10),
          ),
          permanent: true,
        );
    _progression =
        PlayerProgressionService.maybe ??
        Get.put(
          PlayerProgressionService(
            storage: StorageService.to,
            levelCurve: const [
              LevelDefinition(level: 1, xpToNext: 100),
              LevelDefinition(level: 2, xpToNext: 200),
              LevelDefinition(level: 3, xpToNext: 400),
              LevelDefinition(level: 4, xpToNext: 800),
              LevelDefinition(level: 5, xpToNext: 0),
            ],
          ),
          permanent: true,
        );
    _scoreboard =
        LocalScoreboardService.maybe ??
        Get.put(LocalScoreboardService(capacity: 20), permanent: true);
    _achievements =
        AchievementService.maybe ??
        Get.put(AchievementService(), permanent: true);
    _achievements.register(_tapAchievementId, _tapAchievementThreshold);

    _unlockSub = _achievements.onUnlock.listen((id) async {
      if (id == _tapAchievementId) {
        _haptics.play(HapticPattern.reward);
        unawaited(AudioManager.maybe?.playSfx(_sfxTap, duck: true));
        _confettiBurstKey++;
        _showConfetti = true;
        _showAchievementBanner = true;
        await _wallet.earn(
          currency: 'gems',
          amount: 10,
          transactionId: 'bonus_tap_master',
        );
        if (mounted) setState(() {});
      }
    });

    // `earn()` is async (writes to real storage — no guaranteed-synchronous
    // completion on a real device, unlike the fast microtask-only path a
    // mocked SharedPreferences test can hit). Awaiting it before the
    // trailing setState() below is what a device smoke test caught: firing
    // it with `unawaited()` and calling setState() immediately after would
    // rebuild the badge with the STALE gem balance on a real device.
    _tapSub = _eventBus.subscribe<CircleTappedEvent>((_) async {
      _tapCount++;
      if (_roundActive) _roundTaps++;
      _roundScore += 10;
      _haptics.play(
        _tapCount % 5 == 0
            ? HapticPattern.combo
            : HapticPattern([const HapticPulse(level: HapticLevel.light)]),
      );
      unawaited(AudioManager.maybe?.playSfx(_sfxTap, volume: 0.45));
      await _wallet.earn(
        currency: 'gems',
        amount: 1,
        transactionId: 'game_demo_circle_tap_$_tapCount',
      );
      if (!_achievements.isCompleted(_tapAchievementId)) {
        _achievements.incrementProgress(_tapAchievementId, 1);
      }
      if (_roundActive && _roundTaps >= 5) {
        _roundActive = false;
        await _finishRound();
      }
      if (mounted) setState(() {});
    });
  }

  void _restartGame() {
    // PauseOverlay's package-level default can only reset the abstract
    // session back to `loading`; this concrete demo also owns the Flame
    // engine, so complete its known local boot flow immediately. The
    // `_sessionPhaseWorker` above observes the final `playing` transition
    // and resumes the engine — without this callback Restart hid the overlay
    // at `loading` but left `_game.paused == true` forever.
    _session.restart();
    _session.markReady();
    _session.start();
  }

  void _startRound() {
    if (!_energy.consumeEnergy()) {
      _haptics.play(HapticPattern.error);
      unawaited(AudioManager.maybe?.playSfx(_sfxError));
      setState(() {
        _roundStatus = 'Not enough energy. Wait for refill.';
      });
      return;
    }
    setState(() {
      _roundActive = true;
      _roundTaps = 0;
      _roundScore = 0;
      _roundStatus = 'Round active: tap Circle 5 times!';
    });
  }

  Future<void> _finishRound() async {
    final prevLevel = _progression.snapshot.value.level;
    final xpResult = await _progression.grantXp(
      amount: 40,
      transactionId: 'round_xp_${DateTime.now().microsecondsSinceEpoch}',
    );
    await _wallet.earn(
      currency: 'coins',
      amount: 30,
      transactionId: 'round_coins_${DateTime.now().microsecondsSinceEpoch}',
    );
    if (_roundScore > 0) {
      _scoreboard.submitScore('Hero Player', _roundScore);
    }
    _haptics.play(HapticPattern.reward);
    unawaited(AudioManager.maybe?.playSfx(_sfxVictory, duck: true));
    final currentLevel =
        xpResult.value?.level ?? _progression.snapshot.value.level;
    final levelUpMsg = currentLevel > prevLevel
        ? ' LEVEL UP to Lv.$currentLevel!'
        : '';
    if (!mounted) return;
    setState(() {
      _confettiBurstKey++;
      _showConfetti = true;
      _roundStatus = 'Victory! +40 XP, +30 coins.$levelUpMsg';
    });
    // ponytail: keep reward feedback in screen state; add a transient toast
    // when host app owns snackbar lifecycle and teardown policy.
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
    // Dispose the worker BEFORE Get.delete — it listens to `_session.
    // snapshot` (a Rx owned by `_session`), so it must stop before that Rx
    // is torn down.
    _sessionPhaseWorker.dispose();
    _haptics.cancel();
    unawaited(_unlockSub?.cancel());
    // BUG-93: was previously discarded at subscribe time — the underlying
    // `StreamController.broadcast()` in `GameEventBus` doesn't auto-cancel
    // listeners on `dispose()`, so this subscription (and its captured
    // `context`/`this` closure) leaked past screen teardown until now.
    unawaited(_tapSub?.cancel());
    Get.delete<GameSessionController>(force: true);
    if (_ownsEventBus) unawaited(_eventBus.dispose());
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
                child: RepaintBoundary(
                  child: GameWidget(key: _gameWidgetKey, game: _game),
                ),
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
                child: RepaintBoundary(
                  child: NeonAppBar(title: 'game_demo'.tr, onBack: Get.back),
                ),
              ),
              // FEAT-88: live proof the GameEventBus subscriber wiring
              // actually reached both EconomyWallet AND AchievementService
              // from a single CircleTappedEvent, not just "didn't throw".
              Positioned(
                top: kToolbarHeight + NeonTheme.s16,
                left: NeonTheme.s16,
                child: RepaintBoundary(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: NeonTheme.card,
                      borderRadius: BorderRadius.circular(NeonTheme.s16),
                      border: Border.all(
                        color: _achievements.isCompleted(_tapAchievementId)
                            ? NeonTheme.gold
                            : NeonTheme.cyan.withValues(alpha: 0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        ...NeonTheme.glow(
                          _achievements.isCompleted(_tapAchievementId)
                              ? NeonTheme.gold
                              : NeonTheme.cyan,
                          blur: 8,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: NeonTheme.s16,
                        vertical: NeonTheme.s8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _achievements.isCompleted(_tapAchievementId)
                                ? Icons.stars_rounded
                                : Icons.diamond_outlined,
                            size: 18,
                            color: _achievements.isCompleted(_tapAchievementId)
                                ? NeonTheme.gold
                                : NeonTheme.cyan,
                          ),
                          const SizedBox(width: NeonTheme.s8),
                          Text(
                            'gems: ${_wallet.balanceOf('gems')} | '
                            'tap: ${_achievements.progressOf(_tapAchievementId)}'
                            '/$_tapAchievementThreshold',
                            style: TextStyle(
                              color: NeonTheme.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: NeonTheme.s16,
                right: NeonTheme.s16,
                bottom: NeonTheme.s16 + 4,
                child: RepaintBoundary(
                  child: PanelCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _roundStatus,
                          style: TextStyle(
                            color: NeonTheme.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: NeonTheme.s8),
                        EnergyBar(
                          currentEnergy: _energy.currentEnergy,
                          maxEnergy: _energy.maxEnergy,
                          timeUntilNextEnergy: _energy.timeUntilNextEnergy,
                          hasInfiniteLives: _energy.hasInfiniteLives,
                          direction: Axis.horizontal,
                        ),
                        const SizedBox(height: NeonTheme.s8),
                        CommonButton(
                          label: _roundActive
                              ? 'Tap Circle: $_roundTaps / 5'
                              : 'Start Round (-1 Energy)',
                          onTap: _roundActive ? null : _startRound,
                        ),
                        const SizedBox(height: NeonTheme.s8),
                        Obx(() {
                          final progress = _progression.snapshot.value;
                          return Text(
                            'Score: $_roundScore | Lv.${progress.level} | XP: ${progress.xpIntoLevel}/${progress.xpToNextLevel} | Coins: ${_wallet.balanceOf('coins')}',
                            style: TextStyle(color: NeonTheme.inkSoft),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: NeonTheme.s16,
                bottom: 240,
                child: RepaintBoundary(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        heroTag: 'pause',
                        onPressed: () {
                          _haptics.play(HapticPattern.combo);
                          unawaited(
                            AudioManager.maybe?.playSfx(_sfxTap, volume: 0.35),
                          );
                          _session.pause(GamePauseReason.user);
                        },
                        backgroundColor: NeonTheme.cyan,
                        child: const Icon(Icons.pause, color: Colors.white),
                      ),
                      const SizedBox(height: NeonTheme.s16),
                      FloatingActionButton(
                        heroTag: 'info',
                        onPressed: () {
                          _haptics.play(HapticPattern.combo);
                          unawaited(
                            AudioManager.maybe?.playSfx(_sfxTap, volume: 0.35),
                          );
                          setState(() => _showInfo = true);
                        },
                        backgroundColor: NeonTheme.purple,
                        child: const Icon(
                          Icons.info_outline,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Nổ pháo hoa giấy và hiện banner khi hoàn thành thành tựu
              if (_showConfetti)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ConfettiOverlay(
                      key: ValueKey(_confettiBurstKey),
                      particleCount: 75,
                      duration: const Duration(milliseconds: 2400),
                      onFinished: () {
                        if (mounted) {
                          setState(() {
                            _showConfetti = false;
                            _showAchievementBanner = false;
                          });
                        }
                      },
                    ),
                  ),
                ),
              if (_showAchievementBanner)
                Positioned(
                  top: kToolbarHeight + 70,
                  left: NeonTheme.s24,
                  right: NeonTheme.s24,
                  child: const ToastBanner(
                    message:
                        '🎉 Achievement Unlocked: Circle Tap Master! +10 Gems',
                    color: null,
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
                onRestart: _restartGame,
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
