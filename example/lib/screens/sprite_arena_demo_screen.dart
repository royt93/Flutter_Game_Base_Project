import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

import '../game/sprite_arena_game.dart';

class SpriteArenaDemoScreen extends StatefulWidget {
  const SpriteArenaDemoScreen({super.key, this.game});

  final SpriteArenaGame? game;

  @override
  State<SpriteArenaDemoScreen> createState() => _SpriteArenaDemoScreenState();
}

class _SpriteArenaDemoScreenState extends State<SpriteArenaDemoScreen> {
  final _haptics = HapticChoreographer();
  late final SpriteArenaGame _game;
  bool _showingHelp = false;
  bool _resumeAfterHelp = false;

  @override
  void initState() {
    super.initState();
    _game = widget.game ?? SpriteArenaGame();
  }

  void _togglePause() {
    if (_game.phase.value == ArenaPhase.playing) {
      _game.pauseEngine();
    } else if (_game.phase.value == ArenaPhase.paused) {
      _game.resumeEngine();
    }
  }

  void _openHelp() {
    if (_showingHelp || !_game.isLoaded) return;
    _resumeAfterHelp = _game.phase.value == ArenaPhase.playing;
    if (_resumeAfterHelp) _game.pauseEngine();
    setState(() => _showingHelp = true);
  }

  void _closeHelp() {
    if (!_showingHelp) return;
    setState(() => _showingHelp = false);
    if (_resumeAfterHelp) {
      _resumeAfterHelp = false;
      _game.resumeEngine();
    }
  }

  void _back() {
    if (_showingHelp) {
      _closeHelp();
    } else {
      Get.back();
    }
  }

  void _attack() {
    if (!_game.attackEnabled || _showingHelp) return;
    _haptics.play(HapticPattern([const HapticPulse(level: HapticLevel.light)]));
    unawaited(AudioManager.maybe?.playSfx('audio/tap.ogg', volume: 0.5));
    _game.attack();
  }

