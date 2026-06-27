import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../core/neon_theme.dart';
import '../controllers/versus_controller.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_button.dart';
import '../widgets/neon_dialog.dart';

/// Màn 2 người 1 máy (Wave 8.7 — chạy ENGINE Flame như mode thường → đủ juice).
/// Chọn chế độ → đếm ngược → 2 bàn split dọc (người trên xoay 180°) → kết quả.
class VersusScreen extends StatefulWidget {
  const VersusScreen({super.key});

  @override
  State<VersusScreen> createState() => _VersusScreenState();
}

enum _Phase { select, countdown, playing }

class _VersusScreenState extends State<VersusScreen> {
  static const String _tag = 'versus';
  _Phase _phase = _Phase.select;
  int _count = 3;
  Timer? _countTimer;
  bool _showExitOverlay = false; // dialog xác nhận thoát

  VersusController get _ctrl => Get.find<VersusController>(tag: _tag);
  bool get _hasCtrl => Get.isRegistered<VersusController>(tag: _tag);

  @override
  void dispose() {
    _countTimer?.cancel();
    // Pause games trước khi xóa → dừng game loop ngay, không render trong lúc teardown
    if (_hasCtrl) {
      _ctrl.game1.paused = true;
      _ctrl.game2.paused = true;
    }
    if (_hasCtrl) Get.delete<VersusController>(tag: _tag);
    super.dispose();
  }

  void _requestExit() => setState(() => _showExitOverlay = true);
  void _cancelExit() => setState(() => _showExitOverlay = false);

  // Pause games TRƯỚC khi navigate → không còn render frame trong animation thoát
  void _exitNow() {
    if (_hasCtrl) {
      _ctrl.game1.paused = true;
      _ctrl.game2.paused = true;
    }
    Get.back();
  }

  void _pick(VersusMode mode) {
    if (_hasCtrl) Get.delete<VersusController>(tag: _tag);
    Get.put(VersusController(mode), tag: _tag);
    _startCountdown();
  }

  void _replay() {
    final mode = _ctrl.mode;
    Get.delete<VersusController>(tag: _tag);
    Get.put(VersusController(mode), tag: _tag);
    _startCountdown();
  }

