import 'dart:async';

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

  group('BUG-49: maxConcurrent <= 0 bị chặn ngay tại constructor', () {
    test('maxConcurrent: 0 throw ArgumentError ngay, không treo preload', () {
      expect(
        () => AssetPreloadCoordinator(loader: (item) async {}, maxConcurrent: 0),
        throwsArgumentError,
      );
    });

    test('maxConcurrent: -1 cũng bị chặn tương tự', () {
      expect(
        () =>
            AssetPreloadCoordinator(loader: (item) async {}, maxConcurrent: -1),
        throwsArgumentError,
      );
    });

    test(
      'validate là if/throw thường, không phải assert() — không thể bị strip ở release build '
      '(không có cách chạy dart --no-enable-asserts cho package này vì `get` kéo theo dart:ui qua '
      'package:flutter, nên chứng minh bằng cấu trúc: check chạy vô điều kiện, không nằm trong assert())',
      () {
        // Nếu implementation dùng lại `assert(...)`, test này vẫn pass vì
        // flutter test luôn chạy với assert bật — giá trị thật của test này
        // là ở review code (xem ## Quyết định trong task file), test ở đây
        // chỉ giữ hành vi throw không bị đổi ngược lại trong tương lai.
        expect(
          () => AssetPreloadCoordinator(
            loader: (item) async {},
            maxConcurrent: 0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });

  group('BUG-49: sceneId tường minh — unload đúng scene, không nhầm', () {
    test(
      'preload scene A rồi scene B (overlap "shared") — unloadScene(A) chỉ unload phần riêng của A, '
      'giữ shared (B còn giữ ref); unloadScene(B) sau đó mới unload nốt shared',
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

        await coordinator.preload(sceneA, sceneId: 'A');
        await coordinator.preload(sceneB, sceneId: 'B');

        // B được preload sau A (nên là "scene gần nhất"), nhưng ta chủ
        // động unload A trước bằng sceneId tường minh — phải đúng A, không
        // rơi vào hành vi cũ "luôn unload scene gần nhất nhất".
        coordinator.unloadScene('A');
        expect(unloaded, ['onlyA']);
        expect(coordinator.isLoaded('shared'), isTrue);
        expect(coordinator.isLoaded('onlyB'), isTrue);

        coordinator.unloadScene('B');
        expect(unloaded, ['onlyA', 'shared', 'onlyB']);
      },
    );
  });

  group('BUG-49: retryFailed không double-count refcount', () {
    test(
      'retryFailed() lặp lại nhiều lần trên cùng 1 scene vẫn chỉ cần đúng 1 lần unloadScene() để giải phóng hết',
      () async {
        final unloaded = <String>[];
        var shouldFail = true;
        final coordinator = _coordinator(
          loader: (item) async {
            if (item.id == 'flaky' && shouldFail) throw Exception('load lỗi');
          },
          unloader: (item) => unloaded.add(item.id),
        );

        final first = await coordinator.preload(const [
          AssetManifestItem(id: 'stable', kind: AssetKind.image, path: 'a.png'),
          AssetManifestItem(id: 'flaky', kind: AssetKind.image, path: 'b.png'),
        ]);
        expect(first, isA<SdkFailure<void>>());

        // retry nhiều lần trong khi vẫn còn fail — mỗi lần đều re-process
        // 'stable' (đã load, cache hit) — không được cộng dồn refCount.
        await coordinator.retryFailed();
        await coordinator.retryFailed();

        shouldFail = false;
        final last = await coordinator.retryFailed();
        expect(last, isA<SdkSuccess<void>>());

        // Chỉ 1 lần unloadScene() phải giải phóng hết — nếu refCount bị
        // cộng dồn sai qua các lần retry, 'stable' sẽ còn refCount > 1 và
        // không xuất hiện trong unloaded sau lần gọi duy nhất này.
        coordinator.unloadScene();
        expect(unloaded..sort(), ['flaky', 'stable']);
      },
    );
  });

  group('ENH-88: progressOf — 2 scene preload thật sự chồng lấn (concurrent)', () {
    test(
      'preload(A) và preload(B) chạy đồng thời (KHÔNG await tuần tự) — '
      'progress chung bị B "làm giả" 100% dù A chưa xong; progressOf từng '
      'scene báo đúng độc lập',
      () async {
        final aGate = Completer<void>();
        final coordinator = _coordinator(
          loader: (item) async {
            if (item.id == 'a1') await aGate.future;
          },
        );

        // Fire cả 2 preload() KHÔNG await lần lượt — mô phỏng đúng use
        // case thật của task (preload scene B trong lúc scene A vẫn đang
        // active/preload dở) thay vì kiểu sequential-await của BUG-49's
        // test đã có.
        final futureA = coordinator.preload(const [
          AssetManifestItem(id: 'a1', kind: AssetKind.image, path: 'a1.png'),
        ], sceneId: 'A');
        final futureB = coordinator.preload(const [
          AssetManifestItem(id: 'b1', kind: AssetKind.image, path: 'b1.png'),
        ], sceneId: 'B');

        await futureB; // B không chờ gì cả trong loader — xong ngay.

        // Bug thật sự nếu chỉ dùng `progress` chung: B xong khiến field
        // dùng chung bị ghi đè thành 1.0, trông như "xong 100%" dù A vẫn
        // đang treo chờ aGate — không phải lỗi mới do ENH-88 gây ra, đây
        // là hành vi ĐÃ CÓ SẴN của field `progress`, giữ nguyên (đã ghi
        // rõ trong doc comment) để backward-compat single-scene.
        expect(coordinator.progress.value, 1.0);

        // progressOf() KHÔNG bị B đánh lừa — A thật sự vẫn 0%, B thật sự
        // đã 100%, độc lập hoàn toàn.
        expect(coordinator.progressOf('A').value, 0.0);
        expect(coordinator.progressOf('B').value, 1.0);

        aGate.complete();
        await futureA;

        expect(coordinator.progressOf('A').value, 1.0);
        expect(coordinator.progressOf('B').value, 1.0);
      },
    );

    test(
      'unloadScene đúng theo sceneId ngay cả khi 2 scene KHÔNG chung asset '
      'nào được preload CHỒNG LẤN THẬT SỰ (B bị treo tới khi A đã xong) — '
      'regression cho bug "unload nhầm scene" của BUG-49, verify dưới điều '
      'kiện concurrency thật thay vì sequential-await',
      () async {
        final unloaded = <String>[];
        final bGate = Completer<void>();
        final coordinator = _coordinator(
          loader: (item) async {
            if (item.id == 'b1') await bGate.future;
          },
          unloader: (item) => unloaded.add(item.id),
        );

        // Fire cả 2 KHÔNG await tuần tự — scene B thực sự vẫn còn treo dở
        // khi scene A đã hoàn tất hẳn (khác BUG-49's test cũ vốn await A
        // xong rồi mới bắt đầu B).
        final futureA = coordinator.preload(const [
          AssetManifestItem(id: 'a1', kind: AssetKind.image, path: 'a1.png'),
        ], sceneId: 'A');
        final futureB = coordinator.preload(const [
          AssetManifestItem(id: 'b1', kind: AssetKind.image, path: 'b1.png'),
        ], sceneId: 'B');
        await futureA;

        // Scene B vẫn đang treo (chưa gọi bGate.complete()) — unloadScene
        // theo đúng sceneId 'A' không được đụng tới bất kỳ trạng thái nào
        // của B đang preload dở.
        coordinator.unloadScene('A');
        expect(unloaded, ['a1']);
        expect(coordinator.isLoaded('b1'), isFalse);

        bGate.complete();
        await futureB;
        coordinator.unloadScene('B');
        expect(unloaded, ['a1', 'b1']);
      },
    );
  });
}
