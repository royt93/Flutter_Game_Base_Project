import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/asset_preload_coordinator.dart';
import 'package:roy_casual_kit/core/game_session_controller.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';
import 'package:roy_casual_kit/presentation/widgets/common/scene_transition_overlay.dart';

SceneTransitionController _controller() => SceneTransitionController(
  coverDuration: Duration.zero,
  revealDuration: Duration.zero,
);

void main() {
  group('SceneTransitionController: happy path', () {
    test('trạng thái ban đầu là idle, progress 0', () {
      final controller = _controller();
      expect(controller.phase.value, SceneTransitionPhase.idle);
      expect(controller.progress.value, 0.0);
    });

    test(
      'run() thành công đi qua covering → loading → revealing → idle',
      () async {
        final controller = _controller();
        final seen = <SceneTransitionPhase>[];
        controller.phase.listen(seen.add);

        final result = await controller.run((onProgress) async {
          onProgress(0.5);
          onProgress(1.0);
          return const SdkSuccess(null);
        });

        expect(result, isA<SdkSuccess<void>>());
        expect(controller.phase.value, SceneTransitionPhase.idle);
        expect(
          seen,
          containsAllInOrder([
            SceneTransitionPhase.covering,
            SceneTransitionPhase.loading,
            SceneTransitionPhase.revealing,
            SceneTransitionPhase.idle,
          ]),
        );
      },
    );

    test('onProgress trong load cập nhật đúng controller.progress', () async {
      final controller = _controller();
      final observed = <double>[];
      controller.progress.listen(observed.add);

      await controller.run((onProgress) async {
        onProgress(0.3);
        onProgress(0.7);
        onProgress(1.0);
        return const SdkSuccess(null);
      });

      expect(observed, containsAllInOrder([0.3, 0.7, 1.0]));
    });
  });

  group('SceneTransitionController: error/retry', () {
    test('load fail: phase dừng ở error, lưu lại lastError', () async {
      final controller = _controller();
      const failure = SdkFailure<void>(
        kind: SdkErrorKind.network,
        message: 'no internet',
      );

      final result = await controller.run((onProgress) async => failure);

      expect(result, isA<SdkFailure<void>>());
      expect(controller.phase.value, SceneTransitionPhase.error);
      expect(controller.lastError, failure);
    });

    test('retry() sau lỗi chạy lại load, thành công thì về idle', () async {
      final controller = _controller();
      var attempt = 0;

      Future<SdkResult<void>> load(void Function(double) onProgress) async {
        attempt++;
        if (attempt == 1) {
          return const SdkFailure(
            kind: SdkErrorKind.network,
            message: 'no internet',
          );
        }
        onProgress(1.0);
        return const SdkSuccess(null);
      }

      final first = await controller.run(load);
      expect(first, isA<SdkFailure<void>>());
      expect(controller.phase.value, SceneTransitionPhase.error);

      final second = await controller.retry(load);
      expect(second, isA<SdkSuccess<void>>());
      expect(controller.phase.value, SceneTransitionPhase.idle);
      expect(controller.lastError, isNull);
    });

    test(
      'BUG-76: load throw exception trả về SdkFailure có cause/stackTrace và cập nhật lastError/phase',
      () async {
        final controller = _controller();
        final error = StateError('asset load crash');

        final result = await controller.run((onProgress) async => throw error);

        expect(result, isA<SdkFailure<void>>());
        final failure = result as SdkFailure<void>;
        expect(failure.cause, error);
        expect(failure.stackTrace, isNotNull);
        expect(controller.phase.value, SceneTransitionPhase.error);
        expect(controller.lastError, failure);
      },
    );

    test(
      'BUG-76: transition superseded hoặc cancelled: callback throw muộn không mutate state',
      () async {
        final controller = _controller();
        final completer = Completer<SdkResult<void>>();

        final firstFuture = controller.run((onProgress) => completer.future);
        await Future<void>.delayed(Duration.zero);
        expect(controller.phase.value, SceneTransitionPhase.loading);

        final secondFuture = controller.run((onProgress) async {
          return const SdkSuccess(null);
        });

        await secondFuture;
        expect(controller.phase.value, SceneTransitionPhase.idle);

        completer.completeError(StateError('stale throw'));
        final staleResult = await firstFuture;

        expect(staleResult, isA<SdkFailure<void>>());
        expect(controller.phase.value, SceneTransitionPhase.idle);
        expect(controller.lastError, isNull);
      },
    );
  });

  group('SceneTransitionController: cancel không kẹt pointer barrier', () {
    test('cancel() giữa chừng đưa phase về idle ngay lập tức', () async {
      final controller = _controller();
      final completer = Completer<SdkResult<void>>();

      final future = controller.run((onProgress) => completer.future);
      await Future<void>.delayed(Duration.zero);
      expect(controller.phase.value, SceneTransitionPhase.loading);

      controller.cancel();
      expect(controller.phase.value, SceneTransitionPhase.idle);

      completer.complete(const SdkSuccess(null));
      await future;

      // Load cũ hoàn tất SAU cancel không được kéo phase ra khỏi idle.
      expect(controller.phase.value, SceneTransitionPhase.idle);
    });
  });

  group('SceneTransitionController: rapid navigation không callback stale', () {
    test('run() thứ 2 gọi trong lúc run() thứ 1 còn dở: chỉ kết quả run() '
        'mới nhất quyết định trạng thái cuối', () async {
      final controller = _controller();
      final firstCompleter = Completer<SdkResult<void>>();

      final firstFuture = controller.run((onProgress) => firstCompleter.future);

      final secondFuture = controller.run((onProgress) async {
        onProgress(1.0);
        return const SdkSuccess(null);
      });

      await secondFuture;
      expect(controller.phase.value, SceneTransitionPhase.idle);

      // run() đầu tiên (đã bị "supersede") fail muộn — không được kéo
      // phase ra khỏi idle nữa vì token của nó không còn là active token.
      firstCompleter.complete(
        const SdkFailure(kind: SdkErrorKind.network, message: 'stale'),
      );
      await firstFuture;

      expect(controller.phase.value, SceneTransitionPhase.idle);
      expect(controller.lastError, isNull);
    });
  });

  group('SceneTransitionController: dispose', () {
    test('run() sau khi dispose() không throw và không đổi phase', () async {
      final controller = _controller();
      controller.dispose();

      final result = await controller.run(
        (onProgress) async => const SdkSuccess(null),
      );

      expect(result, isA<SdkFailure<void>>());
      expect(controller.phase.value, SceneTransitionPhase.idle);
    });

    test(
      'dispose() giữa chừng: load hoàn tất sau đó không còn đổi phase nữa',
      () async {
        final controller = _controller();
        final completer = Completer<SdkResult<void>>();

        final future = controller.run((onProgress) => completer.future);
        await Future<void>.delayed(Duration.zero);
        expect(controller.phase.value, SceneTransitionPhase.loading);

        controller.dispose();
        completer.complete(const SdkSuccess(null));
        await future;

        // Vẫn ở loading (không nhảy sang revealing/idle) vì controller đã
        // dispose — không còn "callback stale" nào được áp dụng vào state.
        expect(controller.phase.value, SceneTransitionPhase.loading);
      },
    );
  });

  group(
    'SceneTransitionController: đồng bộ AssetPreloadCoordinator + GameSessionController',
    () {
      test(
        'runWithAssetPreload: preload OK thì markReady()+start() trên session thật',
        () async {
          final controller = _controller();
          final preload = AssetPreloadCoordinator(loader: (item) async {});
          final session = GameSessionController();
          addTearDown(session.onClose);

          final result = await controller.runWithAssetPreload(
            preload: preload,
            manifest: const [
              AssetManifestItem(
                id: 'bg',
                kind: AssetKind.image,
                path: 'bg.png',
              ),
            ],
            session: session,
          );

          expect(result, isA<SdkSuccess<void>>());
          expect(session.snapshot.value.phase, GameSessionPhase.playing);
          expect(controller.phase.value, SceneTransitionPhase.idle);
        },
      );

      test(
        'runWithAssetPreload: preload fail thì KHÔNG gọi markReady(), phase error',
        () async {
          final controller = _controller();
          final preload = AssetPreloadCoordinator(
            loader: (item) async => throw Exception('load lỗi'),
          );
          final session = GameSessionController();
          addTearDown(session.onClose);

          final result = await controller.runWithAssetPreload(
            preload: preload,
            manifest: const [
              AssetManifestItem(
                id: 'bg',
                kind: AssetKind.image,
                path: 'bg.png',
              ),
            ],
            session: session,
          );

          expect(result, isA<SdkFailure<void>>());
          expect(session.snapshot.value.phase, GameSessionPhase.loading);
          expect(controller.phase.value, SceneTransitionPhase.error);
        },
      );

      test(
        'runWithAssetPreload: controller.progress theo dõi đúng preload.progress',
        () async {
          final controller = _controller();
          final preload = AssetPreloadCoordinator(loader: (item) async {});
          final observed = <double>[];
          controller.progress.listen(observed.add);

          await controller.runWithAssetPreload(
            preload: preload,
            manifest: const [
              AssetManifestItem(
                id: 'bg',
                kind: AssetKind.image,
                path: 'bg.png',
                weight: 1,
              ),
              AssetManifestItem(
                id: 'sfx',
                kind: AssetKind.audio,
                path: 'sfx.mp3',
                weight: 1,
              ),
            ],
          );

          expect(observed, isNotEmpty);
          expect(observed.last, 1.0);
        },
      );
    },
  );
}
