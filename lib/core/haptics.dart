import 'package:flutter/services.dart';

import 'storage_service.dart';

/// X2: rung xúc giác — mọi điểm gọi `HapticFeedback.*` trong app phải đi qua
/// đây để tôn trọng cờ `StorageKeys.hapticsEnabled` (tắt trong Settings).
enum HapticLevel { light, medium, heavy }

/// I11: cỡ nhóm vừa nổ → mức rung (thuần, test được).
HapticLevel hapticLevelForGroupSize(int size) {
  if (size >= 8) return HapticLevel.heavy;
  if (size >= 4) return HapticLevel.medium;
  return HapticLevel.light;
}

void fireHaptic(HapticLevel level) {
  if (!StorageService.to.getBool(StorageKeys.hapticsEnabled, def: true)) {
    return;
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
