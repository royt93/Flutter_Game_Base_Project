import 'package:flutter/services.dart';

import 'storage_service.dart';

/// X2: rung xúc giác — mọi điểm gọi `HapticFeedback.*` trong app phải đi qua
/// đây để tôn trọng cờ `StorageKeys.hapticsEnabled` (tắt trong Settings).
enum HapticLevel { light, medium, heavy }

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
