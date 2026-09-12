import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/audio_manager.dart';
import '../../../core/neon_theme.dart';
import '../pressable_scale.dart';

/// Small floating round button toggling [AudioManager]'s mute state —
/// speaker icon flips on/off, tap calls `toggleMute()`. Uses
/// [AudioManager.maybe] (the null-safe accessor): renders nothing if audio
/// hasn't been registered instead of throwing, so a gameplay screen can drop
/// this in unconditionally.
class SoundToggleFab extends StatelessWidget {
  const SoundToggleFab({super.key, this.color, this.size = 52});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final audio = AudioManager.maybe;
    // The null-check must sit outside Obx (see settings_screen.dart) — `?.`
    // short-circuiting inside Obx registers no observable, which GetX treats
    // as "improper use of a GetX".
    if (audio == null) return const SizedBox.shrink();

    final c = color ?? NeonTheme.cyan;
    return Obx(() {
      final muted = audio.muted.value;
      return Semantics(
        button: true,
        label: muted ? 'Unmute' : 'Mute',
        child: PressableScale(
          onTap: audio.toggleMute,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(c, Colors.white, 0.18)!, c],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Color.lerp(c, Colors.black, 0.22)!,
                width: 3,
              ),
              boxShadow: NeonTheme.drop(y: 4, blur: 8),
            ),
            child: AnimatedSwitcher(
              duration: NeonTheme.reducedMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                key: ValueKey(muted),
                color: Colors.white,
                size: size * 0.5,
              ),
            ),
          ),
        ),
      );
    });
  }
}
