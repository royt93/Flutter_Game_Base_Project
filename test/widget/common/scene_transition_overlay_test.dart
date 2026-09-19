import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';
import 'package:roy_casual_kit/presentation/widgets/common/scene_transition_overlay.dart';

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
}
