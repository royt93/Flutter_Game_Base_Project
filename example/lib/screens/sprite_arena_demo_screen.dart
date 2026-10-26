import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

import '../game/sprite_arena_game.dart';

/// Full-screen 2D playable character demo with Tiled terrain collision,
/// 8-direction virtual joystick, and attack action. Dedicated mini-game screen
/// cleanly separated from the classic starter circle demo.
class SpriteArenaDemoScreen extends StatefulWidget {
  const SpriteArenaDemoScreen({super.key});

  @override
  State<SpriteArenaDemoScreen> createState() => _SpriteArenaDemoScreenState();
}

class _SpriteArenaDemoScreenState extends State<SpriteArenaDemoScreen> {
  static const _sfxTap = 'audio/tap.ogg';
  final _haptics = HapticChoreographer();
  late final SpriteArenaGame _game;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _game = SpriteArenaGame();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _game.pauseEngine();
    } else {
      _game.resumeEngine();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(child: GameWidget<RoyGame>(game: _game)),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: RepaintBoundary(
                  child: NeonAppBar(
                    title: 'sprite_arena_title'.tr,
                    onBack: Get.back,
                  ),
                ),
              ),
              Positioned(
                left: NeonTheme.s16,
                bottom: NeonTheme.s24,
                child: RepaintBoundary(
                  child: GameJoystick(
                    semanticLabel: 'game_demo_joystick_label'.tr,
                    size: 130,
                    knobSize: 48,
                    onDirectionChanged: (direction, vector) {
                      _game.player?.setMoveInput(direction, vector);
                    },
                  ),
                ),
              ),
              Positioned(
                right: NeonTheme.s24,
                bottom: NeonTheme.s24,
                child: RepaintBoundary(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _game.attackEnabled,
                    builder: (context, enabled, child) => CommonButton(
                      label: 'game_demo_attack_button'.tr,
                      variant: CommonButtonVariant.primary,
                      width: 110,
                      color: NeonTheme.orange,
                      onTap: !enabled
                          ? null
                          : () {
                              if (!_game.attackEnabled.value) return;
                              _haptics.play(
                                HapticPattern([
                                  const HapticPulse(level: HapticLevel.light),
                                ]),
                              );
                              unawaited(
                                AudioManager.maybe?.playSfx(
                                  _sfxTap,
                                  volume: 0.5,
                                ),
                              );
                              _game.attack();
                            },
                    ),
                  ),
                ),
              ),
              Positioned(
                right: NeonTheme.s16,
                top: kToolbarHeight + NeonTheme.s16,
                child: RepaintBoundary(
                  child: FloatingActionButton(
                    heroTag: 'arena_pause',
                    tooltip: 'game_demo_pause_tooltip'.tr,
                    backgroundColor: NeonTheme.cyan,
                    onPressed: _togglePause,
                    child: Icon(
                      _paused ? Icons.play_arrow : Icons.pause,
                      color: Colors.white,
                    ),
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
