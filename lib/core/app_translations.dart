import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Minimal seed translations for the base project — 2 locales with key parity.
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
      'bgm_volume': 'Background music volume',
      'sfx_volume': 'Sound effects volume',
      'keep_screen_on': 'Keep Screen On',
      'dark_mode': 'Dark Mode',
      'color_blind_safe': 'Color-blind Safe',
      'ok': 'OK',
      'cancel': 'Cancel',
      'widget_showcase': 'Widget Kit',
      'back_button_label': 'Back',
      'game_demo': 'Flame Demo',
      'cookbook': 'Cookbook',
      'daily_rewards': 'Daily Rewards',
      'shop': 'Shop',
      'save_cloud': 'Save & Cloud',
      'level_progression': 'Level & Energy',
      'season_leaderboard': 'Season & Ranking',
      'monetization': 'Store & Monetization',
      'a11y_level_up': 'Level up! Now level {value}.',
      'a11y_reward_granted': 'Reward received: {value}.',
      'a11y_lives_changed': 'Lives: {value}.',
      'pause_title': 'Paused',
      'pause_resume': 'Resume',
      'pause_restart': 'Restart',
      'pause_quit': 'Quit',
      'tutorial_got_it': 'Got it',
      'tutorial_skip': 'Skip',
      'tutorial_step_indicator': 'Step @current/@total',
      'level_up_banner': 'Level @level!',
      'level_up_skip': 'Skip',
      'game_demo_round_initial':
          'Spend 1 energy, then tap Circle 5 times to win.',
      'game_demo_round_error_energy': 'Not enough energy. Wait for refill.',
      'game_demo_round_active': 'Round active: tap Circle 5 times!',
      'game_demo_round_victory': 'Victory! +40 XP, +30 coins.',
      'game_demo_round_victory_level_up':
          'Victory! +40 XP, +30 coins. LEVEL UP to Lv.@level!',
      'game_demo_circle_label': 'Circle',
      'game_demo_hud_progress': 'gems: @gems | tap: @tap/@target',
      'game_demo_tap_circle_progress': 'Tap Circle: @current / @target',
      'game_demo_start_round': 'Start Round (-1 Energy)',
      'game_demo_score_hud':
          'Score: @score | Lv.@level | XP: @xp/@xpToNext | Coins: @coins',
      'game_demo_achievement_unlocked':
          '🎉 Achievement Unlocked: Circle Tap Master! +10 Gems',
    },
    'vi': {
      'app_name': 'Roy Project Base Game',
      'settings': 'Cài đặt',
      'language': 'Ngôn ngữ',
      'sound': 'Âm thanh',
      'bgm_volume': 'Âm lượng nhạc nền',
      'sfx_volume': 'Âm lượng hiệu ứng',
      'keep_screen_on': 'Giữ màn hình sáng',
      'dark_mode': 'Chế độ tối',
      'color_blind_safe': 'Màu an toàn mù màu',
      'ok': 'Đồng ý',
      'cancel': 'Huỷ',
      'widget_showcase': 'Bộ Widget',
      'back_button_label': 'Quay lại',
      'game_demo': 'Demo Flame',
      'cookbook': 'Cookbook',
      'daily_rewards': 'Thưởng ngày',
      'shop': 'Cửa hàng',
      'save_cloud': 'Lưu trữ & Đám mây',
      'level_progression': 'Cấp độ & Năng lượng',
      'season_leaderboard': 'Mùa giải & Xếp hạng',
      'monetization': 'Cửa hàng & Kiếm tiền',
      'a11y_level_up': 'Lên cấp! Hiện tại cấp {value}.',
      'a11y_reward_granted': 'Nhận thưởng: {value}.',
      'a11y_lives_changed': 'Số mạng: {value}.',
      'pause_title': 'Đã tạm dừng',
      'pause_resume': 'Tiếp tục',
      'pause_restart': 'Chơi lại',
      'pause_quit': 'Thoát',
      'tutorial_got_it': 'Đã hiểu',
      'tutorial_skip': 'Bỏ qua',
      'tutorial_step_indicator': 'Bước @current/@total',
      'level_up_banner': 'Lên cấp @level!',
      'level_up_skip': 'Bỏ qua',
      'game_demo_round_initial':
          'Dùng 1 năng lượng, rồi chạm Vòng tròn 5 lần để thắng.',
      'game_demo_round_error_energy':
          'Không đủ năng lượng. Chờ hồi năng lượng.',
      'game_demo_round_active': 'Vòng chơi đang diễn ra: chạm Vòng tròn 5 lần!',
      'game_demo_round_victory': 'Chiến thắng! +40 XP, +30 xu.',
      'game_demo_round_victory_level_up':
          'Chiến thắng! +40 XP, +30 xu. LÊN CẤP @level!',
      'game_demo_circle_label': 'Vòng tròn',
      'game_demo_hud_progress': 'ngọc: @gems | lượt chạm: @tap/@target',
      'game_demo_tap_circle_progress': 'Chạm Vòng tròn: @current / @target',
      'game_demo_start_round': 'Bắt đầu vòng chơi (-1 Năng lượng)',
      'game_demo_score_hud':
          'Điểm: @score | Cấp @level | XP: @xp/@xpToNext | Xu: @coins',
      'game_demo_achievement_unlocked':
          '🎉 Đã mở khóa thành tựu: Bậc thầy chạm Vòng tròn! +10 Ngọc',
    },
  };
}