  void _startCountdown() {
    setState(() {
      _phase = _Phase.countdown;
      _count = 3;
    });
    _countTimer?.cancel();
    _countTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _count--);
      if (_count <= 0) {
        t.cancel();
        _ctrl.start();
        setState(() => _phase = _Phase.playing);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBg(
        accent: NeonTheme.magenta,
        child: SafeArea(
          child: Stack(
            children: [
              switch (_phase) {
                _Phase.select => _buildSelect(),
                _Phase.countdown => _buildCountdown(),
                _Phase.playing => _buildPlaying(),
              },
              // Dialog xác nhận thoát — overlay trong-cây (GameWidget không chặn)
              if (_showExitOverlay) _buildExitOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExitOverlay() {
    return NeonDialog.overlay(
      onBarrier: _cancelExit,
      panel: NeonDialog.panel(
        title: 'quit_title'.tr,
        color: NeonTheme.magenta,
        icon: Icons.exit_to_app_rounded,
        message: 'quit_msg'.tr,
        actions: [
          NeonDialogAction(
            label: 'cancel'.tr,
            color: NeonTheme.cyan,
            onTap: _cancelExit,
          ),
          NeonDialogAction(
            label: 'btn_home'.tr,
            color: NeonTheme.magenta,
            onTap: _exitNow,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- chọn chế độ
  Widget _buildSelect() {
    return Padding(
      padding: const EdgeInsets.all(NeonTheme.s24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'versus_title'.tr,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [Shadow(color: NeonTheme.magenta, blurRadius: 16)],
            ),
          ),
          const SizedBox(height: NeonTheme.s8),
          Text(
            'versus_pick'.tr,
            style: const TextStyle(
              fontFamily: 'Baloo2',
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: NeonTheme.s24 * 1.5),
          _modeButton(
            'versus_mode'.tr,
            'versus_mode_desc'.tr,
            Icons.sports_kabaddi_rounded,
            NeonTheme.magenta,
            () => _pick(VersusMode.versus),
          ),
          const SizedBox(height: NeonTheme.s16),
          _modeButton(
            'coop_mode'.tr,
            'coop_mode_desc'.tr,
            Icons.handshake_rounded,
            NeonTheme.lime,
            () => _pick(VersusMode.coop),
          ),
          const SizedBox(height: NeonTheme.s24 * 1.5),
          NeonButton(
            label: 'btn_home'.tr,
            color: NeonTheme.purple,
            icon: Icons.home_rounded,
            onTap: Get.back,
          ),
        ],
      ),
    );
  }

  Widget _modeButton(
    String title,
    String desc,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: NeonTheme.s16,
          horizontal: NeonTheme.s24,
        ),
        decoration: BoxDecoration(
          color: NeonTheme.panel.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color, width: 1.8),
          boxShadow: NeonTheme.glow(color, blur: 10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(width: NeonTheme.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- đếm ngược
  Widget _buildCountdown() {
    return Stack(
      children: [
        Center(
          child:
              Text(
                _count > 0 ? '$_count' : 'versus_go'.tr,
                key: ValueKey(_count),
                style: TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [Shadow(color: NeonTheme.magenta, blurRadius: 24)],
                ),
              ).animate().scale(
                begin: const Offset(0.4, 0.4),
                end: const Offset(1, 1),
                duration: 400.ms,
                curve: Curves.easeOutBack,
              ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white70,
              size: 28,
            ),
            onPressed: _requestExit,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- chơi
  Widget _buildPlaying() {
    final c = _ctrl;
    return Stack(
      children: [
        Column(
          children: [
            // Người 2 (trên) — xoay 180° để ngồi đối diện
            Expanded(
              child: RotatedBox(
                quarterTurns: 2,
                child: _playerPane(c, 2, NeonTheme.cyan),
              ),
            ),
            _centerBar(c),
            // Người 1 (dưới)
            Expanded(child: _playerPane(c, 1, NeonTheme.magenta)),
          ],
        ),
        Obx(
          () => c.finished.value
              ? NeonDialog.overlay(panel: _resultPanel(c))
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _playerPane(VersusController c, int player, Color accent) {
    final g = player == 1 ? c.g1 : c.g2;
    final game = player == 1 ? c.game1 : c.game2;
    return Padding(
      padding: const EdgeInsets.all(NeonTheme.s8),
      child: Column(
        children: [
          Obx(
            () => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_rounded, color: accent, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${(player == 1 ? 'versus_p1' : 'versus_p2').tr}  ${g.score.value}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [Shadow(color: accent, blurRadius: 8)],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: GameWidget(game: game)),
        ],
      ),
    );
  }

  Widget _centerBar(VersusController c) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 4,
        horizontal: NeonTheme.s8,
      ),
      color: Colors.black.withValues(alpha: 0.35),
      child: Obx(() {
        final t = c.timeLeft.value;
        final low = t <= 10;
        return Row(
          children: [
            // Nút thoát
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white54,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: _requestExit,
            ),
            const Spacer(),
            Icon(
              Icons.timer_rounded,
              color: low ? NeonTheme.magenta : NeonTheme.cyan,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              '$t',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: low ? NeonTheme.magenta : Colors.white,
              ),
            ),
            if (c.mode == VersusMode.coop) ...[
              const SizedBox(width: NeonTheme.s16),
              Text(
                '${'coop_goal'.tr} ${c.combinedScore}/${VersusController.coopGoal}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: NeonTheme.lime,
                ),
              ),
            ],
            const Spacer(),
            const SizedBox(width: 36), // cân bằng với nút X bên trái
          ],
        );
      }),
    );
  }

  Widget _resultPanel(VersusController c) {
    final o = c.outcome.value;
    final (title, color) = switch (o) {
      VersusOutcome.p1 => ('versus_p1_win'.tr, NeonTheme.magenta),
      VersusOutcome.p2 => ('versus_p2_win'.tr, NeonTheme.cyan),
      VersusOutcome.draw => ('versus_draw'.tr, NeonTheme.yellow),
      VersusOutcome.coopWin => ('coop_win'.tr, NeonTheme.lime),
      VersusOutcome.coopLose => ('coop_lose'.tr, NeonTheme.orange),
      VersusOutcome.none => ('', NeonTheme.cyan),
    };
    return NeonDialog.panel(
      title: title,
      color: color,
      icon: o == VersusOutcome.coopLose
          ? Icons.timer_off_rounded
          : Icons.emoji_events_rounded,
      message: c.mode == VersusMode.coop
          ? '${'coop_goal'.tr}: ${c.combinedScore} / ${VersusController.coopGoal}'
          : '${'versus_p1'.tr} ${c.score1}  ·  ${'versus_p2'.tr} ${c.score2}',
      actions: [
        NeonDialogAction(
          label: 'btn_again'.tr,
          color: NeonTheme.cyan,
          onTap: _replay,
        ),
        NeonDialogAction(
          label: 'btn_home'.tr,
          color: NeonTheme.purple,
          onTap: Get.back,
        ),
      ],
    );
  }
}
