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

/// Cài đặt: ngôn ngữ, âm thanh, reset tiến trình.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Get.find<LocaleService>();
    final audio = AudioManager.maybe;
    final gameCtrl = Get.find<GameController>();
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              NeonAppBar(title: 'settings'.tr, color: NeonTheme.purple),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(NeonTheme.s16),
                  children: [
                    if (audio != null)
                      Obx(
                        () => SwitchListTile(
                          value: !audio.muted.value,
                          onChanged: (_) => audio.toggleMute(),
                          activeThumbColor: NeonTheme.cyan,
                          title: Text(
                            'sound'.tr,
                            style: const TextStyle(color: NeonTheme.ink),
                          ),
                        ),
                      ),
                    Obx(
                      () => SwitchListTile(
                        value: gameCtrl.colorblindMode.value,
                        onChanged: (_) => gameCtrl.toggleColorblindMode(),
                        activeThumbColor: NeonTheme.cyan,
                        title: Text(
                          'colorblind_mode'.tr,
                          style: const TextStyle(color: NeonTheme.ink),
                        ),
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    Text(
                      'language'.tr,
                      style: const TextStyle(
                        color: NeonTheme.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s8),
                    Obx(
                      () => Wrap(
                        spacing: NeonTheme.s8,
                        runSpacing: NeonTheme.s8,
                        children: [
                          for (final l in AppTranslations.supported)
                            ChoiceChip(
                              label: Text(
                                AppTranslations
                                        .languageNames[AppTranslations.codeOf(
                                      l,
                                    )] ??
                                    l.languageCode,
                                style: TextStyle(
                                  color: locale.isCurrent(l)
                                      ? Colors.white
                                      : NeonTheme.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              selected: locale.isCurrent(l),
                              showCheckmark: false,
                              backgroundColor: NeonTheme.card,
                              selectedColor: NeonTheme.magenta,
                              side: BorderSide(
                                color: locale.isCurrent(l)
                                    ? NeonTheme.magenta
                                    : NeonTheme.ink.withValues(alpha: 0.15),
                              ),
                              onSelected: (_) => locale.change(l),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: NeonTheme.s24),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: NeonTheme.orange,
                        side: const BorderSide(color: NeonTheme.orange),
                      ),
                      onPressed: () => NeonDialog.show(
                        context: context,
                        title: '${'reset_progress'.tr}?',
                        color: NeonTheme.orange,
                        message: 'reset_confirm_msg'.tr,
                        actions: [
                          NeonDialogAction(
                            label: 'cancel'.tr,
                            color: NeonTheme.cyan,
                            onTap: () {},
                          ),
                          NeonDialogAction(
                            label: 'confirm'.tr,
                            color: NeonTheme.orange,
                            onTap: () =>
                                Get.find<GameController>().resetProgress(),
                          ),
                        ],
                      ),
                      child: Text('reset_progress'.tr),
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
}
