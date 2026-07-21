enum ComboTextStyleKind { neon, boldPop, retro, fire }

class ComboTextStyle {
  const ComboTextStyle({
    required this.kind,
    required this.nameKey,
    required this.unlockThreshold,
  });

  final ComboTextStyleKind kind;
  final String nameKey;
  final int unlockThreshold;
}

/// I54: ngưỡng mở khoá tái dùng 3 trong 5 tier của `kAchievements` cho
/// `AchievementMetric.maxComboEver` (3/6/10/15/25) — giữ 6/15/25, bỏ tier 3 và
/// 10 (giữ khoảng cách đều hơn giữa các mốc). Style đầu (`neon`) dùng ngưỡng
/// 0 (không phải tier thật) để luôn mở khoá mặc định, giống `spark` của I52.
const List<ComboTextStyle> kComboTextStyles = [
  ComboTextStyle(
    kind: ComboTextStyleKind.neon,
    nameKey: 'combo_text_style_neon',
    unlockThreshold: 0,
  ),
  ComboTextStyle(
    kind: ComboTextStyleKind.boldPop,
    nameKey: 'combo_text_style_bold_pop',
    unlockThreshold: 6,
  ),
  ComboTextStyle(
    kind: ComboTextStyleKind.retro,
    nameKey: 'combo_text_style_retro',
    unlockThreshold: 15,
  ),
  ComboTextStyle(
    kind: ComboTextStyleKind.fire,
    nameKey: 'combo_text_style_fire',
    unlockThreshold: 25,
  ),
];

bool isComboTextStyleUnlocked(ComboTextStyle style, int maxComboEver) =>
    maxComboEver >= style.unlockThreshold;
