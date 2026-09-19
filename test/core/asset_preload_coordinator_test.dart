import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/asset_preload_coordinator.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';

AssetPreloadCoordinator _coordinator({
  required AssetLoaderFn loader,
  AssetUnloaderFn? unloader,
  int maxConcurrent = 4,
}) => AssetPreloadCoordinator(
  loader: loader,
  unloader: unloader,
  maxConcurrent: maxConcurrent,
);

void main() {
  group('AssetPreloadCoordinator: load cơ bản + cache', () {
    test('preload gọi loader đúng 1 lần cho mỗi item', () async {
      final calls = <String>[];
      final coordinator = _coordinator(
        loader: (item) async => calls.add(item.id),
      );

      final result = await coordinator.preload(const [
        AssetManifestItem(id: 'bg', kind: AssetKind.image, path: 'bg.png'),
        AssetManifestItem(id: 'sfx', kind: AssetKind.audio, path: 'sfx.mp3'),
      ]);

      expect(result, isA<SdkSuccess<void>>());
      expect(calls..sort(), ['bg', 'sfx']);
    });

    test(
      'asset trùng id đã load rồi thì lần preload sau không gọi loader lại',
      () async {
        final calls = <String>[];
        final coordinator = _coordinator(
          loader: (item) async => calls.add(item.id),
        );
        const manifestA = [
          AssetManifestItem(id: 'shared', kind: AssetKind.image, path: 'a.png'),
        ];
        const manifestB = [
          AssetManifestItem(id: 'shared', kind: AssetKind.image, path: 'a.png'),
          AssetManifestItem(id: 'other', kind: AssetKind.image, path: 'b.png'),
        ];

        await coordinator.preload(manifestA);
        await coordinator.preload(manifestB);

        expect(calls, ['shared', 'other']);
      },
    );
  });

  group('AssetPreloadCoordinator: dependency graph', () {
    test('item phụ thuộc load sau khi dependency load xong', () async {
      final order = <String>[];
      final coordinator = _coordinator(
        loader: (item) async => order.add(item.id),
      );

      await coordinator.preload(const [
        AssetManifestItem(
          id: 'player',
          kind: AssetKind.image,
          path: 'player.png',
          dependsOn: ['atlas'],
        ),
        AssetManifestItem(
          id: 'atlas',
          kind: AssetKind.image,
          path: 'atlas.png',
        ),
      ]);

      expect(order, ['atlas', 'player']);
    });

    test(
      'dependency không tồn tại trong manifest báo SdkFailure kind validation',
      () async {
        final coordinator = _coordinator(loader: (item) async {});

        final result = await coordinator.preload(const [
          AssetManifestItem(
            id: 'player',
            kind: AssetKind.image,
            path: 'player.png',
            dependsOn: ['missing_atlas'],
          ),
        ]);

        expect(result, isA<SdkFailure<void>>());
        expect((result as SdkFailure<void>).kind, SdkErrorKind.validation);
      },
    );

    test(
      'dependency cycle báo SdkFailure kind validation, không treo',
      () async {
        final coordinator = _coordinator(loader: (item) async {});

        final result = await coordinator.preload(const [
          AssetManifestItem(
            id: 'a',
            kind: AssetKind.image,
            path: 'a.png',
            dependsOn: ['b'],
          ),
          AssetManifestItem(
            id: 'b',
            kind: AssetKind.image,
            path: 'b.png',
            dependsOn: ['a'],
          ),
        ]);

        expect(result, isA<SdkFailure<void>>());
        expect((result as SdkFailure<void>).kind, SdkErrorKind.validation);
      },
    );
  });

  group('AssetPreloadCoordinator: bounded concurrency', () {
    test('không bao giờ chạy quá maxConcurrent loader cùng lúc', () async {
      var inFlight = 0;
      var maxObserved = 0;
      final coordinator = _coordinator(
        maxConcurrent: 2,
        loader: (item) async {
          inFlight++;
          maxObserved = maxObserved < inFlight ? inFlight : maxObserved;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          inFlight--;
        },
      );

      await coordinator.preload(const [
        AssetManifestItem(id: 'a', kind: AssetKind.image, path: 'a.png'),
        AssetManifestItem(id: 'b', kind: AssetKind.image, path: 'b.png'),
        AssetManifestItem(id: 'c', kind: AssetKind.image, path: 'c.png'),
        AssetManifestItem(id: 'd', kind: AssetKind.image, path: 'd.png'),
      ]);

      expect(maxObserved, lessThanOrEqualTo(2));
    });
  });

  group('AssetPreloadCoordinator: progress', () {
    test(
      'progress tăng đơn điệu 0 → 1 khi mọi asset load thành công',
      () async {
        final coordinator = _coordinator(loader: (item) async {});
        final observed = <double>[];
        coordinator.progress.listen((v) => observed.add(v));

        await coordinator.preload(const [
          AssetManifestItem(
            id: 'a',
            kind: AssetKind.image,
            path: 'a.png',
            weight: 1,
          ),
          AssetManifestItem(
            id: 'b',
            kind: AssetKind.image,
            path: 'b.png',
            weight: 3,
          ),
        ]);

        expect(coordinator.progress.value, 1.0);
        for (var i = 1; i < observed.length; i++) {
          expect(observed[i], greaterThanOrEqualTo(observed[i - 1]));
        }
      },
    );

    test('progress không đạt 1.0 khi asset required fail', () async {
      final coordinator = _coordinator(
        loader: (item) async {
          if (item.id == 'required_fail') throw Exception('load lỗi');
        },
      );

      final result = await coordinator.preload(const [
        AssetManifestItem(id: 'ok', kind: AssetKind.image, path: 'ok.png'),
        AssetManifestItem(
          id: 'required_fail',
          kind: AssetKind.image,
          path: 'x.png',
        ),
      ]);

      expect(result, isA<SdkFailure<void>>());
      expect(coordinator.progress.value, lessThan(1.0));
    });

    test(
      'asset optional fail không chặn scene: kết quả success, progress vẫn đạt 1.0',
      () async {
        final coordinator = _coordinator(
          loader: (item) async {
            if (item.id == 'optional_fail') throw Exception('load lỗi');
          },
        );

        final result = await coordinator.preload(const [
          AssetManifestItem(id: 'ok', kind: AssetKind.image, path: 'ok.png'),
          AssetManifestItem(
            id: 'optional_fail',
            kind: AssetKind.image,
            path: 'x.png',
            required: false,
          ),
        ]);

        expect(result, isA<SdkSuccess<void>>());
        expect(coordinator.progress.value, 1.0);
      },
    );

    test(
      'item phụ thuộc vào asset required fail bị chặn, không gọi loader',
      () async {
        final calls = <String>[];
        final coordinator = _coordinator(
          loader: (item) async {
            calls.add(item.id);
            if (item.id == 'atlas') throw Exception('load lỗi');
          },
        );

        final result = await coordinator.preload(const [
          AssetManifestItem(
            id: 'atlas',
            kind: AssetKind.image,
            path: 'atlas.png',
          ),
          AssetManifestItem(
            id: 'player',
            kind: AssetKind.image,
            path: 'player.png',
            dependsOn: ['atlas'],
          ),
        ]);

        expect(result, isA<SdkFailure<void>>());
        expect(calls, ['atlas']); // player không bao giờ được gọi loader
      },
    );
  });

  group('AssetPreloadCoordinator: cancel', () {
    test(
      'cancel giữa chừng dừng việc khởi động wave mới, không throw/leak',
      () async {
        final calls = <String>[];
        late AssetPreloadCoordinator coordinator;
        coordinator = _coordinator(
          maxConcurrent: 1,
          loader: (item) async {
            calls.add(item.id);
            if (item.id == 'a') coordinator.cancel();
            await Future<void>.delayed(const Duration(milliseconds: 5));
          },
        );

        final result = await coordinator.preload(const [
          AssetManifestItem(id: 'a', kind: AssetKind.image, path: 'a.png'),
          AssetManifestItem(id: 'b', kind: AssetKind.image, path: 'b.png'),
        ]);

        expect(result, isA<SdkFailure<void>>());
        expect(calls, [
          'a',
        ]); // 'b' chưa từng chạy vì đã cancel trước khi tới wave sau
      },
    );
  });

  group('AssetPreloadCoordinator: retry', () {
    test(
      'retryFailed load lại asset đã fail, giữ nguyên cache asset đã ok',
      () async {
        final calls = <String>[];
        var shouldFail = true;
        final coordinator = _coordinator(
          loader: (item) async {
            calls.add(item.id);
            if (item.id == 'flaky' && shouldFail) throw Exception('load lỗi');
          },
        );

        final first = await coordinator.preload(const [
          AssetManifestItem(id: 'stable', kind: AssetKind.image, path: 'a.png'),
          AssetManifestItem(id: 'flaky', kind: AssetKind.image, path: 'b.png'),
        ]);
        expect(first, isA<SdkFailure<void>>());

        shouldFail = false;
        final second = await coordinator.retryFailed();

        expect(second, isA<SdkSuccess<void>>());
        expect(calls, ['stable', 'flaky', 'flaky']); // 'stable' không load lại
      },
    );
  });

  group('AssetPreloadCoordinator: unloadScene + ref-count', () {
    test('unloadScene gọi unloader khi refcount về 0', () async {
      final unloaded = <String>[];
      final coordinator = _coordinator(
        loader: (item) async {},
        unloader: (item) => unloaded.add(item.id),
      );

      await coordinator.preload(const [
        AssetManifestItem(id: 'a', kind: AssetKind.image, path: 'a.png'),
      ]);
      coordinator.unloadScene();

      expect(unloaded, ['a']);
      expect(coordinator.isLoaded('a'), isFalse);
    });

    test(
      'asset dùng chung 2 scene: unload 1 scene không unload asset còn scene kia dùng',
      () async {
        final unloaded = <String>[];
        final coordinator = _coordinator(
          loader: (item) async {},
          unloader: (item) => unloaded.add(item.id),
        );
        const sceneA = [
          AssetManifestItem(id: 'shared', kind: AssetKind.image, path: 'a.png'),
          AssetManifestItem(id: 'onlyA', kind: AssetKind.image, path: 'a2.png'),
        ];
        const sceneB = [
          AssetManifestItem(id: 'shared', kind: AssetKind.image, path: 'a.png'),
          AssetManifestItem(id: 'onlyB', kind: AssetKind.image, path: 'b2.png'),
        ];

        await coordinator.preload(sceneA);
        await coordinator.preload(sceneB);
        coordinator.unloadScene(); // unload theo manifest gần nhất (sceneB)

        expect(unloaded, ['onlyB']);
        expect(coordinator.isLoaded('shared'), isTrue);
      },
    );
  });
}
