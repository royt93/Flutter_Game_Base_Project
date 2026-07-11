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
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Column(
            children: [
              const NeonAppBar(title: 'Settings', color: NeonTheme.purple),
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
                          title: const Text(
                            'Sound',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    const SizedBox(height: NeonTheme.s16),
                    const Text(
                      'Language',
                      style: TextStyle(
                        color: Colors.white70,
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
                              ),
                              selected: locale.isCurrent(l),
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
                        title: 'Reset Progress?',
                        color: NeonTheme.orange,
                        message:
                            'This clears all levels, stars, coins and boosters. This cannot be undone.',
                        actions: [
                          NeonDialogAction(
                            label: 'Cancel',
                            color: NeonTheme.cyan,
                            onTap: () {},
                          ),
                          NeonDialogAction(
                            label: 'Reset',
                            color: NeonTheme.orange,
                            onTap: () =>
                                Get.find<GameController>().resetProgress(),
                          ),
                        ],
                      ),
                      child: const Text('Reset Progress'),
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
