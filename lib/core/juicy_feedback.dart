import 'dart:async';

import 'audio_manager.dart';
import 'haptics.dart';
import 'storage_service.dart';

enum JuicyPreset { tap, pop, success, warning, chestOpen, coinTick }

HapticLevel hapticLevelForJuicyPreset(JuicyPreset preset) => switch (preset) {
  JuicyPreset.tap => HapticLevel.light,
  JuicyPreset.pop => HapticLevel.light,
  JuicyPreset.success => HapticLevel.medium,
  JuicyPreset.warning => HapticLevel.medium,
  JuicyPreset.chestOpen => HapticLevel.heavy,
  JuicyPreset.coinTick => HapticLevel.light,
};

/// Starts a consumer-owned SFX and its matching haptic as one feedback event.
/// Audio stays optional until the consuming app registers [AudioManager],
/// while haptics continue to honor the player's stored haptic preferences.
class JuicyFeedback {
  JuicyFeedback._();

  static void trigger(JuicyPreset preset, {required String sfxAsset}) {
    if (sfxAsset.isEmpty) {
      throw ArgumentError.value(sfxAsset, 'sfxAsset', 'must not be empty');
    }
    final audio = AudioManager.maybe;
    if (audio != null && !audio.muted.value) {
      unawaited(audio.playSfx(sfxAsset));
    }
    if (StorageService.maybe != null) {
      fireHaptic(hapticLevelForJuicyPreset(preset));
    }
  }
}
