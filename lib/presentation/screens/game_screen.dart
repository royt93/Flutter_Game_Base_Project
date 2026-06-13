import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/neon_theme.dart';
import '../../game/neon_jewel_game.dart';
import '../controllers/game_controller.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameController ctrl = Get.find<GameController>();
  late NeonJewelGame game;

  @override
  void initState() {
    super.initState();
    _buildGame();
  }

  void _buildGame() {
    final lv = ctrl.level;
    game = NeonJewelGame(
      controller: ctrl,
      rows: lv.rows,
      cols: lv.cols,
      colorCount: lv.colorCount,
      onGameEnd: _onGameEnd,
    );
  }

  void _onGameEnd(String result) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _showResultDialog(result == 'win');
    });
  }

  void _showResultDialog(bool win) {
    final color = win ? NeonTheme.lime : NeonTheme.magenta;
    Get.dialog(
      barrierDismissible: false,
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: NeonTheme.panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color, width: 3),
            boxShadow: NeonTheme.glow(color, blur: 28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                win ? 'CHIẾN THẮNG!' : 'THỬ LẠI',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  shadows: [Shadow(color: color, blurRadius: 20)],
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: 16),
              Text(
                'Điểm: ${ctrl.score.value}',
                style: GoogleFonts.orbitron(color: Colors.white, fontSize: 18),
              ),
              Text(
                'Mục tiêu: ${ctrl.targetScore.value}',
                style: GoogleFonts.orbitron(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _dialogBtn('LẠI', NeonTheme.cyan, () {
                    Get.back();
                    ctrl.startLevel(ctrl.currentLevel.value);
                    setState(_buildGame);
                  }),
                  const SizedBox(width: 12),
                  if (win && ctrl.currentLevel.value < 5)
                    _dialogBtn('TIẾP', NeonTheme.lime, () {
                      Get.back();
                      ctrl.startLevel(ctrl.currentLevel.value + 1);
                      setState(_buildGame);
                    })
                  else
                    _dialogBtn('VỀ', NeonTheme.purple, () {
                      Get.back();
                      Get.back();
                    }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogBtn(String label, Color c, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c, width: 2),
          boxShadow: NeonTheme.glow(c, blur: 10),
        ),
        child: Text(
          label,
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: c, blurRadius: 8)],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: NeonTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHud(),
              Expanded(child: GameWidget(game: game)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: Get.back,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
              const Spacer(),
              Obx(() => _statChip(
                    'MÀN ${ctrl.currentLevel.value}',
                    NeonTheme.purple,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Obx(() => _statChip('ĐIỂM\n${ctrl.score.value}', NeonTheme.cyan)),
              Obx(() => _statChip('MỤC TIÊU\n${ctrl.targetScore.value}', NeonTheme.lime)),
              Obx(() => _statChip('LƯỢT\n${ctrl.movesLeft.value}', NeonTheme.orange)),
            ],
          ),
          const SizedBox(height: 8),
          // Thanh tiến độ điểm
          Obx(() {
            final ratio = ctrl.targetScore.value == 0
                ? 0.0
                : (ctrl.score.value / ctrl.targetScore.value).clamp(0.0, 1.0);
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: NeonTheme.panel,
                valueColor: const AlwaysStoppedAnimation(NeonTheme.lime),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
        boxShadow: NeonTheme.glow(color, blur: 8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.orbitron(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.3,
          shadows: [Shadow(color: color, blurRadius: 8)],
        ),
      ),
    );
  }
}
