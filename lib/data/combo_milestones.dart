import '../core/haptics.dart';

/// I39: các mốc combo cố định để phát hiệu ứng "COMBO x{N}!" nổi bật.
const List<int> kComboMilestones = [5, 10, 15, 20];

bool isComboMilestone(int comboCount) => kComboMilestones.contains(comboCount);

/// I39: mốc càng cao rung càng mạnh — mốc 5 nhẹ, mốc 10 vừa, mốc 15+ mạnh.
HapticLevel hapticForComboMilestone(int comboCount) {
  if (comboCount >= 15) return HapticLevel.heavy;
  if (comboCount >= 10) return HapticLevel.medium;
  return HapticLevel.light;
}
