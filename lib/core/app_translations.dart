import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Minimal seed translations for the base project — 2 locales, 11 keys.
/// Copy this file's pattern (one `Map<String,String>` per locale code) when
/// a new game needs more languages or more keys.
class AppTranslations extends Translations {
  static const supported = [Locale('en'), Locale('vi')];
  static const fallback = Locale('en');

  /// Kept because lib/core/locale_service.dart (out of this task's scope)
  /// calls it directly to match a persisted locale code back to a [Locale].
  static String codeOf(Locale l) => l.languageCode;

  @override
  Map<String, Map<String, String>> get keys => {
    'en': {
      'app_name': 'Roy Project Base Game',
      'settings': 'Settings',
      'language': 'Language',
      'sound': 'Sound',
      'keep_screen_on': 'Keep Screen On',
      'dark_mode': 'Dark Mode',
      'color_blind_safe': 'Color-blind Safe',
      'ok': 'OK',
      'cancel': 'Cancel',
      'widget_showcase': 'Widget Kit',
      'back_button_label': 'Back',
      'game_demo': 'Flame Demo',
      'cookbook': 'Cookbook',
    },
    'vi': {
      'app_name': 'Roy Project Base Game',
      'settings': 'Cài đặt',
      'language': 'Ngôn ngữ',
      'sound': 'Âm thanh',
      'keep_screen_on': 'Giữ màn hình sáng',
      'dark_mode': 'Chế độ tối',
      'color_blind_safe': 'Màu an toàn mù màu',
      'ok': 'Đồng ý',
      'cancel': 'Huỷ',
      'widget_showcase': 'Bộ Widget',
      'back_button_label': 'Quay lại',
      'game_demo': 'Demo Flame',
      'cookbook': 'Cookbook',
    },
  };
}
