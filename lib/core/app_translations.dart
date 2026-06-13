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
    'hud_goal': 'GOAL',
    'quit_title': 'QUIT LEVEL?',
    'quit_msg': 'Your progress in this level will be lost.',
    'guide': 'HOW TO PLAY',
    'guide_howto_title': 'Match 3+',
    'guide_howto_body':
        'Swipe or tap to swap two adjacent gems. Line up 3 or more of the same shape to clear them and score.',
    'guide_special_title': 'Special Gems',
    'guide_striped': 'Striped — match 4',
    'guide_striped_desc': 'Clears a whole row or column.',
    'guide_bomb': 'Bomb — match T/L',
    'guide_bomb_desc': 'Blasts the surrounding 3×3 area.',
    'guide_rainbow': 'Rainbow — match 5',
    'guide_rainbow_desc': 'Removes every gem of one color.',
    'guide_combo_title': 'Combos & Wombo Combo',
    'guide_combo_body':
        'Chain clears (cascades) raise your combo and score multiplier. Swap two special gems together for a huge combined blast — hit a long chain for a WOMBO COMBO!',
    'guide_modes_title': 'Game Modes',
    'guide_mode_score': 'Score: reach the target score within the moves.',
    'guide_mode_collect': 'Collect: gather enough gems of a given color.',
    'guide_mode_jelly': 'Clear Jelly: pop every jelly tile on the board.',
    'guide_stuck': 'Stuck? Idle gems will blink a hint; no moves left auto-shuffles the board.',
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
    'hud_goal': 'MỤC TIÊU',
    'quit_title': 'THOÁT MÀN?',
    'quit_msg': 'Tiến độ màn này sẽ bị mất.',
    'guide': 'HƯỚNG DẪN',
    'guide_howto_title': 'Ghép 3+',
    'guide_howto_body':
        'Vuốt hoặc chạm để đổi 2 gem kề nhau. Xếp 3 gem cùng hình trở lên để phá và ghi điểm.',
    'guide_special_title': 'Gem Đặc Biệt',
    'guide_striped': 'Striped — ghép 4',
    'guide_striped_desc': 'Phá nguyên 1 hàng hoặc 1 cột.',
    'guide_bomb': 'Bomb — ghép hình T/L',
    'guide_bomb_desc': 'Nổ tung vùng 3×3 xung quanh.',
    'guide_rainbow': 'Rainbow — ghép 5',
    'guide_rainbow_desc': 'Xoá toàn bộ gem của 1 màu.',
    'guide_combo_title': 'Combo & Wombo Combo',
    'guide_combo_body':
        'Chuỗi phá liên tiếp (cascade) tăng combo và hệ số điểm. Đổi 2 gem đặc biệt cạnh nhau để tạo vụ nổ kết hợp cực lớn — chuỗi thật dài sẽ thành WOMBO COMBO!',
    'guide_modes_title': 'Các Chế Độ Chơi',
    'guide_mode_score': 'Điểm: đạt điểm mục tiêu trong số lượt cho phép.',
    'guide_mode_collect': 'Thu thập: gom đủ số gem của màu chỉ định.',
    'guide_mode_jelly': 'Phá Jelly: phá hết các ô jelly trên bàn.',
    'guide_stuck': 'Bí nước? Gem sẽ nhấp nháy gợi ý; hết nước đi bàn tự xáo lại.',
  };
}
