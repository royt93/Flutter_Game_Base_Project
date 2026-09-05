import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_translations.dart';
import '../../core/audio_manager.dart';
import '../../core/locale_service.dart';
import '../../core/neon_theme.dart';
import '../widgets/common/bottom_sheet_panel.dart';
import '../widgets/common/list_tile_row.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bg.dart';

/// Minimal settings screen: locale picker + audio mute toggle. Exercises the
/// 3 kept StorageKeys end to end; extend per-project.
///
/// NeonAppBar is a plain widget (not a PreferredSizeWidget), so it's placed
/// inside the body's Column rather than passed to Scaffold's `appBar:`.
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
              NeonAppBar(title: 'settings'.tr, onBack: Get.back),
              Expanded(
                child: ListView(
                  children: [
                    Obx(
                      () => CommonListTile(
                        title: 'language'.tr,
                        subtitle: locale.current.value.languageCode
                            .toUpperCase(),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: NeonTheme.inkSoft,
                        ),
                        onTap: () => _pickLanguage(context, locale),
                      ),
                    ),
                    // AudioManager may not be registered (e.g.
                    // `app(withAudio: false)`, used by tests) — the
                    // null-check must sit outside Obx, or `?.` short-circuits
                    // and Obx registers no observable, which GetX treats as
                    // "improper use of a GetX".
                    if (audio != null)
                      Obx(
                        () => SwitchListTile(
                          title: Text('sound'.tr),
                          value: !audio.muted.value,
                          onChanged: (_) => audio.toggleMute(),
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
}

/// Opens a candy-styled bottom sheet (common widget kit's
/// [showCommonBottomSheet]/[CommonListTile]) listing every locale in
/// [AppTranslations.supported], instead of a plain [DropdownButton] —
/// dogfoods the kit and matches the rest of the app's visual language.
void _pickLanguage(BuildContext context, LocaleService locale) {
  showCommonBottomSheet(
    context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: NeonTheme.s16),
          child: Text(
            'language'.tr,
            style: TextStyle(
              color: NeonTheme.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        for (final l in AppTranslations.supported) ...[
          CommonListTile(
            title: l.languageCode.toUpperCase(),
            trailing: locale.isCurrent(l)
                ? const Icon(Icons.check_circle, color: NeonTheme.purple)
                : null,
            onTap: () {
              locale.change(l);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: NeonTheme.s8),
        ],
      ],
    ),
  );
}
