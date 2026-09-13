import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/remote_config_service.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';

/// Fake [AssetBundle] backed by an in-memory map of asset path -> JSON
/// string content, so tests never touch a real bundled asset file.
class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle(this._assets);
  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final content = _assets[key];
    if (content == null) {
      throw Exception('Asset not found: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}

const _assetPath = 'assets/remote_config_fallback.json';

void main() {
  tearDown(Get.reset);

  test('maybe trả về null khi chưa đăng ký service', () {
    expect(RemoteConfigService.maybe, isNull);
  });

  test('maybe trả về đúng instance khi đã đăng ký', () {
    final service = RemoteConfigService(
      assetPath: _assetPath,
      bundle: _FakeAssetBundle({_assetPath: '{}'}),
    );
    Get.put<RemoteConfigService>(service, permanent: true);

    expect(RemoteConfigService.maybe, same(service));
  });

  test('không có fetchRemote → dùng giá trị từ asset fallback', () async {
    final service = RemoteConfigService(
      assetPath: _assetPath,
      bundle: _FakeAssetBundle({
        _assetPath: jsonEncode({
          'difficulty': 2,
          'iap_price': 4.99,
          'feature_x_enabled': true,
          'greeting': 'hello from asset',
        }),
      }),
    );

    await service.init();

    expect(service.getInt('difficulty'), 2);
    expect(service.getDouble('iap_price'), 4.99);
    expect(service.getBool('feature_x_enabled'), true);
    expect(service.getString('greeting'), 'hello from asset');
  });

  test(
    'fetchRemote thành công → giá trị network ghi đè asset fallback',
    () async {
      final service = RemoteConfigService(
        assetPath: _assetPath,
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({'difficulty': 2, 'greeting': 'from asset'}),
        }),
        fetchRemote: () async => {'difficulty': 5, 'greeting': 'from network'},
      );

      await service.init();

      expect(service.getInt('difficulty'), 5);
      expect(service.getString('greeting'), 'from network');
    },
  );

  test(
    'fetchRemote throw → im lặng giữ nguyên asset fallback, không crash',
    () async {
      final service = RemoteConfigService(
        assetPath: _assetPath,
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({'difficulty': 2, 'greeting': 'from asset'}),
        }),
        fetchRemote: () async => throw Exception('network down'),
      );

      await service.init();

      expect(service.getInt('difficulty'), 2);
      expect(service.getString('greeting'), 'from asset');
    },
  );

  test(
    'asset không load được và không có fetchRemote → getter trả fallback riêng, không crash',
    () async {
      final service = RemoteConfigService(
        assetPath: _assetPath,
        bundle: _FakeAssetBundle(const {}), // asset không tồn tại
      );

      await service.init();

      expect(service.getInt('difficulty', fallback: 1), 1);
      expect(service.getString('greeting', fallback: 'default'), 'default');
      expect(service.getBool('feature_x_enabled', fallback: false), false);
      expect(service.getDouble('iap_price', fallback: 0.99), 0.99);
    },
  );

  test('key không tồn tại trong config → trả về fallback của getter', () async {
    final service = RemoteConfigService(
      assetPath: _assetPath,
      bundle: _FakeAssetBundle({
        _assetPath: jsonEncode({'difficulty': 2}),
      }),
    );

    await service.init();

    expect(service.getString('missing_key', fallback: 'nope'), 'nope');
  });

  group(
    'ENH-58: partial merge (BUG thật — trước fix, response partial xoá hết key còn lại)',
    () {
      test(
        'fetchRemote CHỈ trả về 1 trong nhiều key → các key KHÔNG có trong response vẫn giữ nguyên asset fallback',
        () async {
          final service = RemoteConfigService(
            assetPath: _assetPath,
            bundle: _FakeAssetBundle({
              _assetPath: jsonEncode({
                'difficulty': 2,
                'iap_price': 4.99,
                'feature_x_enabled': true,
                'greeting': 'from asset',
              }),
            }),
            // Response CHỈ gửi 'difficulty' — trước fix, dòng
            // `_config = await fetch()` sẽ xoá sạch 3 key còn lại.
            fetchRemote: () async => {'difficulty': 5},
          );

          await service.init();

          expect(service.getInt('difficulty'), 5);
          expect(service.getDouble('iap_price'), 4.99);
          expect(service.getBool('feature_x_enabled'), true);
          expect(service.getString('greeting'), 'from asset');
        },
      );

      test(
        'fetchRemote trả về map RỖNG → toàn bộ asset fallback vẫn nguyên vẹn (không bị corrupt)',
        () async {
          final service = RemoteConfigService(
            assetPath: _assetPath,
            bundle: _FakeAssetBundle({
              _assetPath: jsonEncode({
                'difficulty': 2,
                'greeting': 'from asset',
              }),
            }),
            fetchRemote: () async => {},
          );

          await service.init();

          expect(service.getInt('difficulty'), 2);
          expect(service.getString('greeting'), 'from asset');
          expect(service.source, RemoteConfigSource.remoteMerged);
        },
      );

      test(
        'fetchRemote trả về null cho 1 key đã có asset default → coi như "không override", giữ nguyên giá trị asset',
        () async {
          final service = RemoteConfigService(
            assetPath: _assetPath,
            bundle: _FakeAssetBundle({
              _assetPath: jsonEncode({'greeting': 'from asset'}),
            }),
            fetchRemote: () async => {'greeting': null},
          );

          await service.init();

          expect(service.getString('greeting'), 'from asset');
        },
      );

      test(
        'fetchRemote gửi key SAI TYPE cho 1 field → getter tương ứng không crash, trả về fallback riêng của getter đó',
        () async {
          final service = RemoteConfigService(
            assetPath: _assetPath,
            bundle: _FakeAssetBundle({
              _assetPath: jsonEncode({'difficulty': 2}),
            }),
            // 'difficulty' đáng lẽ là int, remote gửi nhầm String.
            fetchRemote: () async => {'difficulty': 'oops'},
          );

          await service.init();

          expect(service.getInt('difficulty', fallback: 9), 9);
        },
      );

      test(
        'fetchRemote thêm key HOÀN TOÀN MỚI (không có trong asset) → vẫn merge vào bình thường',
        () async {
          final service = RemoteConfigService(
            assetPath: _assetPath,
            bundle: _FakeAssetBundle({
              _assetPath: jsonEncode({'difficulty': 2}),
            }),
            fetchRemote: () async => {'new_flag': true},
          );

          await service.init();

          expect(service.getInt('difficulty'), 2);
          expect(service.getBool('new_flag'), true);
        },
      );

      test(
        'gọi init() lần 2 → tự reload lại asset trước rồi mới merge remote mới (không cộng dồn merge của lần init() trước)',
        () async {
          var call = 0;
          final service = RemoteConfigService(
            assetPath: _assetPath,
            bundle: _FakeAssetBundle({
              _assetPath: jsonEncode({'a': 1, 'b': 2, 'c': 3}),
            }),
            fetchRemote: () async {
              call++;
              return call == 1 ? {'a': 10} : {'b': 20};
            },
          );

          await service.init();
          expect(service.getInt('a'), 10);
          expect(service.getInt('b'), 2);
          expect(service.getInt('c'), 3);

          // init() thứ 2 nạp lại asset (a trở về 1) rồi mới merge response
          // thứ 2 ('b': 20) — response lần 1 ('a': 10) không còn hiệu lực vì
          // mỗi lần init() là 1 vòng load-rồi-merge độc lập, không cộng dồn.
          await service.init();
          expect(service.getInt('a'), 1);
          expect(service.getInt('b'), 20);
          expect(service.getInt('c'), 3);
        },
      );
    },
  );

  group('ENH-58: snapshot + source', () {
    test('snapshot phản ánh đúng config đã merge, là bản đọc-only', () async {
      final service = RemoteConfigService(
        assetPath: _assetPath,
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({'difficulty': 2, 'greeting': 'from asset'}),
        }),
        fetchRemote: () async => {'difficulty': 5},
      );

      await service.init();

      expect(service.snapshot, {'difficulty': 5, 'greeting': 'from asset'});
      expect(
        () => service.snapshot['difficulty'] = 999,
        throwsUnsupportedError,
      );
      // Mutation attempt (dù bị chặn) không ảnh hưởng service thật.
      expect(service.getInt('difficulty'), 5);
    });

    test('source: assetOnly khi chưa có fetchRemote', () async {
      final service = RemoteConfigService(
        assetPath: _assetPath,
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({'a': 1}),
        }),
      );

      await service.init();

      expect(service.source, RemoteConfigSource.assetOnly);
    });

    test('source: remoteMerged khi fetchRemote thành công', () async {
      final service = RemoteConfigService(
        assetPath: _assetPath,
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({'a': 1}),
        }),
        fetchRemote: () async => {'a': 2},
      );

      await service.init();

      expect(service.source, RemoteConfigSource.remoteMerged);
    });

    test(
      'source: remoteFailed khi fetchRemote throw, snapshot vẫn là asset fallback',
      () async {
        final service = RemoteConfigService(
          assetPath: _assetPath,
          bundle: _FakeAssetBundle({
            _assetPath: jsonEncode({'a': 1}),
          }),
          fetchRemote: () async => throw Exception('down'),
        );

        await service.init();

        expect(service.source, RemoteConfigSource.remoteFailed);
        expect(service.snapshot, {'a': 1});
      },
    );
  });

  group('ENH-58: initResult() + retry', () {
    test('init thành công (asset-only) → initResult trả SdkSuccess', () async {
      final service = RemoteConfigService(
        assetPath: _assetPath,
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({'a': 1}),
        }),
      );

      final result = await service.initResult();

      expect(result, isA<SdkSuccess<void>>());
      expect(service.getInt('a'), 1);
    });

    test(
      'fetchRemote throw → initResult VẪN trả SdkSuccess (init() tự nuốt lỗi nội bộ, không rethrow ra initResult)',
      () async {
        final service = RemoteConfigService(
          assetPath: _assetPath,
          bundle: _FakeAssetBundle({
            _assetPath: jsonEncode({'a': 1}),
          }),
          fetchRemote: () async => throw Exception('down'),
        );

        final result = await service.initResult();

        expect(result, isA<SdkSuccess<void>>());
        expect(service.source, RemoteConfigSource.remoteFailed);
        expect(service.getInt('a'), 1);
      },
    );

    test(
      'retry: gọi lại init() sau khi fetchRemote lần đầu throw → lần 2 fetchRemote thành công thì merge đúng',
      () async {
        var call = 0;
        final service = RemoteConfigService(
          assetPath: _assetPath,
          bundle: _FakeAssetBundle({
            _assetPath: jsonEncode({'a': 1, 'b': 2}),
          }),
          fetchRemote: () async {
            call++;
            if (call == 1) throw Exception('down');
            return {'a': 99};
          },
        );

        await service.init();
        expect(service.source, RemoteConfigSource.remoteFailed);
        expect(service.getInt('a'), 1);

        // Caller retries per SdkFailure.retryable == true.
        await service.init();
        expect(service.source, RemoteConfigSource.remoteMerged);
        expect(service.getInt('a'), 99);
        expect(service.getInt('b'), 2);
      },
    );
  });
}
