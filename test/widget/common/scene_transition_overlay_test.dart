import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';
import 'package:roy_casual_kit/presentation/widgets/common/retry_error_state.dart';
import 'package:roy_casual_kit/presentation/widgets/common/scene_transition_overlay.dart';
import 'package:roy_casual_kit/presentation/widgets/common/scene_wipe_geometry.dart';

Widget _wrap(Widget child) => MaterialApp(home: Material(child: child));

const _kStep = Duration(milliseconds: 1);

// coverDuration/revealDuration cố tình KHÔNG dùng Duration.zero — một Timer
// zero-duration có thể không được fake_async flush hết chỉ với 1 lần
// `pump()` trơn (dễ để lại "pending timer" ở cuối test) — dùng 1ms + advance
// tường minh qua `pump(_kStep)` sau mỗi lần gọi run()/complete() để chắc
// chắn đi hết qua từng giai đoạn covering/loading/revealing.
SceneTransitionController _controller() =>
    SceneTransitionController(coverDuration: _kStep, revealDuration: _kStep);

void main() {
  group('FEAT-105: wipe geometry', () {
    test('maximum radius reaches the farthest screen corner', () {
      expect(
        sceneWipeMaxRadius(const Size(300, 200), const Offset(150, 100)),
        closeTo(math.sqrt(150 * 150 + 100 * 100), 0.001),
      );
      expect(
        sceneWipeMaxRadius(const Size(300, 200), const Offset(0, 0)),
        closeTo(math.sqrt(300 * 300 + 200 * 200), 0.001),
      );
    });

    test('each shape starts empty and covers viewport at completion', () {
      for (final shape in SceneWipeShape.values.where(
        (shape) => shape != SceneWipeShape.fade,
      )) {
        expect(
          sceneWipePath(
            size: const Size(300, 200),
            center: const Offset(150, 100),
            progress: 0,
            shape: shape,
          ).computeMetrics(),
          isEmpty,
        );
        expect(
          sceneWipePath(
            size: const Size(300, 200),
            center: const Offset(150, 100),
            progress: 1,
            shape: shape,
          ).getBounds(),
          const Rect.fromLTWH(0, 0, 300, 200),
        );
      }
    });
  });

  testWidgets(
    'Iris wipe covers then reveals scene and restores pointer input',
    (tester) async {
      final controller = SceneTransitionController(
        coverDuration: const Duration(milliseconds: 100),
        revealDuration: const Duration(milliseconds: 100),
      );
      addTearDown(controller.dispose);
      var taps = 0;
      final loaded = Completer<SdkResult<void>>();
      await tester.pumpWidget(
        _wrap(
          SceneTransitionOverlay(
            controller: controller,
            wipeShape: SceneWipeShape.iris,
            child: GestureDetector(
              onTap: () => taps++,
              child: const Text('Scene'),
            ),
          ),
        ),
      );
      final run = controller.run((_) => loaded.future);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(ClipPath), findsOneWidget);
      await tester.tap(find.text('Scene'), warnIfMissed: false);
      expect(taps, 0);
      await tester.pump(const Duration(milliseconds: 60));
      expect(controller.phase.value, SceneTransitionPhase.loading);

      loaded.complete(const SdkSuccess(null));
      await tester.pump();
      expect(controller.phase.value, SceneTransitionPhase.revealing);
      await tester.pump(const Duration(milliseconds: 110));
      await run;
      expect(controller.phase.value, SceneTransitionPhase.idle);
      await tester.tap(find.text('Scene'));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('star wipe respects reduced motion and balances on cancel', (
    tester,
  ) async {
    final controller = SceneTransitionController(
      coverDuration: const Duration(milliseconds: 100),
      revealDuration: const Duration(milliseconds: 100),
    );
    addTearDown(controller.dispose);
    final loaded = Completer<SdkResult<void>>();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _wrap(
          SceneTransitionOverlay(
            controller: controller,
            wipeShape: SceneWipeShape.star,
            child: const Text('Scene'),
          ),
        ),
      ),
    );
    unawaited(controller.run((_) => loaded.future));
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.phase.value, SceneTransitionPhase.loading);
    expect(tester.takeException(), isNull);
    controller.cancel();
    await tester.pump();
    expect(find.byType(ClipPath), findsNothing);
    loaded.complete(const SdkSuccess(null));
  });

  testWidgets(
    'normal-motion reveal uses revealDuration and active state clears on completion',
    (tester) async {
      final controller = SceneTransitionController(
        coverDuration: const Duration(milliseconds: 10),
        revealDuration: const Duration(milliseconds: 200),
      );
      addTearDown(controller.dispose);
      final loaded = Completer<SdkResult<void>>();
      await tester.pumpWidget(
        _wrap(
          SceneTransitionOverlay(
            controller: controller,
            child: const Text('Scene'),
          ),
        ),
      );
      expect(controller.isActive, isFalse);
      final future = controller.run((_) => loaded.future);
      await tester.pump(const Duration(milliseconds: 10));
      expect(controller.isActive, isTrue);
      loaded.complete(const SdkSuccess(null));
      await tester.pump();
      expect(controller.phase.value, SceneTransitionPhase.revealing);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration,
        const Duration(milliseconds: 200),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await future;
      expect(controller.isActive, isFalse);
    },
  );

  testWidgets('idle: child hiện bình thường, không có barrier, nhận được tap', (
    tester,
  ) async {
    final controller = _controller();
    var tapped = false;

    await tester.pumpWidget(
      _wrap(
        SceneTransitionOverlay(
          controller: controller,
          child: GestureDetector(
            onTap: () => tapped = true,
            child: const Text('Scene content'),
          ),
        ),
      ),
    );

    expect(find.text('Scene content'), findsOneWidget);
    await tester.tap(find.text('Scene content'));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'đang loading: barrier chắn tap tới child, hiện CircularProgressIndicator',
    (tester) async {
      final controller = _controller();
      var tapped = false;
      final completer = Completer<SdkResult<void>>();

      await tester.pumpWidget(
        _wrap(
          SceneTransitionOverlay(
            controller: controller,
            child: GestureDetector(
              onTap: () => tapped = true,
              child: const Text('Scene content'),
            ),
          ),
        ),
      );

      unawaited(controller.run((onProgress) => completer.future));
      await tester.pump(_kStep); // qua hết covering, vào loading

      expect(controller.phase.value, SceneTransitionPhase.loading);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Tap đúng vị trí "Scene content" nhưng bị barrier chắn — không được
      // lọt xuống child bên dưới.
      await tester.tap(find.text('Scene content'), warnIfMissed: false);
      expect(tapped, isFalse);

      completer.complete(const SdkSuccess(null));
      await tester.pump(_kStep); // qua hết revealing, về idle
      expect(controller.phase.value, SceneTransitionPhase.idle);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('load fail: hiện RetryErrorState, bấm Retry gọi lại onRetry', (
    tester,
  ) async {
    final controller = _controller();
    var retried = false;

    await tester.pumpWidget(
      _wrap(
        SceneTransitionOverlay(
          controller: controller,
          onRetry: () async {
            retried = true;
          },
          child: const Text('Scene content'),
        ),
      ),
    );

    final runFuture = controller.run(
      (onProgress) async =>
          const SdkFailure(kind: SdkErrorKind.network, message: 'no internet'),
    );
    await tester.pump(_kStep);
    await runFuture;
    await tester.pump();

    expect(controller.phase.value, SceneTransitionPhase.error);
    expect(find.text('no internet'), findsOneWidget);
    await tester.tap(find.text('Retry').last);
    await tester.pump();

    expect(retried, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancel() giữa chừng: barrier biến mất ngay, child nhận tap lại được',
    (tester) async {
      final controller = _controller();
      var tapped = false;
      final completer = Completer<SdkResult<void>>();

      await tester.pumpWidget(
        _wrap(
          SceneTransitionOverlay(
            controller: controller,
            child: GestureDetector(
              onTap: () => tapped = true,
              child: const Text('Scene content'),
            ),
          ),
        ),
      );

      final future = controller.run((onProgress) => completer.future);
      await tester.pump(_kStep);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      controller.cancel();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Scene content'));
      expect(tapped, isTrue);

      completer.complete(const SdkSuccess(null));
      await future;
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'widget dispose giữa chừng transition không throw (rapid navigation)',
    (tester) async {
      final controller = _controller();
      final completer = Completer<SdkResult<void>>();

      await tester.pumpWidget(
        _wrap(
          SceneTransitionOverlay(
            controller: controller,
            child: const Text('Scene content'),
          ),
        ),
      );

      unawaited(controller.run((onProgress) => completer.future));
      await tester.pump(_kStep);

      // Điều hướng đi nơi khác — widget bị dispose khỏi cây trong khi
      // transition còn dở.
      await tester.pumpWidget(_wrap(const Text('Other screen')));

      completer.complete(const SdkSuccess(null));
      await tester.pump(_kStep);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'BUG-76: load throw exception chuyển sang error và không kẹt loading indicator',
    (tester) async {
      final controller = _controller();
      var retried = false;

      await tester.pumpWidget(
        _wrap(
          SceneTransitionOverlay(
            controller: controller,
            onRetry: () async {
              retried = true;
            },
            child: const Text('Scene content'),
          ),
        ),
      );

      final runFuture = controller.run((onProgress) async {
        throw StateError('asset bundle decode crashed');
      });

      await tester.pump(_kStep);
      final result = await runFuture;
      await tester.pump();

      expect(result, isA<SdkFailure<void>>());
      expect(controller.phase.value, SceneTransitionPhase.error);
      expect(controller.lastError, isNotNull);
      expect(controller.lastError?.cause, isA<StateError>());
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(RetryErrorState), findsOneWidget);

      await tester.tap(find.text('Retry').last);
      await tester.pump();
      expect(retried, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