  @override
  void dispose() {
    _haptics.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_showingHelp,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && _showingHelp) _closeHelp();
    },
    child: Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = constraints.maxWidth < 340 ? 8.0 : 16.0;
            final attackWidth = math.min(110.0, constraints.maxWidth * 0.4);
            final joystickSize = math.min(
              130.0,
              math.min(
                constraints.maxHeight * 0.4,
                constraints.maxWidth - padding * 2 - attackWidth - 16,
              ),
            );
            return ValueListenableBuilder<ArenaPhase>(
              valueListenable: _game.phase,
              builder: (context, phase, _) {
                final ready =
                    phase == ArenaPhase.playing ||
                    phase == ArenaPhase.paused ||
                    phase == ArenaPhase.gameOver;
                final controllable =
                    phase == ArenaPhase.playing || phase == ArenaPhase.paused;
                return SizedBox.expand(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: GameWidget<RoyGame>(
                            game: _game,
                            loadingBuilder: (_) => _status(loading: true),
                            errorBuilder: (_, error) => _status(loading: false),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: RepaintBoundary(
                          child: NeonAppBar(
                            title: 'sprite_arena_title'.tr,
                            onBack: _back,
                            actions: [
                              if (controllable) ...[
                                IconButton(
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  tooltip: 'sprite_arena_controls_tooltip'.tr,
                                  onPressed: _openHelp,
                                  icon: Icon(
                                    Icons.info_outline,
                                    color: NeonTheme.cyan,
                                  ),
                                ),
                                SizedBox.square(
                                  dimension: 48,
                                  child: FloatingActionButton(
                                    heroTag: 'arena_pause',
                                    tooltip: phase == ArenaPhase.paused
                                        ? 'pause_resume'.tr
                                        : 'game_demo_pause_tooltip'.tr,
                                    onPressed: _togglePause,
                                    backgroundColor: NeonTheme.cyan,
                                    child: Icon(
                                      phase == ArenaPhase.paused
                                          ? Icons.play_arrow
                                          : Icons.pause,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (ready)
                        Positioned(
                          top: 76,
                          left: padding,
                          child: ValueListenableBuilder<int>(
                            valueListenable: _game.score,
                            builder: (context, score, _) => Semantics(
                              liveRegion: true,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: NeonTheme.card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: NeonTheme.cyan,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  'sprite_arena_score'.trParams({
                                    'n': '$score',
                                  }),
                                  style: TextStyle(
                                    color: NeonTheme.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (ready)
                        Positioned(
                          top: 76,
                          right: padding,
                          child: ValueListenableBuilder<int>(
                            valueListenable: _game.lives,
                            builder: (context, lives, _) =>
                                ValueListenableBuilder<int>(
                                  valueListenable: _game.wave,
                                  builder: (context, wave, _) => Container(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth * 0.62,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: NeonTheme.card,
                                      border: Border.all(
                                        color: NeonTheme.cyan,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Semantics(
                                      liveRegion: true,
                                      label: 'sprite_arena_status_semantics'
                                          .trParams({
                                            'lives': '$lives',
                                            'wave': '$wave',
                                          }),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.favorite,
                                            size: 18,
                                            color: NeonTheme.pink,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$lives',
                                            style: TextStyle(
                                              color: NeonTheme.ink,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Icon(
                                            Icons.waves,
                                            size: 18,
                                            color: NeonTheme.cyan,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              'sprite_arena_wave'.trParams({
                                                'n': '$wave',
                                              }),
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: NeonTheme.ink,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      if (controllable)
                        Positioned(
                          left: padding,
                          right: padding,
                          bottom: 16,
                          child: RepaintBoundary(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                AbsorbPointer(
                                  absorbing:
                                      phase != ArenaPhase.playing ||
                                      _showingHelp,
                                  child: GameJoystick(
                                    semanticLabel:
                                        'game_demo_joystick_label'.tr,
                                    size: joystickSize,
                                    knobSize: math.min(48, joystickSize * 0.42),
                                    onDirectionChanged: (direction, vector) {
                                      if (_game.attackEnabled &&
                                          !_showingHelp) {
                                        _game.player?.setMoveInput(
                                          direction,
                                          vector,
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const Spacer(),
                                CommonButton(
                                  label: 'game_demo_attack_button'.tr,
                                  width: attackWidth,
                                  color: NeonTheme.orange,
                                  onTap: _game.attackEnabled && !_showingHelp
                                      ? _attack
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (phase == ArenaPhase.gameOver)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.55),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(16),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: constraints.maxHeight - 32,
                              ),
                              child: SingleChildScrollView(
                                child: PanelCard(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Semantics(
                                        liveRegion: true,
                                        child: Text(
                                          'sprite_arena_game_over'.tr,
                                          style: TextStyle(
                                            color: NeonTheme.ink,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'sprite_arena_final_score'.trParams({
                                          'n': '${_game.score.value}',
                                          'wave': '${_game.wave.value}',
                                        }),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: NeonTheme.inkSoft,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      CommonButton(
                                        label: 'sprite_arena_restart'.tr,
                                        width: math.min(
                                          200,
                                          constraints.maxWidth - 64,
                                        ),
                                        onTap: () {
                                          _game.restart();
                                          setState(() {});
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      CommonButton(
                                        label: 'back_button_label'.tr,
                                        variant: CommonButtonVariant.secondary,
                                        width: math.min(
                                          200,
                                          constraints.maxWidth - 64,
                                        ),
                                        onTap: Get.back,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (phase == ArenaPhase.paused && !_showingHelp)
                        Positioned(
                          top: 80,
                          bottom: joystickSize + 32,
                          left: 16,
                          right: 16,
                          child: Center(
                            child: SingleChildScrollView(
                              child: PanelCard(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        'pause_title'.tr,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: NeonTheme.ink,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    CommonButton(
                                      label: 'pause_resume'.tr,
                                      variant: CommonButtonVariant.secondary,
                                      width: math.min(
                                        160,
                                        constraints.maxWidth - 80,
                                      ),
                                      onTap: _togglePause,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_showingHelp)
                        Positioned.fill(
                          child: NeonDialog.overlay(
                            onBarrier: _closeHelp,
                            panel: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: constraints.maxHeight - 16,
                              ),
                              child: SingleChildScrollView(
                                child: NeonDialog.panel(
                                  title: 'sprite_arena_help_title'.tr,
                                  color: NeonTheme.cyan,
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('sprite_arena_help_move'.tr),
                                      const SizedBox(height: 8),
                                      Text('sprite_arena_help_attack'.tr),
                                      const SizedBox(height: 8),
                                      Text('sprite_arena_help_pause'.tr),
                                    ],
                                  ),
                                  actions: [
                                    NeonDialogAction(
                                      label: 'ok'.tr,
                                      color: NeonTheme.cyan,
                                      onTap: _closeHelp,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );

  Widget _status({required bool loading}) => ColoredBox(
    color: NeonTheme.bgMid,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 88, 24, 16),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator()
              else
                Icon(Icons.error_outline, size: 48, color: NeonTheme.red),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  (loading ? 'sprite_arena_loading' : 'sprite_arena_error').tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: NeonTheme.ink, fontSize: 18),
                ),
              ),
              if (!loading) ...[
                const SizedBox(height: 16),
                CommonButton(
                  label: 'back_button_label'.tr,
                  width: 140,
                  onTap: _back,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
