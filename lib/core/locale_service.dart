import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_translations.dart';

/// Quản lý ngôn ngữ hiện tại + lưu lựa chọn của người dùng.
class LocaleService extends GetxService {
  static const _key = 'locale_code';
  final SharedPreferences _prefs;
  final Rx<Locale> current;

  LocaleService(this._prefs) : current = _loadInitial(_prefs).obs;

  static Locale _loadInitial(SharedPreferences prefs) {
    final saved = prefs.getString(_key);
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
    await _prefs.setString(_key, AppTranslations.codeOf(locale));
  }

  bool isCurrent(Locale l) =>
      AppTranslations.codeOf(l) == AppTranslations.codeOf(current.value);
}
