import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/adaptive_game_hud.dart';
import 'package:roy_casual_kit/presentation/widgets/common/circular_progress_ring.dart';
import 'package:roy_casual_kit/presentation/widgets/common/combo_heat_background.dart';
import 'package:roy_casual_kit/presentation/widgets/common/combo_meter_bar.dart';
import 'package:roy_casual_kit/presentation/widgets/common/currency_counter.dart';
import 'package:roy_casual_kit/presentation/widgets/common/energy_bar.dart';
import 'package:roy_casual_kit/presentation/widgets/common/game_joystick.dart';
import 'package:roy_casual_kit/presentation/widgets/common/level_goal_tracker.dart';
import 'package:roy_casual_kit/presentation/widgets/common/live_frame_graph.dart';
import 'package:roy_casual_kit/presentation/widgets/common/progress_bar_stars.dart';
import 'package:roy_casual_kit/presentation/widgets/common/star_chest_progress_hud.dart';
import 'package:roy_casual_kit/presentation/widgets/common/streak_counter.dart';
import 'package:roy_casual_kit/presentation/widgets/common/tap_hint_pointer.dart';

import '../../support/golden_matrix.dart';
import 'golden_test_support.dart';

/// ENH-120 (batch C): game HUD / progress widgets. One golden per widget with
/// the interesting states stacked in one frame, rendered through the shared
/// matrix. Deterministic: every value is fixed, no animation is left running
/// (looping/pop animations are either off or idle at their first frame).
///
/// Not covered on purpose: `ReactiveEnergyBar` (polls an `EnergyService` on a
/// timer; `EnergyBar` is its pure renderer), animated transitions (pop, roll,
/// star burst: behavior tests own those).
void main() {
  final previous = installGoldenTolerance(
    'batch_c_game_hud_widgets_golden_test.dart',
  );
  tearDownAll(() => goldenFileComparator = previous);

  Widget stack(List<Widget> children, {double width = 340}) => SizedBox(
    width: width,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    ),
  );

  Future<void> golden(
    WidgetTester tester,
    String name,
    Widget Function() build, {
    Size size = const Size(390, 700),
    Future<void> Function(WidgetTester)? afterPump,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await runGoldenMatrix(
      tester,
      (_) => Padding(padding: const EdgeInsets.all(16), child: build()),
      goldenBaseName: name,
      guidelines: const [],
      afterPump: afterPump,
    );
  }

  testWidgets('AdaptiveGameHud', (tester) async {
    Widget chip(String t, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: c,
      child: Text(t, style: const TextStyle(color: Colors.white)),
    );
    await golden(
      tester,
      'adaptivegamehud_slots',
      () => ColoredBox(
        color: NeonTheme.cardAlt,
        child: SizedBox(
          width: 340,
          height: 420,
          child: AdaptiveGameHud(
            slots: {
              HudSlot.topStart: chip('Start', Colors.indigo),
              HudSlot.topCenter: chip('Center', Colors.teal),
              HudSlot.topEnd: chip('End', Colors.deepOrange),
              HudSlot.bottom: chip('Bottom', Colors.purple),
            },
          ),
        ),
      ),
    );
  });

  testWidgets('ComboMeterBar', (tester) async {
    await golden(
      tester,
      'combometerbar_states',
      () => stack([
        ComboMeterBar(multiplier: 1, progress: 0.0, width: 300),
        ComboMeterBar(multiplier: 2, progress: 0.4, width: 300),
        ComboMeterBar(multiplier: 5, progress: 0.75, width: 300),
        ComboMeterBar(multiplier: 10, progress: 1.0, width: 300),
        ComboMeterBar(
          multiplier: 3,
          progress: 0.5,
          width: 300,
          showMultiplierBadge: false,
        ),
      ]),
    );
  });

  testWidgets('ComboHeatBackground', (tester) async {
    Widget cell(double heat) => SizedBox(
      width: 100,
      height: 80,
      child: ComboHeatBackground(
        heat: heat,
        child: Center(child: Text('${(heat * 100).round()}%')),
      ),
    );
    await golden(
      tester,
      'comboheatbackground_levels',
      () => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [cell(0), cell(0.33), cell(0.66), cell(1)],
      ),
    );
  });

  testWidgets('CircularProgressRing', (tester) async {
    await golden(
      tester,
      'circularprogressring_states',
      () => const Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          CircularProgressRing(progress: 0),
          CircularProgressRing(progress: 0.35, label: '35%'),
          CircularProgressRing(progress: 0.75, icon: Icons.star),
          CircularProgressRing(progress: 1, label: 'Done', size: 96),
          CircularProgressRing(
            progress: 0.6,
            strokeWidth: 14,
            color: Colors.green,
            child: Icon(Icons.bolt),
          ),
        ],
      ),
    );
  });

  testWidgets('ProgressBarStars', (tester) async {
    await golden(
      tester,
      'progressbarstars_states',
      () => stack([
        const ProgressBarStars(progress: 0),
        const ProgressBarStars(progress: 0.5),
        const ProgressBarStars(progress: 1),
        const ProgressBarStars(
          progress: 0.7,
          starThresholds: [0.25, 0.5, 0.75, 1.0],
          height: 28,
        ),
      ]),
    );
  });

  testWidgets('EnergyBar', (tester) async {
    await golden(
      tester,
      'energybar_states',
      () => Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          EnergyBar(
            currentEnergy: 3,
            maxEnergy: 5,
            timeUntilNextEnergy: const Duration(minutes: 12, seconds: 5),
            enableStatusPulse: false,
          ),
          EnergyBar(
            currentEnergy: 0,
            maxEnergy: 5,
            timeUntilNextEnergy: const Duration(minutes: 29, seconds: 59),
            enableStatusPulse: false,
            onRefillTap: () {},
          ),
          EnergyBar(
            currentEnergy: 5,
            maxEnergy: 5,
            timeUntilNextEnergy: Duration.zero,
            enableStatusPulse: false,
          ),
          EnergyBar(
            currentEnergy: 2,
            maxEnergy: 5,
            timeUntilNextEnergy: Duration.zero,
            hasInfiniteLives: true,
            enableStatusPulse: false,
          ),
          EnergyBar(
            currentEnergy: 2,
            maxEnergy: 5,
            timeUntilNextEnergy: const Duration(minutes: 3),
            direction: Axis.horizontal,
            enableStatusPulse: false,
          ),
        ],
      ),
    );
  });

  testWidgets('CurrencyCounter', (tester) async {
    await golden(
      tester,
      'currencycounter_states',
      () => stack([
        const CurrencyCounter(value: 0),
        const CurrencyCounter(value: 1250),
        const CurrencyCounter(value: 1250, compact: false),
        const CurrencyCounter(
          value: 4500000,
          icon: Icons.diamond,
          color: Colors.cyan,
          fontSize: 26,
        ),
      ]),
    );
  });

  testWidgets('LevelGoalTracker', (tester) async {
    List<GoalItem> goals() => [
      GoalItem(
        id: 'a',
        label: 'Red',
        icon: const Icon(Icons.circle, color: Colors.red),
        target: 10,
        current: 4,
      ),
      GoalItem(
        id: 'b',
        label: 'Blue',
        icon: const Icon(Icons.circle, color: Colors.blue),
        target: 8,
        current: 8,
      ),
      GoalItem(
        id: 'c',
        label: 'Star',
        icon: const Icon(Icons.star, color: Colors.amber),
        target: 3,
      ),
    ];
    await golden(
      tester,
      'levelgoaltracker_states',
      () => stack([
        // Horizontal is a non-wrapping Row: labels would overflow 340dp at 2x
        // text, so only the icon+count form is shown horizontally.
        LevelGoalTracker(goals: goals()),
        LevelGoalTracker(goals: goals().take(1).toList(), showLabel: true),
        LevelGoalTracker(
          goals: goals(),
          direction: Axis.vertical,
          showLabel: true,
        ),
      ]),
    );
  });

  testWidgets('StarChestProgressHud', (tester) async {
    await golden(
      tester,
      'starchestprogresshud_states',
      () => stack([
        StarChestProgressHud(currentStars: 0, targetStars: 10),
        StarChestProgressHud(currentStars: 4, targetStars: 10),
        StarChestProgressHud(
          currentStars: 10,
          targetStars: 10,
          onOpenChestTap: () {},
        ),
        StarChestProgressHud(
          currentStars: 6,
          targetStars: 12,
          onInfoTap: () {},
          width: 220,
        ),
      ]),
    );
  });

  testWidgets('StreakCounter', (tester) async {
    await golden(
      tester,
      'streakcounter_states',
      () => const Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          StreakCounter(days: 0),
          StreakCounter(days: 1),
          StreakCounter(days: 7),
          StreakCounter(days: 365, fontSize: 26),
          StreakCounter(days: 12, icon: Icons.bolt, color: Colors.blue),
        ],
      ),
    );
  });

  testWidgets('LiveFrameGraph', (tester) async {
    // 16 ms = normal, 24 ms = slow, 48 ms = jank; fixed pattern, no clock.
    final durations = [
      for (var i = 0; i < 30; i++)
        Duration(milliseconds: i % 10 == 9 ? 48 : (i % 4 == 3 ? 24 : 16)),
    ];
    await golden(
      tester,
      'liveframegraph_samples',
      () => SizedBox(
        width: 340,
        child: LiveFrameGraph(
          capacity: 40,
          sampleFrameTimings: Stream.fromIterable(durations),
        ),
      ),
      // Samples arrive via the stream, the graph repaints on a 100 ms timer.
      afterPump: (t) async {
        await t.pump(const Duration(milliseconds: 150));
        await t.pump(const Duration(milliseconds: 150));
      },
    );
  });

  testWidgets('GameJoystick', (tester) async {
    await golden(
      tester,
      'gamejoystick_idle',
      () => Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          GameJoystick(semanticLabel: 'Move', onDirectionChanged: (_, _) {}),
          GameJoystick(
            semanticLabel: 'Move small',
            size: 96,
            knobSize: 36,
            onDirectionChanged: (_, _) {},
          ),
        ],
      ),
    );
  });

  testWidgets('TapHintPointer', (tester) async {
    final tapTarget = GlobalKey();
    Widget dot(GlobalKey k, double left, double top) => Positioned(
      left: left,
      top: top,
      child: SizedBox(key: k, width: 20, height: 20),
    );
    Widget pane(List<Widget> children) => Container(
      width: 160,
      height: 120,
      color: NeonTheme.cardAlt,
      child: Stack(clipBehavior: Clip.hardEdge, children: children),
    );
    await golden(
      tester,
      'taphintpointer_states',
      // The pointer needs its target laid out to place the hint: the wrapper
      // rebuilds once after the first frame. Only `tap` is shown: swipe at
      // t=0 draws the same frame (the motion is a behavior-test concern).
      () => _RebuildOnce(
        builder: () => pane([
          dot(tapTarget, 70, 50),
          TapHintPointer(targetKey: tapTarget),
        ]),
      ),
    );
  });
}

class _RebuildOnce extends StatefulWidget {
  const _RebuildOnce({required this.builder});
  final Widget Function() builder;

  @override
  State<_RebuildOnce> createState() => _RebuildOnceState();
}

class _RebuildOnceState extends State<_RebuildOnce> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder();
}
