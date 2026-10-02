import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/app_translations.dart';

/// Placeholders in a template string — `{name}` (the convention
/// `GameAccessibilityAnnouncer`/FEAT-99 uses for its own manual
/// interpolation) and `@name` (GetX's native `.trParams`/`.trArgs`
/// convention, used by the BUG-94 sweep keys). Normalized to a bare name
/// set so a key using either style still gets checked for en/vi parity.
Set<String> _placeholdersOf(String template) => {
  ...RegExp(r'\{([^{}]+)\}').allMatches(template).map((m) => m.group(1)!),
  ...RegExp(r'@(\w+)').allMatches(template).map((m) => m.group(1)!),
};

void main() {
  group('AppTranslations', () {
    test('en và vi có cùng bộ key (key parity)', () {
      final keys = AppTranslations().keys;
      expect(keys['en']!.keys.toSet(), keys['vi']!.keys.toSet());
    });

    test('back_button_label tồn tại ở cả en và vi', () {
      final keys = AppTranslations().keys;
      expect(keys['en'], contains('back_button_label'));
      expect(keys['vi'], contains('back_button_label'));
    });

    test('BUG-94: mọi key có đúng cùng bộ placeholder {name} ở cả en và vi '
        '(không lệch tên/số lượng placeholder giữa 2 bản dịch)', () {
      final keys = AppTranslations().keys;
      for (final key in keys['en']!.keys) {
        final enPlaceholders = _placeholdersOf(keys['en']![key]!);
        final viPlaceholders = _placeholdersOf(keys['vi']![key]!);
        expect(
          viPlaceholders,
          enPlaceholders,
          reason:
              'key "$key": placeholder vi (${viPlaceholders.join(", ")}) '
              'phải khớp placeholder en (${enPlaceholders.join(", ")})',
        );
      }
    });

    test('BUG-94: đủ key cho pause/tutorial/spotlight/level-up/game-demo '
        'sweep ở cả en và vi', () {
      final keys = AppTranslations().keys;
      const requiredKeys = [
        'pause_title',
        'pause_resume',
        'pause_restart',
        'pause_quit',
        'tutorial_got_it',
        'tutorial_skip',
        'tutorial_step_indicator',
        'level_up_banner',
        'level_up_skip',
        'game_demo_round_initial',
        'game_demo_round_error_energy',
        'game_demo_round_active',
        'game_demo_round_victory',
        'game_demo_round_victory_level_up',
        'game_demo_circle_label',
        'game_demo_hud_progress',
        'game_demo_tap_circle_progress',
        'game_demo_start_round',
        'game_demo_score_hud',
        'game_demo_achievement_unlocked',
      ];
      for (final key in requiredKeys) {
        expect(keys['en'], contains(key), reason: 'thiếu key en "$key"');
        expect(keys['vi'], contains(key), reason: 'thiếu key vi "$key"');
      }
    });
  });
}
