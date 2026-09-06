import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';
import 'package:roy_casual_kit/presentation/widgets/flame_tracked_overlay.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_app_bar.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_dialog.dart';
import 'package:roy_casual_kit/presentation/widgets/stroke_text.dart';

/// Demo screen for the Flame starter template (FEAT-14). Also the one place
/// in this example app that shows `NeonDialog.overlay` doing the job its
/// doc comment (`lib/presentation/widgets/neon_dialog.dart`) describes: a
/// dialog rendered ON TOP of a real full-screen `GameWidget`, where
/// `Get.dialog`/`showDialog` would be a no-op there (nothing to push a route
/// over a full-screen Flame game). Also demos `FlameTrackedOverlay` (IDEA-07):
/// a floating pill label glued to the `TappableCircle`'s world position.
class GameDemoScreen extends StatefulWidget {
  const GameDemoScreen({super.key});

  @override
  State<GameDemoScreen> createState() => _GameDemoScreenState();
}

class _GameDemoScreenState extends State<GameDemoScreen> {
  final _game = RoyGame();
  final _gameWidgetKey = GlobalKey();
  bool _showInfo = false;

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
              Positioned(
                right: NeonTheme.s16,
                bottom: NeonTheme.s16,
                child: FloatingActionButton(
                  onPressed: () => setState(() => _showInfo = true),
                  backgroundColor: NeonTheme.purple,
                  child: const Icon(Icons.info_outline, color: Colors.white),
                ),
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
