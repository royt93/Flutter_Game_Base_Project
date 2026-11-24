import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/card_flip_3d.dart';
import 'package:roy_casual_kit/presentation/widgets/common/coin_fly_overlay.dart';
import 'package:roy_casual_kit/presentation/widgets/common/floating_combo_text.dart';
import 'package:roy_casual_kit/presentation/widgets/common/floating_emoji_burst.dart';
import 'package:roy_casual_kit/presentation/widgets/common/golden_shimmer_text.dart';
import 'package:roy_casual_kit/presentation/widgets/common/item_fly_overlay.dart';
import 'package:roy_casual_kit/presentation/widgets/common/pooled_particle_burst.dart';
import 'package:roy_casual_kit/presentation/widgets/common/radial_action_menu.dart';
import 'package:roy_casual_kit/presentation/widgets/common/screen_shake.dart';
import 'package:roy_casual_kit/presentation/widgets/common/shimmer_placeholder.dart';
import 'package:roy_casual_kit/presentation/widgets/common/squash_stretch.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

/// ENH-123 (batch F): motion widgets. A golden of motion is only meaningful at
/// a FIXED instant, so each test pumps an exact number of milliseconds and the
/// random ones take a seed. Anything that still cannot be made deterministic
/// is left out and listed below with the reason.
///
/// Not covered, on purpose:
/// - `ConfettiOverlay`: its `initState` calls `generateConfettiParticles`
///   without a seed (`Random()`), so two runs paint different confetti. It
///   has no seed parameter; making it deterministic needs a public API change.
///   Its particle generator is a pure function already tested with a seeded
///   `Random` (`confetti_overlay_test.dart`).
/// - `SceneTransitionOverlay`: needs a `SceneTransitionController.run` future
///   in flight; the phases are behavior-tested, and a golden of one frame of a
///   wipe adds little (the batch B `LoadingOverlay` golden covers the cover).
void main() {
  final previous = installGoldenTolerance('batch_f_motion_widgets_golden_test.dart');
  tearDownAll(() => goldenFileComparator = previous);

  // Fixed instants the motion widgets are captured at.
  const mid = Duration(milliseconds: 300);

  Future<void> golden(
    WidgetTester tester,
    String name,
    Widget Function() build, {
    Size size = const Size(390, 600),
    Future<void> Function(WidgetTester)? afterPump,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // One matrix call per case, tree unmounted in between. A motion widget
    // plays ONCE when it mounts: re-pumping the same tree under a new
    // MediaQuery/locale reuses the finished State and the next case captures
    // a blank frame (5 of 7 images of FloatingComboText and ItemFlyOverlay
    // were one-colour before this).
    for (final c in defaultGoldenMatrix()) {
      await runGoldenMatrix(
        tester,
        (_) => SizedBox(width: size.width, height: size.height, child: build()),
        goldenBaseName: name,
        matrix: [c],
        guidelines: const [],
        afterPump: afterPump,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  }

  /// Pumps [total] in small steps so every ticker/timer gets a frame, ending
  /// at an exact elapsed time. One long `pump(total)` would fire timers but
  /// not run the animation they start (see ENH-122: empty goldens).
  Future<void> pumpTo(WidgetTester t, Duration total, {int stepMs = 50}) async {
    var spent = 0;
    while (spent < total.inMilliseconds) {
      await t.pump(Duration(milliseconds: stepMs));
      spent += stepMs;
    }
  }

  Widget face(String text, Color color) => Container(
    width: 140,
    height: 200,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
    child: Text(text),
  );

  testWidgets('CardFlip3D', (tester) async {
    await golden(
      tester,
      'cardflip3d_states',
      () => Center(
        child: Wrap(
          spacing: 16,
          children: [
            CardFlip3D(front: face('Front', Colors.indigo), back: face('Back', Colors.teal), showGleam: false),
            CardFlip3D(
              front: face('Front', Colors.indigo),
              back: face('Back', Colors.teal),
              isFlipped: true,
              showGleam: false,
            ),
          ],
        ),
      ),
      afterPump: (t) => pumpTo(t, const Duration(seconds: 1)),
    );
  });

  testWidgets('CoinFlyOverlay mid flight', (tester) async {
    await golden(
      tester,
      'coinflyoverlay_midflight',
      () => const CoinFlyOverlay(from: Offset(60, 500), to: Offset(330, 60), coinCount: 5),
      afterPump: (t) => pumpTo(t, mid),
    );
  });

  testWidgets('FloatingComboText mid rise', (tester) async {
    await golden(
      tester,
      'floatingcombotext_midrise',
      () => const Center(child: FloatingComboText(text: 'COMBO x5')),
      afterPump: (t) => pumpTo(t, const Duration(milliseconds: 400)),
    );
  });

  testWidgets('FloatingEmojiBurst seeded', (tester) async {
    final emojiKey = GlobalKey<FloatingEmojiBurstState>();
    await golden(
      tester,
      'floatingemojiburst_seeded',
      () => FloatingEmojiBurst(key: emojiKey, random: Random(7), origin: const Offset(0.5, 0.9)),
      // Nothing is drawn until `burst()` is called: three emojis from three
      // different origins (same origin overlaps them into one blob), then a
      // fixed instant. Without this every case is an empty (one-colour) image.
      afterPump: (t) async {
        final state = emojiKey.currentState!;
        state.burst('🎉', origin: const Offset(0.2, 0.9));
        state.burst('⭐', origin: const Offset(0.5, 0.9));
        state.burst('🔥', origin: const Offset(0.8, 0.9));
        await pumpTo(t, const Duration(milliseconds: 600));
      },
    );
  });

  testWidgets('GoldenShimmerText', (tester) async {
    await golden(
      tester,
      'goldenshimmertext_states',
      () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GoldenShimmerText('Level 12', fontSize: 32, animated: false),
            SizedBox(height: 16),
            GoldenShimmerText('WIN!', fontSize: 48, stroke: Color(0xFF7A4B00)),
          ],
        ),
      ),
      afterPump: (t) => pumpTo(t, const Duration(milliseconds: 450)),
    );
  });

  testWidgets('ItemFlyOverlay mid flight', (tester) async {
    await golden(
      tester,
      'itemflyoverlay_midflight',
      () => ItemFlyOverlay(from: const Offset(60, 500), to: const Offset(330, 60), icon: Icons.star, itemCount: 4),
      afterPump: (t) => pumpTo(t, mid),
    );
  });

  testWidgets('PooledParticleBurst seeded', (tester) async {
    final burstKey = GlobalKey<PooledParticleBurstState>();
    await golden(
      tester,
      'pooledparticleburst_seeded',
      () => PooledParticleBurst(key: burstKey, randomSeed: 42, particleCount: 40),
      afterPump: (t) async {
        burstKey.currentState!.burst();
        await pumpTo(t, const Duration(milliseconds: 400));
      },
    );
  });

  testWidgets('RadialActionMenu', (tester) async {
    final key = GlobalKey<RadialActionMenuState>();
    await golden(
      tester,
      'radialactionmenu_open',
      () => RadialActionMenu(
        key: key,
        items: [
          RadialActionItem(label: 'Share', icon: Icons.share, onTap: () {}),
          RadialActionItem(label: 'Edit', icon: Icons.edit, onTap: () {}),
          RadialActionItem(label: 'Delete', icon: Icons.delete, onTap: () {}),
        ],
      ),
      // A tap by finder misses the floating button (it sits at a corner of
      // the full-size host), leaving the menu closed in every case.
      afterPump: (t) async {
        key.currentState!.open();
        await pumpTo(t, const Duration(seconds: 1));
      },
    );
  });

  testWidgets('ScreenShake at rest', (tester) async {
    final controller = ScreenShakeController();
    addTearDown(controller.dispose);
    await golden(
      tester,
      'screenshake_rest',
      () => ScreenShake(
        controller: controller,
        child: Center(child: face('steady', Colors.deepOrange)),
      ),
    );
  });

  testWidgets('ShimmerPlaceholder', (tester) async {
    await golden(
      tester,
      'shimmerplaceholder_states',
      () => const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerPlaceholder(width: 280),
            SizedBox(height: 12),
            ShimmerPlaceholder(width: 200, height: 24),
            SizedBox(height: 12),
            ShimmerPlaceholder(width: 64, height: 64, shape: BoxShape.circle),
          ],
        ),
      ),
      afterPump: (t) => pumpTo(t, const Duration(milliseconds: 300)),
    );
  });

  testWidgets('SquashStretch at rest', (tester) async {
    await golden(
      tester,
      'squashstretch_rest',
      () => Center(
        child: SquashStretch(onTap: () {}, child: face('tap me', NeonTheme.cyan)),
      ),
    );
  });
}
