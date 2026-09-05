import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'app_translations.dart';
import 'storage_service.dart';

/// Manages the current language + persists the user's choice.
class LocaleService extends GetxService {
  final StorageService _store;
  final Rx<Locale> current;

  LocaleService(this._store) : current = _loadInitial(_store).obs;

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

  Future<void> change(Locale locale) async {
    current.value = locale;
    Get.updateLocale(locale);
    await _store.setString(
      StorageKeys.localeCode,
      AppTranslations.codeOf(locale),
    );
  }

  bool isCurrent(Locale l) =>
      AppTranslations.codeOf(l) == AppTranslations.codeOf(current.value);
}
