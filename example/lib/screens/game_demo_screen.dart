import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_app_bar.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_dialog.dart';

/// Demo screen for the Flame starter template (FEAT-14). Also the one place
/// in this example app that shows `NeonDialog.overlay` doing the job its
/// doc comment (`lib/presentation/widgets/neon_dialog.dart`) describes: a
/// dialog rendered ON TOP of a real full-screen `GameWidget`, where
/// `Get.dialog`/`showDialog` would be a no-op there (nothing to push a route
/// over a full-screen Flame game).
class GameDemoScreen extends StatefulWidget {
  const GameDemoScreen({super.key});

  @override
  State<GameDemoScreen> createState() => _GameDemoScreenState();
}

class _GameDemoScreenState extends State<GameDemoScreen> {
  final _game = RoyGame();
  bool _showInfo = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: GameWidget(game: _game)),
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
    );
  }
}
