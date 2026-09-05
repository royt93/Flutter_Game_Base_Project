import 'package:flutter/services.dart';

import 'storage_service.dart';

/// Rung xúc giác — mọi điểm gọi `HapticFeedback.*` trong app phải đi qua
/// đây để tôn trọng cờ `StorageKeys.hapticsEnabled` (tắt trong Settings).
enum HapticLevel { light, medium, heavy }

/// Cỡ nhóm vừa nổ → mức rung (thuần, test được) — dùng khi có luật ghép
/// nhóm/pop thật.
HapticLevel hapticLevelForGroupSize(int size) {
  if (size >= 8) return HapticLevel.heavy;
  if (size >= 4) return HapticLevel.medium;
  return HapticLevel.light;
}

/// Giảm 1 mức rung cho soft mode (heavy→medium, medium→light, light→light)
/// bằng cách lùi 1 chỉ số trong `HapticLevel.values` (khai theo đúng thứ tự
/// light < medium < heavy) — tự đúng nếu sau này thêm/bớt tier, không cần
/// sửa tay từng cặp ánh xạ.
HapticLevel _softModeDowngrade(HapticLevel level) =>
    HapticLevel.values[(level.index - 1).clamp(
      0,
      HapticLevel.values.length - 1,
    )];

void fireHaptic(HapticLevel level) {
  if (!StorageService.to.getBool(StorageKeys.hapticsEnabled, def: true)) {
    return;
  }
  if (StorageService.to.getBool(StorageKeys.hapticSoftMode, def: false)) {
    level = _softModeDowngrade(level);
  }
  switch (level) {
    case HapticLevel.light:
      HapticFeedback.lightImpact();
    case HapticLevel.medium:
      HapticFeedback.mediumImpact();
    case HapticLevel.heavy:
      HapticFeedback.heavyImpact();
  }
}
