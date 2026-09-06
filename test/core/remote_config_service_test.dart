import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/remote_config_service.dart';

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

  test(
    'không có fetchRemote → dùng giá trị từ asset fallback',
    () async {
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
    },
  );

  test(
    'fetchRemote thành công → giá trị network ghi đè asset fallback',
    () async {
      final service = RemoteConfigService(
        assetPath: _assetPath,
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({'difficulty': 2, 'greeting': 'from asset'}),
        }),
        fetchRemote: () async => {
          'difficulty': 5,
          'greeting': 'from network',
        },
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
}
