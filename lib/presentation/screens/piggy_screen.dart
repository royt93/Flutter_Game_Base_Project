import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../../core/utils/format.dart';
import '../controllers/game_controller.dart';
import '../controllers/piggy_controller.dart';
import '../widgets/coin_chip.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_dialog.dart';

/// Heo đất — tích xu mỗi màn thắng, đập nhận khi đủ (Wave 14).
class PiggyScreen extends StatelessWidget {
  const PiggyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = Get.find<GameController>();
    final pc = Get.put(PiggyController(g));
    const accent = NeonTheme.magenta;
    return Scaffold(
      body: NeonBg(
        accent: accent,
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(
                title: 'piggy_title'.tr,
                color: accent,
                actions: [CoinChip(g)],
              ),
              Expanded(
                child: Center(
                  child: Obx(() {
                    final full = pc.isFull;
                    final color = full ? NeonTheme.lime : accent;
                    return Padding(
                      padding: const EdgeInsets.all(NeonTheme.s24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Heo to + glow theo độ đầy.
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: NeonTheme.panel.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                              border: Border.all(color: color, width: 3),
                              boxShadow: NeonTheme.glow(color,
                                  blur: 14 + pc.progress * 18),
                            ),
                            child: Icon(Icons.savings_rounded,
                                color: color, size: 86),
                          ),
                          const SizedBox(height: NeonTheme.s24),
                          Text(
                            fmtNum(pc.saved.value),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(color: color, blurRadius: 16)],
                            ),
                          ),
                          Text(
                            '/ ${fmtNum(PiggyController.kPiggyCap)} ${'coins_short'.tr}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: NeonTheme.s16),
                          // Thanh đầy.
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: pc.progress,
                              minHeight: 10,
                              backgroundColor: NeonTheme.bgDark2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                          const SizedBox(height: NeonTheme.s24),
                          // Nút đập.
                          GestureDetector(
                            onTap:
                                pc.canSmash ? () => _smash(context, pc) : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 14),
                              decoration: BoxDecoration(
                                color: pc.canSmash
                                    ? NeonTheme.lime.withValues(alpha: 0.2)
                                    : NeonTheme.panel.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: pc.canSmash
                                      ? NeonTheme.lime
                                      : Colors.white24,
                                  width: 2,
                                ),
                                boxShadow: pc.canSmash
                                    ? NeonTheme.glow(NeonTheme.lime, blur: 10)
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.gavel_rounded,
                                      color: pc.canSmash
                                          ? NeonTheme.lime
                                          : Colors.white38,
                                      size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    'piggy_smash'.tr,
                                    style: TextStyle(
                                      color: pc.canSmash
                                          ? NeonTheme.lime
                                          : Colors.white38,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: NeonTheme.s16),
                          Text(
                            pc.canSmash
                                ? 'piggy_ready'.tr
                                : 'piggy_min'.trParams(
                                    {'n': '${PiggyController.kPiggyMin}'}),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _smash(BuildContext context, PiggyController pc) {
    final got = pc.smash();
    if (got <= 0) return;
    NeonDialog.show(
      context: context,
      title: 'piggy_smashed'.tr,
      color: NeonTheme.lime,
      icon: Icons.savings_rounded,
      message: 'piggy_got'.trParams({'n': fmtNum(got)}),
      actions: [
        NeonDialogAction(
          label: 'confirm'.tr,
          color: NeonTheme.lime,
          onTap: () {},
        ),
      ],
    );
  }
}
