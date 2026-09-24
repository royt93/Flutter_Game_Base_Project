import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';
import 'package:roy_casual_kit/presentation/widgets/flame_tracked_overlay.dart';

/// FEAT-92 prototype benchmark. Real GPU frame timing isn't available (or
/// deterministic/CI-safe) inside a headless `flutter test` VM, so this
/// measures the actual bottleneck the task is about directly: how many
/// `RenderStack.performLayout()` passes the enclosing `Stack` does across
/// many position-changing frames.
///
/// `Positioned`'s `left`/`top` are `StackParentData`, owned by the PARENT
/// `RenderStack` — changing them (via `setState()` rebuilding a new
/// `Positioned` every tick) marks the STACK dirty, not the individual
/// tracked child (whose own layout constraints never change, so its own
/// `performLayout()` is often skipped by Flutter's relayout-boundary
/// optimization regardless — measuring the leaf child would understate
/// the real cost). `Transform.translate` only marks `RenderTransform` for
/// REPAINT, never touches `StackParentData`/layout at all. Counting the
/// Stack's own layout passes directly proves (or disproves) the claim
/// with 0 flakiness — many `markNeedsLayout()` calls on the Stack within
/// 1 frame coalesce into exactly 1 `performLayout()` for that frame, so
/// this count is "how many FRAMES forced a Stack relayout", independent
/// of how many overlays are tracked.
class _LayoutCounter {
  int count = 0;
}

class _CountingStack extends Stack {
  const _CountingStack({required this.counter, super.children});

  final _LayoutCounter counter;

  @override
  RenderStack createRenderObject(BuildContext context) => _RenderCountingStack(
    counter: counter,
    alignment: alignment,
    textDirection: textDirection ?? Directionality.of(context),
    fit: fit,
    clipBehavior: clipBehavior,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderCountingStack renderObject,
  ) {
    renderObject
      ..counter = counter
      ..alignment = alignment
      ..textDirection = textDirection ?? Directionality.of(context)
      ..fit = fit
      ..clipBehavior = clipBehavior;
  }
}

class _RenderCountingStack extends RenderStack {
  _RenderCountingStack({
    required this.counter,
    required super.alignment,
    required super.textDirection,
    required super.fit,
    required super.clipBehavior,
  });

  _LayoutCounter counter;

  @override
  void performLayout() {
    counter.count++;
    super.performLayout();
  }
}

/// A faithful, self-contained reproduction of FlameTrackedOverlay's
/// PRE-FEAT-92 mechanism (`setState()` + `Positioned(left:, top:)`
/// recomputed every tick) — kept ONLY here, for this before/after
/// benchmark comparison. Takes a plain `Offset Function()` instead of
/// going through real Flame camera math, since that part is orthogonal to
/// what's being measured and is already covered by
/// `flame_tracked_overlay_test.dart`'s own position-correctness tests.
class _OldStyleTrackedOverlay extends StatefulWidget {
  const _OldStyleTrackedOverlay({required this.positionOf, required this.child});

  final Offset Function() positionOf;
  final Widget child;

  @override
  State<_OldStyleTrackedOverlay> createState() =>
      _OldStyleTrackedOverlayState();
}

class _OldStyleTrackedOverlayState extends State<_OldStyleTrackedOverlay>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Offset? _offset;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final next = widget.positionOf();
      if (next != _offset && mounted) setState(() => _offset = next);
    })..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offset = _offset;
    if (offset == null) return const SizedBox.shrink();
    return Positioned(left: offset.dx, top: offset.dy, child: widget.child);
  }
}

void main() {
  testWidgets(
    'MỚI (Transform.translate, paint-only): N overlay qua M frame vị trí '
    'đổi liên tục -> Stack chỉ relayout ĐÚNG 1 LẦN (lúc resolve lần đầu), '
    'KHÔNG relayout thêm dù vị trí đổi M lần sau đó',
    (tester) async {
      const overlayCount = 50;
      const frameCount = 20;
      final game = RoyGame();
      final gameKey = GlobalKey();
      final stackLayouts = _LayoutCounter();

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: _CountingStack(
              counter: stackLayouts,
              children: [
                GameWidget(key: gameKey, game: game),
                for (var i = 0; i < overlayCount; i++)
                  FlameTrackedOverlay(
                    game: game,
                    gameWidgetKey: gameKey,
                    worldPositionOf: () =>
                        game.circle.position + Vector2(i.toDouble(), 0),
                    child: const SizedBox(width: 10, height: 10),
                  ),
              ],
            ),
          ),
        ),
      );
      await game.toBeLoaded();
      await tester.pump();
      // IDEA-65: RoyGame's components now add their own hitbox child in
      // onLoad (TappableCircle/BouncingOrb) — that child's own mount
      // settles on the frame AFTER the one that flushes toBeLoaded(), so
      // a single pump() here left 1 more relayout to leak into the
      // frameCount loop below (inflating the "no more relayouts" count
      // this test asserts on). A second pump folds that settling into
      // the initial-resolve baseline instead, where it belongs.
      await tester.pump();
      final layoutsAfterInitialResolve = stackLayouts.count;
      expect(
        layoutsAfterInitialResolve,
        greaterThan(0),
        reason: 'ít nhất 1 lần relayout khi mọi overlay resolve lần đầu',
      );

      for (var f = 0; f < frameCount; f++) {
        game.circle.position += Vector2(1, 1);
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(
        stackLayouts.count,
        layoutsAfterInitialResolve,
        reason:
            'sau lần resolve đầu tiên, Stack KHÔNG được relayout thêm lần '
            'nào nữa dù vị trí đổi $frameCount lần — mọi update sau đó chỉ '
            'là paint-time Transform, không chạm StackParentData/layout',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CŨ (Positioned+setState mỗi frame — mô phỏng lại cơ chế trước '
    'FEAT-92, chỉ để so sánh benchmark): vị trí đổi mỗi frame -> Stack '
    'relayout gần như MỖI FRAME, chứng minh đúng vấn đề cần giải quyết',
    (tester) async {
      const overlayCount = 10;
      const frameCount = 20;
      final stackLayouts = _LayoutCounter();
      var tick = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: _CountingStack(
              counter: stackLayouts,
              children: [
                for (var i = 0; i < overlayCount; i++)
                  _OldStyleTrackedOverlay(
                    positionOf: () =>
                        Offset(i.toDouble() + tick, tick.toDouble()),
                    child: const SizedBox(width: 10, height: 10),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final layoutsAfterInitialResolve = stackLayouts.count;

      for (var f = 0; f < frameCount; f++) {
        tick++;
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(
        stackLayouts.count - layoutsAfterInitialResolve,
        greaterThan(frameCount ~/ 2),
        reason:
            'cơ chế Positioned+setState cũ phải relayout Stack gần như mỗi '
            'frame vị trí đổi (đây chính là vấn đề FEAT-92 giải quyết) — '
            'nếu số này THẤP thì benchmark trên không còn ý nghĩa so sánh',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
