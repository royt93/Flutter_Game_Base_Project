import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:roy_casual_kit/roy_casual_kit.dart';

/// Minimal settings screen: locale picker + audio mute toggle. Exercises the
/// 3 kept StorageKeys end to end; extend per-project.
///
/// NeonAppBar is a plain widget (not a PreferredSizeWidget), so it's placed
/// inside the body's Column rather than passed to Scaffold's `appBar:`.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // FEAT-79: debug-only QA toggle — never shown outside kDebugMode, so it
  // can never leak into a release build's UI (see
  // PseudoLocaleTranslations's own doc comment for the same discipline at
  // the translations-data level).
  bool _pseudoLocaleEnabled = false;
  Locale? _localeBeforePseudo;

  // FEAT-94: reuses the app's real StorageService singleton — an export/
  // erasure request operates on the SAME storage every other screen reads/
  // writes, not a throwaway instance. Null only if StorageService was
  // never registered (e.g. a test that boots without it), matching this
  // screen's existing `AudioManager.maybe`/`WakeLockService.maybe` posture.
  late final PlayerDataRightsService? _dataRights =
      StorageService.maybe != null
      ? PlayerDataRightsService(storage: StorageService.to)
      : null;

  Future<void> _requestExport() async {
    final rights = _dataRights;
    if (rights == null) return;
    final receipt = rights.requestExport();
    if (!mounted) return;
    ToastBanner.show(
      context,
      message:
          'Đã xuất ${receipt.data.length} key (schema v${receipt.schemaVersion}) '
          'lúc ${DateTime.fromMillisecondsSinceEpoch(receipt.exportedAtMs)}',
    );
  }

  Future<void> _requestErasure() async {
    final rights = _dataRights;
    if (rights == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Xoá toàn bộ dữ liệu?',
      message: 'Hành động này không thể hoàn tác — mọi dữ liệu đã lưu sẽ mất.',
      confirmLabel: 'Xoá',
      color: NeonTheme.red,
    );
    if (!confirmed || !mounted) return;
    final receipt = await rights.requestErasure();
    if (!mounted) return;
    ToastBanner.show(
      context,
      message:
          'Đã xoá ${receipt.erasedKeyCount} key lúc '
          '${DateTime.fromMillisecondsSinceEpoch(receipt.completedAtMs)}',
    );
  }

  void _togglePseudoLocale(bool enabled, LocaleService locale) {
    if (enabled) {
      _localeBeforePseudo = locale.current.value;
      Get.addTranslations(
        PseudoLocaleTranslations(baseKeys: AppTranslations().keys['en']!).keys,
      );
      Get.updateLocale(PseudoLocaleTranslations.defaultLocale);
    } else {
      Get.updateLocale(_localeBeforePseudo ?? AppTranslations.fallback);
    }
    setState(() => _pseudoLocaleEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Get.find<LocaleService>();
    final audio = AudioManager.maybe;
    final wakeLock = WakeLockService.maybe;
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
                        () => CommonListTile(
                          title: 'sound'.tr,
                          trailing: CandyToggleSwitch(
                            value: !audio.muted.value,
                            onChanged: (_) => audio.toggleMute(),
                          ),
                        ),
                      ),
                    // Same null-outside-Obx reasoning as AudioManager above —
                    // WakeLockService may not be registered (e.g. a test that
                    // boots without the wakeLock module).
                    if (wakeLock != null)
                      Obx(
                        () => CommonListTile(
                          title: 'keep_screen_on'.tr,
                          trailing: CandyToggleSwitch(
                            value: wakeLock.enabled.value,
                            onChanged: (v) => wakeLock.setEnabled(v),
                          ),
                        ),
                      ),
                    CommonListTile(
                      title: 'dark_mode'.tr,
                      trailing: CandyToggleSwitch(
                        value: NeonTheme.dark,
                        onChanged: (v) {
                          StorageService.maybe?.setBool(
                            StorageKeys.themeDark,
                            v,
                          );
                          // NeonTheme.dark is a plain static, not observable —
                          // setState re-renders this screen with the new
                          // palette immediately; other already-mounted screens
                          // pick it up next time they rebuild/navigate.
                          setState(() => NeonTheme.dark = v);
                        },
                      ),
                    ),
                    CommonListTile(
                      title: 'color_blind_safe'.tr,
                      trailing: CandyToggleSwitch(
                        value: NeonTheme.colorBlindSafe,
                        onChanged: (v) {
                          StorageService.maybe?.setBool(
                            StorageKeys.colorBlindSafe,
                            v,
                          );
                          setState(() => NeonTheme.colorBlindSafe = v);
                        },
                      ),
                    ),
                    // FEAT-79: QA-only, never shown in a release build —
                    // catches hardcoded strings (stay plain ASCII while
                    // everything real turns accented) and overflow
                    // (pseudo-localized text runs ~40% longer) before a
                    // real translator ever touches a key.
                    if (kDebugMode)
                      CommonListTile(
                        title: 'Pseudo-locale (QA)',
                        subtitle: 'Debug only — bắt hardcode/overflow',
                        trailing: CandyToggleSwitch(
                          value: _pseudoLocaleEnabled,
                          onChanged: (v) => _togglePseudoLocale(v, locale),
                        ),
                      ),
                    // FEAT-94: GDPR/CCPA-style "player requested their
                    // data" workflow — both tiles are no-ops (never call
                    // PlayerDataRightsService) if StorageService was never
                    // registered.
                    if (_dataRights != null) ...[
                      CommonListTile(
                        key: const Key('settingsRequestExport'),
                        title: 'Yêu cầu xuất dữ liệu',
                        subtitle: 'Tải toàn bộ dữ liệu đã lưu (GDPR/CCPA)',
                        trailing: Icon(
                          Icons.download_outlined,
                          color: NeonTheme.inkSoft,
                        ),
                        onTap: _requestExport,
                      ),
                      CommonListTile(
                        key: const Key('settingsRequestErasure'),
                        title: 'Yêu cầu xoá dữ liệu',
                        subtitle: 'Xoá vĩnh viễn toàn bộ dữ liệu đã lưu',
                        trailing: Icon(
                          Icons.delete_outline,
                          color: NeonTheme.red,
                        ),
                        onTap: _requestErasure,
                      ),
                    ],
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
                ? Icon(Icons.check_circle, color: NeonTheme.purple)
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
