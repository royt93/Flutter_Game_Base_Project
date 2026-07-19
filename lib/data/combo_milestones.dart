/// I39: các mốc combo cố định để phát hiệu ứng "COMBO x{N}!" nổi bật.
const List<int> kComboMilestones = [5, 10, 15, 20];

bool isComboMilestone(int comboCount) => kComboMilestones.contains(comboCount);
