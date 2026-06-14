import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/neon_theme.dart';
import '../controllers/story_controller.dart';
import 'neon_dialog.dart';
import 'npc_avatar.dart';

/// Overlay cốt truyện (trong cây — route dialog no-op ở full-screen).
/// Thêm `const StoryOverlay()` vào Stack của màn có thể kích hoạt story.
class StoryOverlay extends StatelessWidget {
  const StoryOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final story = StoryController.to;
    return Obx(() {
      story.line.value; // observe để đổi dòng thoại
      final beat = story.current.value;
      if (!story.open.value || beat == null) return const SizedBox.shrink();

      final color = NeonTheme.accentForWorld(beat.world);
      final last = story.line.value >= beat.lineCount - 1;

      return NeonDialog.overlay(
        onBarrier: story.next,
        panel: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -100) {
              story.next();
            } else if (v > 100) {
              story.prev();
            }
          },
          child: NeonDialog.panel(
            title: beat.titleKey.tr,
            color: color,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NpcAvatar(world: beat.world, size: 88),
                const SizedBox(height: 6),
                Text(
                  beat.npcNameKey.tr,
                  style: TextStyle(
                    fontFamily: 'Baloo2',
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    shadows: [Shadow(color: color, blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: NeonTheme.s8),
                Text(
                  beat.lineKey(story.line.value).tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Baloo2',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: NeonTheme.s8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(beat.lineCount, (i) {
                    final on = i == story.line.value;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: on ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: on ? color : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: on ? NeonTheme.glow(color, blur: 6) : null,
                      ),
                    );
                  }),
                ),
              ],
            ),
            actions: [
              if (!last)
                NeonDialogAction(
                    label: 'story_skip'.tr,
                    color: NeonTheme.magenta,
                    onTap: story.skip),
              NeonDialogAction(
                label: last ? 'story_done'.tr : 'story_next'.tr,
                color: NeonTheme.lime,
                onTap: story.next,
              ),
            ],
          ),
        ),
      );
    });
  }
}
