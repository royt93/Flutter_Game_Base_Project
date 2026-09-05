import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_translations.dart';
import '../../core/audio_manager.dart';
import '../../core/locale_service.dart';
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
                      () => ListTile(
                        title: Text('language'.tr),
                        trailing: DropdownButton<Locale>(
                          value: locale.current.value,
                          items: AppTranslations.supported
                              .map(
                                (l) => DropdownMenuItem(
                                  value: l,
                                  child: Text(l.languageCode),
                                ),
                              )
                              .toList(),
                          onChanged: (l) {
                            if (l != null) locale.change(l);
                          },
                        ),
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
