import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Hệ thống đa ngôn ngữ (GetX i18n).
///
/// Mở rộng thêm ngôn ngữ trong tương lai chỉ cần:
///   1. Thêm map `_xx` bên dưới (đủ key như `_en`).
///   2. Thêm `'xx_YY': _xx` vào [keys].
///   3. Thêm `Locale('xx','YY')` vào [supported] + tên vào [languageNames].
/// Test `app_translations_test.dart` sẽ tự kiểm mọi ngôn ngữ có ĐỦ key.
class AppTranslations extends Translations {
  static const Locale fallback = Locale('en', 'US');

  /// Danh sách ngôn ngữ đang hỗ trợ (default đầu tiên = English).
  static const List<Locale> supported = [
    Locale('en', 'US'),
    Locale('vi', 'VN'),
  ];

  /// Tên hiển thị của từng ngôn ngữ (theo chính ngôn ngữ đó — native name).
  static const Map<String, String> languageNames = {
    'en_US': 'English',
    'vi_VN': 'Tiếng Việt',
  };

  static String codeOf(Locale l) => '${l.languageCode}_${l.countryCode}';

  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': _en,
        'vi_VN': _vi,
      };

  static const Map<String, String> _en = {
    'play_now': 'PLAY NOW',
    'quick_level1': 'LEVEL 1',
    'levels_tagline': '@count levels · neon style',
    'select_level': 'SELECT LEVEL',
    'victory': 'VICTORY!',
    'retry': 'TRY AGAIN',
    'score_value': 'Score: @value',
    'target_value': 'Target: @value',
    'btn_again': 'AGAIN',
    'btn_next': 'NEXT',
    'btn_home': 'HOME',
    'stage_n': 'STAGE @n',
    'hud_score': 'SCORE',
    'hud_target': 'TARGET',
    'hud_moves': 'MOVES',
    'settings': 'SETTINGS',
    'sound': 'Sound',
    'language': 'Language',
    'reset_progress': 'Reset progress',
    'reset_done': 'Progress has been reset',
    'cancel': 'CANCEL',
    'confirm': 'CONFIRM',
    'reset_confirm_msg': 'Erase all progress and high scores?',
    'on': 'On',
    'off': 'Off',
    'shuffle': 'SHUFFLE',
  };

  static const Map<String, String> _vi = {
    'play_now': 'CHƠI NGAY',
    'quick_level1': 'MÀN 1',
    'levels_tagline': '@count màn · phong cách neon',
    'select_level': 'CHỌN MÀN',
    'victory': 'CHIẾN THẮNG!',
    'retry': 'THỬ LẠI',
    'score_value': 'Điểm: @value',
    'target_value': 'Mục tiêu: @value',
    'btn_again': 'CHƠI LẠI',
    'btn_next': 'TIẾP',
    'btn_home': 'TRANG CHỦ',
    'stage_n': 'MÀN @n',
    'hud_score': 'ĐIỂM',
    'hud_target': 'MỤC TIÊU',
    'hud_moves': 'LƯỢT',
    'settings': 'CÀI ĐẶT',
    'sound': 'Âm thanh',
    'language': 'Ngôn ngữ',
    'reset_progress': 'Xoá tiến độ',
    'reset_done': 'Đã xoá toàn bộ tiến độ',
    'cancel': 'HUỶ',
    'confirm': 'ĐỒNG Ý',
    'reset_confirm_msg': 'Xoá toàn bộ tiến độ và điểm cao?',
    'on': 'Bật',
    'off': 'Tắt',
    'shuffle': 'XÁO TRỘN',
  };
}
