import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/remote_content_pack.dart';
import 'package:roy_casual_kit/core/save_integrity.dart' show signExport;
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake [AssetBundle] backed by an in-memory map, same convention as
/// `test/core/remote_config_service_test.dart`.
class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle(this._assets);
  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final content = _assets[key];
    if (content == null) throw Exception('Asset not found: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}

const _assetPath = 'assets/level_pack_fallback.json';
const _secret = 'test-content-secret';

class _Level {
  _Level(this.id, this.name);
  final int id;
  final String name;

  static _Level fromJson(Map<String, Object?> json) =>
      _Level(json['id']! as int, json['name']! as String);
}

class _ThrowingCacheStorage extends StorageService {
  _ThrowingCacheStorage(super.prefs, this.targetKey);
  final String targetKey;

  @override
  Future<void> setString(String key, String value) {
    if (key == targetKey) throw StateError('cache write failed');
    return super.setString(key, value);
  }
}

_FakeAssetBundle _asset(String name) => _FakeAssetBundle({
  _assetPath: jsonEncode({'id': 1, 'name': name, 'schemaVersion': 1}),
});

void main() {
  test(
    'asset-only (không có fetchRemote) → load() trả nội dung từ asset',
    () async {
      final pack = RemoteContentPack<_Level>(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({
            'id': 1,
            'name': 'Asset Level',
            'schemaVersion': 1,
          }),
        }),
      );

      final level = await pack.load();

      expect(level, isNotNull);
      expect(level!.name, 'Asset Level');
      expect(pack.current!.name, 'Asset Level');
    },
  );

  test('asset thiếu/hỏng → load() trả null, không throw', () async {
    final pack = RemoteContentPack<_Level>(
      assetPath: _assetPath,
      schemaVersion: 1,
      fromJson: _Level.fromJson,
      bundle: _FakeAssetBundle({}),
    );

    final level = await pack.load();

    expect(level, isNull);
    expect(pack.current, isNull);
  });

  test(
    'fetchRemote thành công với chữ ký hợp lệ → áp dụng nội dung mới sau khi load() resolve',
    () async {
      final signed = signExport({
        'id': 2,
        'name': 'Remote Level',
        'schemaVersion': 1,
      }, _secret);
      final pack = RemoteContentPack<_Level>(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        contentSecret: _secret,
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({
            'id': 1,
            'name': 'Asset Level',
            'schemaVersion': 1,
          }),
        }),
        fetchRemote: () async => signed,
      );

      await pack.load();
      expect(pack.current!.name, 'Asset Level');

      await pack.refreshed;

      expect(pack.current!.name, 'Remote Level');
    },
  );

  test(
    'fetchRemote trả chữ ký sai → fallback về asset, không áp dụng, không throw',
    () async {
      final tampered = {
        'id': 999,
        'name': 'Malicious Level',
        'schemaVersion': 1,
        '_checksum': 'not-a-real-checksum',
      };
      final pack = RemoteContentPack<_Level>(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        contentSecret: _secret,
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({
            'id': 1,
            'name': 'Asset Level',
            'schemaVersion': 1,
          }),
        }),
        fetchRemote: () async => tampered,
      );

      await pack.load();
      await pack.refreshed;

      expect(pack.current!.name, 'Asset Level');
    },
  );

  test(
    'fetchRemote trả schemaVersion mới hơn (từ tương lai) → fallback về asset, không throw',
    () async {
      final fromFuture = signExport({
        'id': 3,
        'name': 'Future Level',
        'schemaVersion': 99,
      }, _secret);
      final pack = RemoteContentPack<_Level>(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        contentSecret: _secret,
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({
            'id': 1,
            'name': 'Asset Level',
            'schemaVersion': 1,
          }),
        }),
        fetchRemote: () async => fromFuture,
      );

      await pack.load();
      await pack.refreshed;

      expect(pack.current!.name, 'Asset Level');
    },
  );

  test(
    'fetchRemote schema cũ hơn → chạy qua migrate() trước khi fromJson',
    () async {
      final oldShape = signExport({
        'id': 4,
        'label': 'Legacy Level',
        'schemaVersion': 0,
      }, _secret);
      final pack = RemoteContentPack<_Level>(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        contentSecret: _secret,
        migrate: (fromVersion, json) => {
          ...json,
          'name': json['label'],
          'schemaVersion': 1,
        },
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({
            'id': 1,
            'name': 'Asset Level',
            'schemaVersion': 1,
          }),
        }),
        fetchRemote: () async => oldShape,
      );

      await pack.load();
      await pack.refreshed;

      expect(pack.current!.name, 'Legacy Level');
    },
  );

  test(
    'không có contentSecret nhưng fetchRemote trả envelope có _checksum → fallback về asset (không tin nội dung chưa cấu hình xác thực)',
    () async {
      final signed = signExport({
        'id': 5,
        'name': 'Unverifiable Level',
        'schemaVersion': 1,
      }, _secret);
      final pack = RemoteContentPack<_Level>(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({
            'id': 1,
            'name': 'Asset Level',
            'schemaVersion': 1,
          }),
        }),
        fetchRemote: () async => signed,
      );

      await pack.load();
      await pack.refreshed;

      expect(pack.current!.name, 'Asset Level');
    },
  );

  test(
    'fetchRemote throw (mất mạng) → giữ nguyên nội dung hiện tại, không crash',
    () async {
      final pack = RemoteContentPack<_Level>(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({
            'id': 1,
            'name': 'Asset Level',
            'schemaVersion': 1,
          }),
        }),
        fetchRemote: () async => throw Exception('network down'),
      );

      await pack.load();
      await pack.refreshed;

      expect(pack.current!.name, 'Asset Level');
    },
  );

  test(
    'fromJson ném lỗi trên nội dung remote hợp lệ chữ ký nhưng sai kiểu field → fallback về asset',
    () async {
      final badShape = signExport({
        'id': 'not-an-int',
        'schemaVersion': 1,
      }, _secret);
      final pack = RemoteContentPack<_Level>(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        contentSecret: _secret,
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({
            'id': 1,
            'name': 'Asset Level',
            'schemaVersion': 1,
          }),
        }),
        fetchRemote: () async => badShape,
      );

      await pack.load();
      await pack.refreshed;

      expect(pack.current!.name, 'Asset Level');
    },
  );

  test(
    'load() không throw khi cả asset lẫn fetchRemote đều không có gì dùng được',
    () async {
      final pack = RemoteContentPack<_Level>(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        bundle: _FakeAssetBundle({}),
        fetchRemote: () async => throw Exception('network down'),
      );

      final level = await pack.load();
      await pack.refreshed;

      expect(level, isNull);
      expect(pack.current, isNull);
    },
  );

  group(
    'BUG-37: schemaVersion vắng mặt — default phải khớp VersionedJsonStore (0, không phải "current")',
    () {
      test(
        'asset thiếu schemaVersion, pack có schemaVersion > 0 VÀ có migrate: chạy qua migrate(0, json) đúng',
        () async {
          var migrateCalledWithVersion = -1;
          final pack = RemoteContentPack<_Level>(
            assetPath: _assetPath,
            schemaVersion: 1,
            fromJson: _Level.fromJson,
            migrate: (fromVersion, json) {
              migrateCalledWithVersion = fromVersion;
              return {...json, 'schemaVersion': 1};
            },
            bundle: _FakeAssetBundle({
              // Không có 'schemaVersion' — mô phỏng asset author quên thêm field.
              _assetPath: jsonEncode({'id': 9, 'name': 'No Version Level'}),
            }),
          );

          final level = await pack.load();

          expect(migrateCalledWithVersion, 0);
          expect(level!.name, 'No Version Level');
        },
      );

      test(
        'asset thiếu schemaVersion, pack có schemaVersion > 0 NHƯNG không có migrate: bị từ chối an toàn, không throw',
        () async {
          final pack = RemoteContentPack<_Level>(
            assetPath: _assetPath,
            schemaVersion: 1,
            fromJson: _Level.fromJson,
            bundle: _FakeAssetBundle({
              _assetPath: jsonEncode({'id': 9, 'name': 'No Version Level'}),
            }),
          );

          final level = await pack.load();

          expect(level, isNull);
          expect(pack.current, isNull);
        },
      );

      test(
        'asset thiếu schemaVersion, pack có schemaVersion == 0 (mặc định): vẫn được chấp nhận bình thường',
        () async {
          final pack = RemoteContentPack<_Level>(
            assetPath: _assetPath,
            schemaVersion: 0,
            fromJson: _Level.fromJson,
            bundle: _FakeAssetBundle({
              _assetPath: jsonEncode({'id': 9, 'name': 'No Version Level'}),
            }),
          );

          final level = await pack.load();

          expect(level!.name, 'No Version Level');
        },
      );

      test(
        'fetchRemote thiếu schemaVersion, có migrate: chạy qua migrate(0, json) đúng (network path, giống asset path)',
        () async {
          final envelope = signExport({
            'id': 10,
            'label': 'Legacy Remote Level',
          }, _secret);
          var migrateCalledWithVersion = -1;
          final pack = RemoteContentPack<_Level>(
            assetPath: _assetPath,
            schemaVersion: 1,
            fromJson: _Level.fromJson,
            contentSecret: _secret,
            migrate: (fromVersion, json) {
              migrateCalledWithVersion = fromVersion;
              return {...json, 'name': json['label'], 'schemaVersion': 1};
            },
            bundle: _FakeAssetBundle({
              _assetPath: jsonEncode({
                'id': 1,
                'name': 'Asset Level',
                'schemaVersion': 1,
              }),
            }),
            fetchRemote: () async => envelope,
          );

          await pack.load();
          await pack.refreshed;

          expect(migrateCalledWithVersion, 0);
          expect(pack.current!.name, 'Legacy Remote Level');
        },
      );

      test(
        'fetchRemote thiếu schemaVersion, không có migrate: bị từ chối an toàn, giữ nguyên nội dung asset cũ',
        () async {
          final envelope = signExport({
            'id': 10,
            'name': 'Legacy Remote Level',
          }, _secret);
          final pack = RemoteContentPack<_Level>(
            assetPath: _assetPath,
            schemaVersion: 1,
            fromJson: _Level.fromJson,
            contentSecret: _secret,
            bundle: _FakeAssetBundle({
              _assetPath: jsonEncode({
                'id': 1,
                'name': 'Asset Level',
                'schemaVersion': 1,
              }),
            }),
            fetchRemote: () async => envelope,
          );

          await pack.load();
          await pack.refreshed;

          expect(
            pack.current!.name,
            'Asset Level',
          ); // giữ nguyên, không nhận nội dung thiếu version
        },
      );
    },
  );

  group('ENH-94: durable verified cache', () {
    late StorageService storage;
    const cacheKey = 'test_remote_content_cache';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService(await SharedPreferences.getInstance());
    });

    Future<void> seedVerifiedCache(String name) async {
      final pack = RemoteContentPack<_Level>.withCache(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        contentSecret: _secret,
        storage: storage,
        cacheKey: cacheKey,
        bundle: _asset('Old Asset'),
        fetchRemote: () async =>
            signExport({'id': 2, 'name': name, 'schemaVersion': 1}, _secret),
      );
      await pack.load();
      await pack.refreshed;
      expect(pack.current!.name, name);
    }

    test('verified fetch -> ghi cache -> instance MỚI đọc cache đúng, cache '
        'thắng asset cũ', () async {
      await seedVerifiedCache('Verified Remote');

      final restarted = RemoteContentPack<_Level>.withCache(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        storage: storage,
        cacheKey: cacheKey,
        bundle: _asset('Different Asset'),
      );

      final level = await restarted.load();

      expect(level!.name, 'Verified Remote');
      expect(restarted.current!.name, 'Verified Remote');
    });

    test('tampered envelope sau cache hợp lệ -> cache cũ giữ nguyên, không bị '
        'ghi đè', () async {
      await seedVerifiedCache('Last Known Good');
      final tamperedRefresh = RemoteContentPack<_Level>.withCache(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        contentSecret: _secret,
        storage: storage,
        cacheKey: cacheKey,
        bundle: _asset('Asset'),
        fetchRemote: () async => {
          'id': 999,
          'name': 'Tampered',
          'schemaVersion': 1,
          '_checksum': 'wrong',
        },
      );
      await tamperedRefresh.load();
      await tamperedRefresh.refreshed;

      final restarted = RemoteContentPack<_Level>.withCache(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        storage: storage,
        cacheKey: cacheKey,
        bundle: _asset('Asset'),
      );
      final level = await restarted.load();

      expect(level!.name, 'Last Known Good');
    });

    test('restart offline (fetch throw) -> dùng cache verified gần nhất, không '
        'rơi về asset cũ hơn', () async {
      await seedVerifiedCache('Cached While Online');
      final offline = RemoteContentPack<_Level>.withCache(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        contentSecret: _secret,
        storage: storage,
        cacheKey: cacheKey,
        bundle: _asset('Old Asset'),
        fetchRemote: () async => throw Exception('offline'),
      );

      final level = await offline.load();
      await offline.refreshed;

      expect(level!.name, 'Cached While Online');
      expect(offline.current!.name, 'Cached While Online');
    });

    test('cache schema tương lai -> reject cache, fallback asset', () async {
      await storage.setString(
        cacheKey,
        jsonEncode({
          'id': 8,
          'name': 'Future Cache',
          'schemaVersion': 99,
          'cachedAtMs': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      final pack = RemoteContentPack<_Level>.withCache(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        storage: storage,
        cacheKey: cacheKey,
        bundle: _asset('Safe Asset'),
      );

      final level = await pack.load();

      expect(level!.name, 'Safe Asset');
    });

    test('cache wrong-typed (fromJson throw) -> fallback asset', () async {
      await storage.setString(
        cacheKey,
        jsonEncode({
          'id': 'not-an-int',
          'name': 'Broken Cache',
          'schemaVersion': 1,
          'cachedAtMs': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      final pack = RemoteContentPack<_Level>.withCache(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        storage: storage,
        cacheKey: cacheKey,
        bundle: _asset('Safe Asset'),
      );

      final level = await pack.load();

      expect(level!.name, 'Safe Asset');
    });

    test('maxCacheAge hết hạn -> fallback asset', () async {
      await storage.setString(
        cacheKey,
        jsonEncode({
          'id': 2,
          'name': 'Expired Cache',
          'schemaVersion': 1,
          'cachedAtMs': 1,
        }),
      );
      final pack = RemoteContentPack<_Level>.withCache(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        storage: storage,
        cacheKey: cacheKey,
        maxCacheAge: const Duration(seconds: 1),
        bundle: _asset('Fresh Asset'),
      );

      final level = await pack.load();

      expect(level!.name, 'Fresh Asset');
    });

    test('maxCacheAge null -> cache không hết hạn theo tuổi', () async {
      await storage.setString(
        cacheKey,
        jsonEncode({
          'id': 2,
          'name': 'Ancient But Valid Cache',
          'schemaVersion': 1,
          'cachedAtMs': 1,
        }),
      );
      final pack = RemoteContentPack<_Level>.withCache(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        storage: storage,
        cacheKey: cacheKey,
        bundle: _asset('Asset'),
      );

      final level = await pack.load();

      expect(level!.name, 'Ancient But Valid Cache');
    });

    test('withCache cacheKey rỗng -> ArgumentError tại constructor', () {
      expect(
        () => RemoteContentPack<_Level>.withCache(
          assetPath: _assetPath,
          schemaVersion: 1,
          fromJson: _Level.fromJson,
          storage: storage,
          cacheKey: '',
          bundle: _asset('Asset'),
        ),
        throwsArgumentError,
      );
    });

    test(
      'cache write throw -> atomic swap: giữ current asset cũ, không áp dụng '
      'remote chỉ tồn tại trong RAM',
      () async {
        final throwing = _ThrowingCacheStorage(
          await SharedPreferences.getInstance(),
          cacheKey,
        );
        final pack = RemoteContentPack<_Level>.withCache(
          assetPath: _assetPath,
          schemaVersion: 1,
          fromJson: _Level.fromJson,
          contentSecret: _secret,
          storage: throwing,
          cacheKey: cacheKey,
          bundle: _asset('Asset Before Failed Write'),
          fetchRemote: () async => signExport({
            'id': 2,
            'name': 'Remote That Cannot Persist',
            'schemaVersion': 1,
          }, _secret),
        );

        await pack.load();
        await pack.refreshed;

        expect(pack.current!.name, 'Asset Before Failed Write');
      },
    );
  });

  group('ENH-96: verified content history + rollback', () {
    late StorageService storage;
    const cacheKey = 'test_history_cache';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService(await SharedPreferences.getInstance());
    });

    Map<String, Object?> envelopeFor(
      int id,
      String name, {
      int contentVersion = 1,
    }) => signExport({
      'id': id,
      'name': name,
      'schemaVersion': 1,
      'contentVersion': contentVersion,
    }, _secret);

    RemoteContentPack<_Level> packWithHistory({
      required StorageService useStorage,
      Future<Map<String, Object?>> Function()? fetchRemote,
      int historyCapacity = 3,
    }) => RemoteContentPack<_Level>.withHistory(
      assetPath: _assetPath,
      schemaVersion: 1,
      fromJson: _Level.fromJson,
      contentSecret: _secret,
      storage: useStorage,
      cacheKey: cacheKey,
      historyCapacity: historyCapacity,
      bundle: _asset('Asset'),
      fetchRemote: fetchRemote,
    );

    test('historyCapacity <= 0 -> ArgumentError tại constructor', () {
      expect(
        () => packWithHistory(useStorage: storage, historyCapacity: 0),
        throwsArgumentError,
      );
    });

    test('mỗi fetch verified thành công được thêm vào history, capped FIFO '
        'theo historyCapacity', () async {
      var version = 1;
      final pack = packWithHistory(
        useStorage: storage,
        fetchRemote: () async =>
            envelopeFor(version, 'v$version', contentVersion: version++),
        historyCapacity: 2,
      );

      for (var i = 0; i < 4; i++) {
        await pack.load();
        await pack.refreshed;
      }

      expect(pack.history, hasLength(2));
      expect(pack.history.map((e) => e.contentVersion), [3, 4]);
      expect(pack.currentContentVersion, 4);
    });

    test('history persist qua restart (instance mới đọc lại đúng history + '
        'current)', () async {
      final seed = packWithHistory(
        useStorage: storage,
        fetchRemote: () async => envelopeFor(1, 'Seeded', contentVersion: 5),
      );
      await seed.load();
      await seed.refreshed;

      final restarted = packWithHistory(useStorage: storage);
      await restarted.load();

      expect(restarted.currentContentVersion, 5);
      expect(restarted.history, hasLength(1));
      expect(restarted.history.single.contentVersion, 5);
    });

    test('downgrade: fetch trả contentVersion nhỏ hơn current bị từ chối, '
        'current/history không đổi', () async {
      final pack = packWithHistory(
        useStorage: storage,
        fetchRemote: () async => envelopeFor(1, 'v10', contentVersion: 10),
      );
      await pack.load();
      await pack.refreshed;
      expect(pack.currentContentVersion, 10);

      final downgraded = RemoteContentPack<_Level>.withHistory(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        contentSecret: _secret,
        storage: storage,
        cacheKey: cacheKey,
        historyCapacity: 3,
        bundle: _asset('Asset'),
        fetchRemote: () async => envelopeFor(1, 'v3', contentVersion: 3),
      );
      await downgraded.load();
      await downgraded.refreshed;

      expect(downgraded.currentContentVersion, 10);
      expect(downgraded.history, hasLength(1));
    });

    test('tamper: chữ ký sai không áp dụng, không thêm vào history, current '
        'giữ nguyên', () async {
      final pack = packWithHistory(
        useStorage: storage,
        fetchRemote: () async => envelopeFor(1, 'Good', contentVersion: 1),
      );
      await pack.load();
      await pack.refreshed;
      expect(pack.history, hasLength(1));

      final tampered = RemoteContentPack<_Level>.withHistory(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        contentSecret: _secret,
        storage: storage,
        cacheKey: cacheKey,
        historyCapacity: 3,
        bundle: _asset('Asset'),
        fetchRemote: () async => {
          'id': 2,
          'name': 'Tampered',
          'schemaVersion': 1,
          'contentVersion': 2,
          '_checksum': 'wrong',
        },
      );
      await tampered.load();
      await tampered.refreshed;

      expect(tampered.currentContentVersion, 1);
      expect(tampered.history, hasLength(1));
    });

    test('rollbackToChecksum: khôi phục đúng bản cũ trong history, cập nhật '
        'current + cache, persist qua restart', () async {
      final pack = packWithHistory(
        useStorage: storage,
        fetchRemote: () async => envelopeFor(1, 'V1', contentVersion: 1),
      );
      await pack.load();
      await pack.refreshed;
      final v1Checksum = pack.currentChecksum!;

      final toV2 = RemoteContentPack<_Level>.withHistory(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        contentSecret: _secret,
        storage: storage,
        cacheKey: cacheKey,
        historyCapacity: 3,
        bundle: _asset('Asset'),
        fetchRemote: () async => envelopeFor(2, 'V2', contentVersion: 2),
      );
      await toV2.load();
      await toV2.refreshed;
      expect(toV2.current!.name, 'V2');

      final result = await toV2.rollbackToChecksum(v1Checksum);
      expect(result.isSuccess, isTrue);
      expect(toV2.current!.name, 'V1');
      expect(toV2.currentContentVersion, 1);

      final restarted = packWithHistory(useStorage: storage);
      await restarted.load();
      expect(restarted.current!.name, 'V1');
    });

    test('rollbackToVersion: chọn bản applied mới nhất nếu trùng version, trả '
        'SdkFailure khi version không tồn tại', () async {
      final pack = packWithHistory(
        useStorage: storage,
        fetchRemote: () async => envelopeFor(1, 'V1', contentVersion: 1),
      );
      await pack.load();
      await pack.refreshed;

      final toV2 = RemoteContentPack<_Level>.withHistory(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        contentSecret: _secret,
        storage: storage,
        cacheKey: cacheKey,
        historyCapacity: 3,
        bundle: _asset('Asset'),
        fetchRemote: () async => envelopeFor(2, 'V2', contentVersion: 2),
      );
      await toV2.load();
      await toV2.refreshed;

      final missing = await toV2.rollbackToVersion(999);
      expect(missing.isSuccess, isFalse);
      expect(toV2.current!.name, 'V2');

      final rolledBack = await toV2.rollbackToVersion(1);
      expect(rolledBack.isSuccess, isTrue);
      expect(toV2.current!.name, 'V1');
    });

    test('diagnosticsSummary chỉ chứa metadata (schemaVersion/contentVersion/'
        'checksum/appliedAtMs), tuyệt đối không có content body/PII', () async {
      final pack = packWithHistory(
        useStorage: storage,
        fetchRemote: () async =>
            envelopeFor(1, 'Secret Player Name', contentVersion: 1),
      );
      await pack.load();
      await pack.refreshed;

      final summary = pack.diagnosticsSummary();
      final encoded = jsonEncode(summary);

      expect(summary['schemaVersion'], 1);
      expect(summary['contentVersion'], 1);
      expect(summary['checksum'], isNotNull);
      expect(summary['appliedAtMs'], isNotNull);
      expect(encoded, isNot(contains('Secret Player Name')));
      expect(encoded, isNot(contains('"name"')));
      expect(encoded, isNot(contains('"id"')));
    });

    test('contentVersionResolver tuỳ chỉnh được ưu tiên hơn mặc định '
        '(contentVersion -> version -> 0)', () async {
      final signedWithVersionField = signExport({
        'id': 1,
        'name': 'Legacy Shape',
        'schemaVersion': 1,
        'version': 7,
      }, _secret);
      final pack = RemoteContentPack<_Level>.withHistory(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        contentSecret: _secret,
        storage: storage,
        cacheKey: cacheKey,
        historyCapacity: 3,
        bundle: _asset('Asset'),
        fetchRemote: () async => signedWithVersionField,
      );

      await pack.load();
      await pack.refreshed;

      expect(pack.currentContentVersion, 7);
    });
  });
}
