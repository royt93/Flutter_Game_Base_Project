import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_translations.dart';
import '../../core/audio_manager.dart';
import '../../core/locale_service.dart';
import '../../core/neon_theme.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_dialog.dart';

/// State UI cho màn cài đặt (GetX, không setState).
/// Dùng overlay trong-cây thay cho route dialog vì ở chế độ full-screen
/// route dialog (Get.dialog/showDialog) không render được.
class SettingsController extends GetxController {
  final RxBool showResetConfirm = false.obs;

  void askReset() {
    debugPrint('roy93~ RESET card tapped → bật overlay xác nhận');
    showResetConfirm.value = true;
  }

  void cancelReset() {
    debugPrint('roy93~ RESET huỷ');
    showResetConfirm.value = false;
  }

  Future<void> doReset() async {
    debugPrint('roy93~ RESET confirm → gọi resetProgress');
    await Get.find<GameController>().resetProgress();
    showResetConfirm.value = false;
    debugPrint('roy93~ RESET xong: unlockedLevel='
        '${Get.find<GameController>().unlockedLevel.value}');
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  TextStyle _t(double size,
          {Color color = Colors.white, FontWeight w = FontWeight.w700}) =>
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
    final ui = Get.put(SettingsController());
    return Scaffold(
      body: NeonBg(
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NeonAppBar(title: 'settings'.tr, color: NeonTheme.purple),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(NeonTheme.s24,
                          NeonTheme.s16, NeonTheme.s24, NeonTheme.s24),
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
                                      onChanged: (_) =>
                                          AudioManager.maybe!.toggleMute(),
                                    )),
                            ],
                          ),
                        ),
                        const SizedBox(height: NeonTheme.s16),
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
                                          color: selected
                                              ? NeonTheme.lime
                                              : Colors.white24,
                                          width: 2,
                                        ),
                                        boxShadow: selected
                                            ? NeonTheme.glow(NeonTheme.lime,
                                                blur: 8)
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            AppTranslations
                                                    .languageNames[code] ??
                                                code,
                                            style: _t(15, w: FontWeight.w600),
                                          ),
                                          if (selected)
                                            const Icon(Icons.check_circle,
                                                color: NeonTheme.lime,
                                                size: 22),
                                        ],
                                      ),
                                    ),
                                  );
                                });
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: NeonTheme.s16),
                        // --- Reset tiến độ (cả thẻ bấm được) ---
                        _card(
                          color: NeonTheme.magenta,
                          onTap: ui.askReset,
                          child: Row(
                            children: [
                              const Icon(Icons.restart_alt,
                                  color: NeonTheme.magenta),
                              const SizedBox(width: 12),
                              Text('reset_progress'.tr, style: _t(16)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // --- Overlay xác nhận reset (trong cây, không qua route) ---
            Obx(() => ui.showResetConfirm.value
                ? NeonDialog.overlay(
                    onBarrier: ui.cancelReset,
                    panel: NeonDialog.panel(
                      title: 'reset_progress'.tr,
                      color: NeonTheme.magenta,
                      icon: Icons.restart_alt_rounded,
                      message: 'reset_confirm_msg'.tr,
                      actions: [
                        NeonDialogAction(
                          label: 'cancel'.tr,
                          color: NeonTheme.cyan,
                          onTap: ui.cancelReset,
                        ),
                        NeonDialogAction(
                          label: 'confirm'.tr,
                          color: NeonTheme.magenta,
                          onTap: () async {
                            await ui.doReset();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('reset_done'.tr,
                                    style: _t(14, w: FontWeight.w600)),
                                backgroundColor: NeonTheme.panel,
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.all(NeonTheme.s16),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _card(
      {required Color color, required Widget child, VoidCallback? onTap}) {
    final box = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(NeonTheme.s16),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
        boxShadow: NeonTheme.glow(color, blur: 7),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: box,
    );
  }
}
