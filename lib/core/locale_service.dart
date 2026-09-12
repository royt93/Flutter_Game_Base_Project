import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'app_translations.dart';
import 'storage_service.dart';

/// Manages the current language + persists the user's choice.
class LocaleService extends GetxService {
  final StorageService _store;
  final Rx<Locale> current;

  LocaleService(this._store) : current = _loadInitial(_store).obs;

  /// Safe to call from a call site that may run before/without this
  /// service registered (e.g. widget tests), matching every other service
  /// in this codebase (`AudioManager.maybe`, `CrashReporter.maybe`, ...).
  static LocaleService? get maybe =>
      Get.isRegistered<LocaleService>() ? Get.find<LocaleService>() : null;

  static Locale _loadInitial(StorageService store) {
    final saved = store.getString(StorageKeys.localeCode);
    if (saved != null) {
      for (final l in AppTranslations.supported) {
        if (AppTranslations.codeOf(l) == saved) return l;
      }
    }
    // chưa chọn → theo máy nếu hỗ trợ, không thì English (default)
    final device = Get.deviceLocale;
    if (device != null) {
      for (final l in AppTranslations.supported) {
        if (l.languageCode == device.languageCode) return l;
      }
    }
    return AppTranslations.fallback;
  }

  /// Throws [ArgumentError] (BUG-26) for a [locale] not in
  /// [AppTranslations.supported] — accepting it anyway would run the
  /// CURRENT session untranslated (fallback text everywhere), then have
  /// [_loadInitial] reject that same persisted code on the next launch and
  /// silently revert, an inconsistent before/after-restart experience.
  ///
  /// Matches by `languageCode` only (same as [_loadInitial]'s device-locale
  /// matching) — a country-code variant of an already-supported language
  /// (e.g. `en_GB` when only `en` is declared) is accepted and normalized
  /// to the exact [AppTranslations.supported] entry, not rejected.
  Future<void> change(Locale locale) async {
    Locale? supported;
    for (final l in AppTranslations.supported) {
      if (l.languageCode == locale.languageCode) {
        supported = l;
        break;
      }
    }
    if (supported == null) {
      throw ArgumentError.value(
        locale,
        'locale',
        'not in AppTranslations.supported',
      );
    }

    current.value = supported;
    Get.updateLocale(supported);
    await _store.setString(
      StorageKeys.localeCode,
      AppTranslations.codeOf(supported),
    );
  }

  bool isCurrent(Locale l) =>
      AppTranslations.codeOf(l) == AppTranslations.codeOf(current.value);
}
