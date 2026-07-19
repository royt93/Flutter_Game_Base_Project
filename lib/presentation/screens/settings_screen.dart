import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_translations.dart';
import '../../core/audio_manager.dart';
import '../../core/locale_service.dart';
import '../../core/neon_theme.dart';
import '../../core/share_helper.dart';
import '../../core/storage_service.dart';
import '../controllers/game_controller.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_dialog.dart';
import 'puzzle_lab_screen.dart';

// ponytail: Switch M3 (useMaterial3: true) có track cố định 52x32dp nhưng
// vẫn giữ 1 vùng vô hình rộng hơn ở cạnh phải track (không đổi theo
// shrinkWrap) khiến margin phải > trái dù contentPadding 2 bên bằng nhau.
// Bù trừ cứng theo dp (không phụ thuộc device density) — nếu Flutter SDK
// đổi kích thước Switch M3 sau này, chỉnh lại giá trị này.
const double _switchTrailingCompensation = 11;

/// Cài đặt: ngôn ngữ, âm thanh, reset tiến trình.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _hapticsEnabled = StorageService.to.getBool(
    StorageKeys.hapticsEnabled,
    def: true,
  );
  late bool _reduceMotion = StorageService.to.getBool(StorageKeys.reduceMotion);
  late bool _darkTheme = NeonTheme.dark;
  late bool _recordReplay = StorageService.to.getBool(StorageKeys.recordReplay);

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
                          activeThumbColor: Colors.white,
                          activeTrackColor: NeonTheme.cyan,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          contentPadding: const EdgeInsets.only(
                            left: NeonTheme.s16,
                            right: NeonTheme.s16 - _switchTrailingCompensation,
                          ),
                          title: Text(
                            'sound'.tr,
                            style: TextStyle(color: NeonTheme.ink),
                          ),
                        ),
                      ),
                    if (audio != null)
                      Obx(
                        () => ListTile(
                          title: Text(
                            'bgm_volume'.tr,
                            style: TextStyle(color: NeonTheme.ink),
                          ),
                          subtitle: Slider(
                            value: audio.bgmVolume.value,
                            activeColor: NeonTheme.cyan,
                            onChanged: audio.setBgmVolume,
                          ),
                        ),
                      ),
                    if (audio != null)
                      Obx(
                        () => ListTile(
                          title: Text(
                            'sfx_volume'.tr,
                            style: TextStyle(color: NeonTheme.ink),
                          ),
                          subtitle: Slider(
                            value: audio.sfxVolume.value,
                            activeColor: NeonTheme.cyan,
                            onChanged: audio.setSfxVolume,
                          ),
                        ),
                      ),
                    SwitchListTile(
                      value: _hapticsEnabled,
                      onChanged: (v) {
                        setState(() => _hapticsEnabled = v);
                        StorageService.to.setBool(
                          StorageKeys.hapticsEnabled,
                          v,
                        );
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: NeonTheme.cyan,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      contentPadding: const EdgeInsets.only(
                        left: NeonTheme.s16,
                        right: NeonTheme.s16 - _switchTrailingCompensation,
                      ),
                      title: Text(
                        'haptics'.tr,
                        style: TextStyle(color: NeonTheme.ink),
                      ),
                    ),
                    SwitchListTile(
                      value: _reduceMotion,
                      onChanged: (v) {
                        setState(() => _reduceMotion = v);
                        StorageService.to.setBool(StorageKeys.reduceMotion, v);
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: NeonTheme.cyan,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      contentPadding: const EdgeInsets.only(
                        left: NeonTheme.s16,
                        right: NeonTheme.s16 - _switchTrailingCompensation,
                      ),
                      title: Text(
                        'reduce_motion'.tr,
                        style: TextStyle(color: NeonTheme.ink),
                      ),
                    ),
                    SwitchListTile(
                      value: _recordReplay,
                      onChanged: (v) {
                        setState(() => _recordReplay = v);
                        StorageService.to.setBool(StorageKeys.recordReplay, v);
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: NeonTheme.cyan,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      contentPadding: const EdgeInsets.only(
                        left: NeonTheme.s16,
                        right: NeonTheme.s16 - _switchTrailingCompensation,
                      ),
                      title: Text(
                        'record_replay'.tr,
                        style: TextStyle(color: NeonTheme.ink),
                      ),
                    ),
                    Obx(
                      () => SwitchListTile(
                        value: gameCtrl.colorblindMode.value,
                        onChanged: (_) => gameCtrl.toggleColorblindMode(),
                        activeThumbColor: Colors.white,
                        activeTrackColor: NeonTheme.cyan,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        contentPadding: const EdgeInsets.only(
                          left: NeonTheme.s16,
                          right: NeonTheme.s16 - _switchTrailingCompensation,
                        ),
                        title: Text(
                          'colorblind_mode'.tr,
                          style: TextStyle(color: NeonTheme.ink),
                        ),
                      ),
                    ),
                    SwitchListTile(
                      value: _darkTheme,
                      onChanged: (v) {
                        setState(() => _darkTheme = v);
                        NeonTheme.dark = v;
                        StorageService.to.setBool(StorageKeys.themeDark, v);
                        Get.forceAppUpdate();
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: NeonTheme.cyan,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      contentPadding: const EdgeInsets.only(
                        left: NeonTheme.s16,
                        right: NeonTheme.s16 - _switchTrailingCompensation,
                      ),
                      title: Text(
                        'dark_theme'.tr,
                        style: TextStyle(color: NeonTheme.ink),
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.share_rounded, color: NeonTheme.cyan),
                      title: Text(
                        'invite_friend'.tr,
                        style: TextStyle(color: NeonTheme.ink),
                      ),
                      onTap: () => shareText(
                        // X6: text-only, tái dùng shareText đã dựng ở F15.
                        // Placeholder link store — thay khi có link thật.
                        'Chơi Pop Star Blast cùng mình! '
                        'https://play.google.com/store/apps/details?id=com.galaxyjoy.pop_star_blast',
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.dashboard_customize_rounded,
                        color: NeonTheme.lime,
                      ),
                      title: Text(
                        'puzzle_lab_title'.tr,
                        style: TextStyle(color: NeonTheme.ink),
                      ),
                      onTap: () => Get.to(() => const PuzzleLabScreen()),
                    ),
                    const SizedBox(height: NeonTheme.s16),
                    Text(
                      'language'.tr,
                      style: TextStyle(
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
