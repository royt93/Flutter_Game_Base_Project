import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_translations.dart';
import '../../core/audio_manager.dart';
import '../../core/locale_service.dart';
import '../../core/neon_theme.dart';
import '../controllers/game_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  TextStyle _t(double size, {Color color = Colors.white, FontWeight w = FontWeight.w700}) =>
      TextStyle(
        fontFamily: 'Orbitron',
        color: color,
        fontSize: size,
        fontWeight: w,
        letterSpacing: 1,
      );

  @override
  Widget build(BuildContext context) {
    final locale = Get.find<LocaleService>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: NeonTheme.bgGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: Get.back,
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'settings'.tr,
                      style: _t(24, w: FontWeight.w800).copyWith(
                        shadows: const [Shadow(color: NeonTheme.purple, blurRadius: 16)],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // --- Âm thanh ---
                    _card(
                      color: NeonTheme.cyan,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('sound'.tr, style: _t(16)),
                          if (AudioManager.maybe != null)
                            Obx(() => Switch(
                                  value: !AudioManager.maybe!.muted.value,
                                  activeThumbColor: NeonTheme.cyan,
                                  onChanged: (_) => AudioManager.maybe!.toggleMute(),
                                )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // --- Ngôn ngữ ---
                    _card(
                      color: NeonTheme.lime,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('language'.tr, style: _t(16)),
                          const SizedBox(height: 12),
                          ...AppTranslations.supported.map((l) {
                            final code = AppTranslations.codeOf(l);
                            return Obx(() {
                              final selected = locale.isCurrent(l);
                              return GestureDetector(
                                onTap: () => locale.change(l),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected ? NeonTheme.lime : Colors.white24,
                                      width: 2,
                                    ),
                                    boxShadow:
                                        selected ? NeonTheme.glow(NeonTheme.lime, blur: 8) : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        AppTranslations.languageNames[code] ?? code,
                                        style: _t(15, w: FontWeight.w600),
                                      ),
                                      if (selected)
                                        const Icon(Icons.check_circle,
                                            color: NeonTheme.lime, size: 22),
                                    ],
                                  ),
                                ),
                              );
                            });
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // --- Reset tiến độ ---
                    _card(
                      color: NeonTheme.magenta,
                      child: GestureDetector(
                        onTap: () => _confirmReset(),
                        child: Row(
                          children: [
                            const Icon(Icons.restart_alt, color: NeonTheme.magenta),
                            const SizedBox(width: 12),
                            Text('reset_progress'.tr, style: _t(16)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Color color, required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NeonTheme.panel.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
          boxShadow: NeonTheme.glow(color, blur: 8),
        ),
        child: child,
      );

  void _confirmReset() {
    Get.dialog(
      AlertDialog(
        backgroundColor: NeonTheme.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: NeonTheme.magenta, width: 2),
        ),
        content: Text('reset_confirm_msg'.tr, style: _t(15, w: FontWeight.w500)),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text('cancel'.tr, style: _t(14, color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              await Get.find<GameController>().resetProgress();
              Get.back();
              Get.snackbar(
                '',
                'reset_done'.tr,
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: NeonTheme.panel,
                colorText: Colors.white,
                margin: const EdgeInsets.all(16),
              );
            },
            child: Text('confirm'.tr, style: _t(14, color: NeonTheme.magenta)),
          ),
        ],
      ),
    );
  }
}
