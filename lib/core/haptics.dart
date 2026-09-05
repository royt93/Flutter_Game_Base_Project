import 'package:flutter/services.dart';

import 'storage_service.dart';

/// Haptic feedback — every call site in the app using `HapticFeedback.*`
/// must go through here to respect the `StorageKeys.hapticsEnabled` flag
/// (disabled from Settings).
enum HapticLevel { light, medium, heavy }

/// Maps a just-popped group's size to a haptic level (pure, testable) — use
/// this once real group/pop matching rules exist.
HapticLevel hapticLevelForGroupSize(int size) {
  if (size >= 8) return HapticLevel.heavy;
  if (size >= 4) return HapticLevel.medium;
  return HapticLevel.light;
}

/// Steps a haptic level down by one tier for soft mode (heavy→medium,
/// medium→light, light→light) by moving back one index in
/// `HapticLevel.values` (declared in order light < medium < heavy) — stays
/// correct automatically if tiers are added/removed later, no need to hand-edit
/// each mapping pair.
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
