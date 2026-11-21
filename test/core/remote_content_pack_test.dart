import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/remote_content_pack.dart';
import 'package:roy_casual_kit/core/save_integrity.dart' show signExport;
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/sdk_result.dart';
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

class _SequencedAssetBundle extends AssetBundle {
  _SequencedAssetBundle(this._first, this._later);
  final Future<ByteData> _first;
  final ByteData _later;
  var _calls = 0;

  @override
  Future<ByteData> load(String key) =>
      _calls++ == 0 ? _first : Future.value(_later);
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
    if (key == targetKey) throw StateError('write failed');
    return super.setString(key, value);
  }
}

class _ThrowingOnceStorage extends StorageService {
  _ThrowingOnceStorage(super.prefs, this.targetKey);
  final String targetKey;
  bool _thrown = false;

  @override
  Future<void> setString(String key, String value) {
    if (!_thrown && key == targetKey) {
      _thrown = true;
      throw StateError('write failed');
    }
    return super.setString(key, value);
  }
}

class _DelayedWriteStorage extends StorageService {
  _DelayedWriteStorage(super.prefs, this.targetKey);
  final String targetKey;
  final writeStarted = Completer<void>();
  final allowWrite = Completer<void>();

  final writes = <String>[];

  @override
  Future<void> setString(String key, String value) async {
    if (key == targetKey) {
      writes.add(value);
      if (!writeStarted.isCompleted) writeStarted.complete();
      if (writes.length == 1) await allowWrite.future;
    }
    await super.setString(key, value);
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

    test('BUG-113: cache ghi ở schema cũ được migrate khi app nâng schema, '
        'không bị bỏ qua', () async {
      // Cache written by an older app version (schema 1, old field name).
      await storage.setString(
        cacheKey,
        jsonEncode({
          'id': 2,
          'title': 'Cached Remote',
          'schemaVersion': 1,
          'cachedAtMs': 1,
        }),
      );
      var migrateCalls = 0;
      final upgraded = RemoteContentPack<_Level>.withCache(
        assetPath: _assetPath,
        schemaVersion: 2,
        fromJson: _Level.fromJson,
        migrate: (from, json) {
          migrateCalls++;
          return {...json, 'name': json['title']};
        },
        storage: storage,
        cacheKey: cacheKey,
        bundle: _asset('Bundled Asset v2'),
      );

      final level = await upgraded.load();

      expect(migrateCalls, 1);
      expect(level!.name, 'Cached Remote');
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

    String historyRecordKey(String key) => '${key}_history_v1';
    String combinedRecordKey(String key) => '${key}_record_v2';

    Map<String, Object?> legacyCache(String name, int id) => {
      'id': id,
      'name': name,
      'schemaVersion': 1,
      'cachedAtMs': 1,
    };

    Map<String, Object?> legacyHistory(String name, int id, int version) => {
      'schemaVersion': 1,
      'contentVersion': version,
      'checksum': 'legacy-$version',
      'appliedAtMs': version,
      'json': {'id': id, 'name': name, 'schemaVersion': 1},
    };

    test(
      'migrate legacy cache/history vào một record authoritative, giữ key cũ',
      () async {
        await storage.setString(
          cacheKey,
          jsonEncode(legacyCache('Current cached V2', 2)),
        );
        await storage.setString(
          historyRecordKey(cacheKey),
          jsonEncode([
            legacyHistory('V1', 1, 1),
            legacyHistory('Current cached V2', 2, 2),
          ]),
        );

        final pack = packWithHistory(useStorage: storage);
        await pack.load();

        expect(pack.current!.name, 'Current cached V2');
        expect(pack.currentContentVersion, 2);
        expect(pack.history.map((entry) => entry.contentVersion), [1, 2]);
        expect(storage.getString(combinedRecordKey(cacheKey)), isNotNull);
        expect(storage.getString(cacheKey), isNotNull);
        expect(storage.getString(historyRecordKey(cacheKey)), isNotNull);
      },
    );

    test(
      'legacy cache without history is rejected because its signature was not retained',
      () async {
        await storage.setString(
          cacheKey,
          jsonEncode(legacyCache('Newest cache', 3)),
        );
        await storage.setString(historyRecordKey(cacheKey), jsonEncode([]));

        final pack = packWithHistory(useStorage: storage);
        await pack.load();

        expect(pack.current!.name, 'Asset');
        expect(pack.history, isEmpty);
        expect(storage.getString(combinedRecordKey(cacheKey)), isNotNull);
      },
    );

    test(
      'migration write failure retries from untouched legacy keys',
      () async {
        await storage.setString(
          cacheKey,
          jsonEncode(legacyCache('Legacy cached', 2)),
        );
        await storage.setString(
          historyRecordKey(cacheKey),
          jsonEncode([legacyHistory('Legacy cached', 2, 2)]),
        );
        final failing = _ThrowingOnceStorage(
          await SharedPreferences.getInstance(),
          combinedRecordKey(cacheKey),
        );

        final first = packWithHistory(useStorage: failing);
        await first.load();
        expect(first.current!.name, 'Legacy cached');
        expect(failing.getString(combinedRecordKey(cacheKey)), isNull);
        expect(failing.getString(cacheKey), isNotNull);
        expect(failing.getString(historyRecordKey(cacheKey)), isNotNull);

        final retry = packWithHistory(useStorage: failing);
        await retry.load();
        expect(retry.current!.name, 'Legacy cached');
        expect(retry.history.single.contentVersion, 2);
        expect(failing.getString(combinedRecordKey(cacheKey)), isNotNull);
      },
    );

    test(
      'combined-record write failure leaves current and history unchanged',
      () async {
        final pack = packWithHistory(
          useStorage: storage,
          fetchRemote: () async => envelopeFor(1, 'V1', contentVersion: 1),
        );
        await pack.load();
        await pack.refreshed;
        final beforeCurrent = pack.current!.name;
        final beforeHistory = pack.history
            .map((entry) => entry.contentVersion)
            .toList();
        final beforeRecord = storage.getString(combinedRecordKey(cacheKey));

        final failing = RemoteContentPack<_Level>.withHistory(
          assetPath: _assetPath,
          schemaVersion: 1,
          fromJson: _Level.fromJson,
          contentSecret: _secret,
          storage: _ThrowingCacheStorage(
            await SharedPreferences.getInstance(),
            combinedRecordKey(cacheKey),
          ),
          cacheKey: cacheKey,
          historyCapacity: 3,
          bundle: _asset('Asset'),
          fetchRemote: () async => envelopeFor(2, 'V2', contentVersion: 2),
        );
        await failing.load();
        await failing.refreshed;
        expect(failing.current!.name, beforeCurrent);
        expect(
          failing.history.map((entry) => entry.contentVersion),
          beforeHistory,
        );
        expect(storage.getString(combinedRecordKey(cacheKey)), beforeRecord);

        final result = await failing.rollbackToChecksum(
          failing.currentChecksum!,
        );
        expect(result, isA<SdkFailure<_Level>>());
        expect(failing.current!.name, beforeCurrent);
        expect(
          failing.history.map((entry) => entry.contentVersion),
          beforeHistory,
        );
        expect(storage.getString(combinedRecordKey(cacheKey)), beforeRecord);
      },
    );

    test(
      'withCache stays on legacy cache key and does not consume history record',
      () async {
        await storage.setString(
          combinedRecordKey(cacheKey),
          jsonEncode({
            'formatVersion': 2,
            'cache': legacyCache('New record', 9),
            'history': [],
          }),
        );
        await storage.setString(
          cacheKey,
          jsonEncode(legacyCache('withCache legacy', 4)),
        );

        final pack = RemoteContentPack<_Level>.withCache(
          assetPath: _assetPath,
          schemaVersion: 1,
          fromJson: _Level.fromJson,
          storage: storage,
          cacheKey: cacheKey,
          bundle: _asset('Asset'),
        );
        await pack.load();

        expect(pack.current!.name, 'withCache legacy');
      },
    );

    test('cacheKey rỗng -> ArgumentError tại constructor', () {
      expect(
        () => RemoteContentPack<_Level>.withHistory(
          assetPath: _assetPath,
          schemaVersion: 1,
          fromJson: _Level.fromJson,
          contentSecret: _secret,
          storage: storage,
          cacheKey: '',
          historyCapacity: 3,
          bundle: _asset('Asset'),
        ),
        throwsArgumentError,
      );
    });

    test('rollbackToChecksum: checksum không có trong history -> SdkFailure, '
        'current và history không đổi', () async {
      final pack = packWithHistory(
        useStorage: storage,
        fetchRemote: () async => envelopeFor(1, 'V1', contentVersion: 1),
      );
      await pack.load();
      await pack.refreshed;

      final result = await pack.rollbackToChecksum('khong-ton-tai');

      expect(result, isA<SdkFailure<_Level>>());
      expect((result as SdkFailure<_Level>).kind, SdkErrorKind.validation);
      expect(pack.current!.name, 'V1');
      expect(pack.history, hasLength(1));
    });

    test(
      'rollback: ghi cache lỗi -> SdkFailure(storage), current giữ nguyên',
      () async {
        final seed = packWithHistory(
          useStorage: storage,
          fetchRemote: () async => envelopeFor(1, 'V1', contentVersion: 1),
        );
        await seed.load();
        await seed.refreshed;
        final v1Checksum = seed.currentChecksum!;

        final failing = RemoteContentPack<_Level>.withHistory(
          assetPath: _assetPath,
          schemaVersion: 1,
          fromJson: _Level.fromJson,
          contentSecret: _secret,
          storage: _ThrowingCacheStorage(
            await SharedPreferences.getInstance(),
            combinedRecordKey(cacheKey),
          ),
          cacheKey: cacheKey,
          historyCapacity: 3,
          bundle: _asset('Asset'),
          fetchRemote: () async => envelopeFor(2, 'V2', contentVersion: 2),
        );
        await failing.load();
        await failing.refreshed;
        final before = failing.current!.name;

        final result = await failing.rollbackToChecksum(v1Checksum);

        expect(result, isA<SdkFailure<_Level>>());
        final failure = result as SdkFailure<_Level>;
        expect(failure.kind, SdkErrorKind.storage);
        expect(failure.cause, isA<StateError>());
        expect(failure.stackTrace, isNotNull);
        expect(failing.current!.name, before);
      },
    );

    test(
      'BUG-137: latest load invocation wins for overlapping fetches',
      () async {
        final older = Completer<Map<String, Object?>>();
        final newer = Completer<Map<String, Object?>>();
        var calls = 0;
        final pack = RemoteContentPack<_Level>(
          assetPath: _assetPath,
          schemaVersion: 1,
          fromJson: _Level.fromJson,
          contentSecret: _secret,
          bundle: _asset('Asset'),
          fetchRemote: () => ++calls == 1 ? older.future : newer.future,
        );

        await pack.load();
        final olderRefresh = pack.refreshed;
        await pack.load();
        final newerRefresh = pack.refreshed;
        expect(calls, 2);
        expect(identical(olderRefresh, newerRefresh), isFalse);

        newer.complete(
          signExport({'id': 2, 'name': 'Newer', 'schemaVersion': 1}, _secret),
        );
        await newerRefresh;
        older.complete(
          signExport({'id': 1, 'name': 'Older', 'schemaVersion': 1}, _secret),
        );
        await olderRefresh;

        expect(pack.current!.name, 'Newer');
      },
    );

    test(
      'BUG-137: load generation starts before an older asset read completes',
      () async {
        final oldAsset = Completer<ByteData>();
        final oldFetch = Completer<Map<String, Object?>>();
        final newFetch = Completer<Map<String, Object?>>();
        var fetchCalls = 0;
        final pack = RemoteContentPack<_Level>(
          assetPath: _assetPath,
          schemaVersion: 1,
          fromJson: _Level.fromJson,
          contentSecret: _secret,
          bundle: _SequencedAssetBundle(
            oldAsset.future,
            ByteData.sublistView(
              Uint8List.fromList(
                utf8.encode(
                  jsonEncode({
                    'id': 1,
                    'name': 'Newer Asset',
                    'schemaVersion': 1,
                  }),
                ),
              ),
            ),
          ),
          fetchRemote: () =>
              ++fetchCalls == 1 ? newFetch.future : oldFetch.future,
        );

        final oldLoad = pack.load();
        final oldRefresh = pack.refreshed;
        final newLoad = pack.load();
        final newRefresh = pack.refreshed;
        expect(identical(oldRefresh, newRefresh), isFalse);
        await newLoad;

        newFetch.complete(
          signExport({'id': 2, 'name': 'Newer', 'schemaVersion': 1}, _secret),
        );
        await newRefresh;
        oldAsset.complete(
          ByteData.sublistView(
            Uint8List.fromList(
              utf8.encode(
                jsonEncode({'id': 1, 'name': 'Late Asset', 'schemaVersion': 1}),
              ),
            ),
          ),
        );
        await oldLoad;
        expect(identical(pack.refreshed, newRefresh), isTrue);
        oldFetch.complete(
          signExport({
            'id': 3,
            'name': 'Old Fetch',
            'schemaVersion': 1,
          }, _secret),
        );
        await oldRefresh;

        expect(fetchCalls, 2);
        expect(pack.current!.name, 'Newer');
      },
    );

    test(
      'BUG-137: stale withCache response cannot overwrite current or disk cache',
      () async {
        final older = Completer<Map<String, Object?>>();
        final newer = Completer<Map<String, Object?>>();
        var calls = 0;
        final pack = RemoteContentPack<_Level>.withCache(
          assetPath: _assetPath,
          schemaVersion: 1,
          fromJson: _Level.fromJson,
          contentSecret: _secret,
          storage: storage,
          cacheKey: cacheKey,
          bundle: _asset('Asset'),
          fetchRemote: () => ++calls == 1 ? older.future : newer.future,
        );

        await pack.load();
        final olderRefresh = pack.refreshed;
        await pack.load();
        final newerRefresh = pack.refreshed;
        newer.complete(
          signExport({'id': 2, 'name': 'Newer', 'schemaVersion': 1}, _secret),
        );
        await newerRefresh;
        older.complete(
          signExport({'id': 1, 'name': 'Older', 'schemaVersion': 1}, _secret),
        );
        await olderRefresh;

        final restarted = RemoteContentPack<_Level>.withCache(
          assetPath: _assetPath,
          schemaVersion: 1,
          fromJson: _Level.fromJson,
          storage: storage,
          cacheKey: cacheKey,
          bundle: _asset('Different Asset'),
        );
        await restarted.load();
        expect(pack.current!.name, 'Newer');
        expect(restarted.current!.name, 'Newer');
      },
    );

    test(
      'BUG-137: delayed stale cache write is followed by latest commit',
      () async {
        final firstFetch = Completer<Map<String, Object?>>();
        final secondFetch = Completer<Map<String, Object?>>();
        var calls = 0;
        final delayedPrefs = await SharedPreferences.getInstance();
        final delayedStorage = _DelayedWriteStorage(delayedPrefs, cacheKey);
        final pack = RemoteContentPack<_Level>.withCache(
          assetPath: _assetPath,
          schemaVersion: 1,
          fromJson: _Level.fromJson,
          contentSecret: _secret,
          storage: delayedStorage,
          cacheKey: cacheKey,
          bundle: _asset('Asset'),
          fetchRemote: () =>
              ++calls == 1 ? firstFetch.future : secondFetch.future,
        );

        await pack.load();
        final firstRefresh = pack.refreshed;
        firstFetch.complete(
          signExport({'id': 1, 'name': 'Older', 'schemaVersion': 1}, _secret),
        );
        await delayedStorage.writeStarted.future;

        await pack.load();
        final secondRefresh = pack.refreshed;
        secondFetch.complete(
          signExport({'id': 2, 'name': 'Newer', 'schemaVersion': 1}, _secret),
        );
        await Future<void>.delayed(Duration.zero);
        delayedStorage.allowWrite.complete();
        await firstRefresh;
        await secondRefresh;
        expect(delayedStorage.writes, hasLength(2));
        expect(jsonDecode(delayedStorage.writes.last)['name'], 'Newer');

        final restarted = RemoteContentPack<_Level>.withCache(
          assetPath: _assetPath,
          schemaVersion: 1,
          fromJson: _Level.fromJson,
          storage: StorageService(delayedPrefs),
          cacheKey: cacheKey,
          bundle: _asset('Different Asset'),
        );
        await restarted.load();
        expect(pack.current!.name, 'Newer');
        expect(restarted.current!.name, 'Newer');
      },
    );

    test(
      'BUG-137: equal/default history revisions still honor invocation order',
      () async {
        final older = Completer<Map<String, Object?>>();
        final newer = Completer<Map<String, Object?>>();
        var calls = 0;
        final pack = packWithHistory(
          useStorage: storage,
          fetchRemote: () => ++calls == 1 ? older.future : newer.future,
        );

        await pack.load();
        final olderRefresh = pack.refreshed;
        await pack.load();
        final newerRefresh = pack.refreshed;
        newer.complete(envelopeFor(2, 'Newer', contentVersion: 0));
        await newerRefresh;
        older.complete(envelopeFor(1, 'Older', contentVersion: 0));
        await olderRefresh;

        expect(pack.current!.name, 'Newer');
        expect(pack.currentContentVersion, 0);
        expect(pack.history.last.checksum, isNotEmpty);
      },
    );

    test(
      'history hỏng trên đĩa: bỏ entry hỏng, giữ entry hợp lệ, không chặn boot',
      () async {
        const good =
            '{"schemaVersion":1,"contentVersion":1,"checksum":"c1","appliedAtMs":1,"json":{"id":1,"name":"V1"}}';

        // Non-list/malformed blobs decode as empty history.
        await storage.setString('${cacheKey}_history_v1', '{"not":"a list"}');
        final notList = packWithHistory(useStorage: storage);
        await notList.load();
        expect(notList.history, isEmpty);

        await storage.remove(combinedRecordKey(cacheKey));
        await storage.setString('${cacheKey}_history_v1', 'not json at all');
        final garbage = packWithHistory(useStorage: storage);
        await garbage.load();
        expect(garbage.history, isEmpty);

        // Invalid entries are ignored when legacy history migrates.
        await storage.remove(combinedRecordKey(cacheKey));
        await storage.setString(
          '${cacheKey}_history_v1',
          '[$good,"not a map",{"checksum":"c2"},{"checksum":5,"json":{}},$good]',
        );
        final mixed = packWithHistory(useStorage: storage);
        await mixed.load();
        expect(mixed.history.map((r) => r.checksum), ['c1', 'c1']);
      },
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
