import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/remote_content_pack.dart';
import 'package:roy_casual_kit/core/save_integrity.dart' show signExport;

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

void main() {
  test('asset-only (không có fetchRemote) → load() trả nội dung từ asset', () async {
    final pack = RemoteContentPack<_Level>(
      assetPath: _assetPath,
      schemaVersion: 1,
      fromJson: _Level.fromJson,
      bundle: _FakeAssetBundle({
        _assetPath: jsonEncode({'id': 1, 'name': 'Asset Level', 'schemaVersion': 1}),
      }),
    );

    final level = await pack.load();

    expect(level, isNotNull);
    expect(level!.name, 'Asset Level');
    expect(pack.current!.name, 'Asset Level');
  });

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
      final signed = signExport(
        {'id': 2, 'name': 'Remote Level', 'schemaVersion': 1},
        _secret,
      );
      final pack = RemoteContentPack<_Level>(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        contentSecret: _secret,
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({'id': 1, 'name': 'Asset Level', 'schemaVersion': 1}),
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
          _assetPath: jsonEncode({'id': 1, 'name': 'Asset Level', 'schemaVersion': 1}),
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
      final fromFuture = signExport(
        {'id': 3, 'name': 'Future Level', 'schemaVersion': 99},
        _secret,
      );
      final pack = RemoteContentPack<_Level>(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        contentSecret: _secret,
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({'id': 1, 'name': 'Asset Level', 'schemaVersion': 1}),
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
      final oldShape = signExport(
        {'id': 4, 'label': 'Legacy Level', 'schemaVersion': 0},
        _secret,
      );
      final pack = RemoteContentPack<_Level>(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        contentSecret: _secret,
        migrate: (fromVersion, json) =>
            {...json, 'name': json['label'], 'schemaVersion': 1},
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({'id': 1, 'name': 'Asset Level', 'schemaVersion': 1}),
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
      final signed = signExport(
        {'id': 5, 'name': 'Unverifiable Level', 'schemaVersion': 1},
        _secret,
      );
      final pack = RemoteContentPack<_Level>(
        assetPath: _assetPath,
        schemaVersion: 1,
        fromJson: _Level.fromJson,
        bundle: _FakeAssetBundle({
          _assetPath: jsonEncode({'id': 1, 'name': 'Asset Level', 'schemaVersion': 1}),
        }),
        fetchRemote: () async => signed,
      );

      await pack.load();
      await pack.refreshed;

      expect(pack.current!.name, 'Asset Level');
    },
  );

  test('fetchRemote throw (mất mạng) → giữ nguyên nội dung hiện tại, không crash', () async {
    final pack = RemoteContentPack<_Level>(
      assetPath: _assetPath,
      schemaVersion: 1,
      fromJson: _Level.fromJson,
      bundle: _FakeAssetBundle({
        _assetPath: jsonEncode({'id': 1, 'name': 'Asset Level', 'schemaVersion': 1}),
      }),
      fetchRemote: () async => throw Exception('network down'),
    );

    await pack.load();
    await pack.refreshed;

    expect(pack.current!.name, 'Asset Level');
  });

  test('fromJson ném lỗi trên nội dung remote hợp lệ chữ ký nhưng sai kiểu field → fallback về asset', () async {
    final badShape = signExport({'id': 'not-an-int', 'schemaVersion': 1}, _secret);
    final pack = RemoteContentPack<_Level>(
      assetPath: _assetPath,
      schemaVersion: 1,
      fromJson: _Level.fromJson,
      contentSecret: _secret,
      bundle: _FakeAssetBundle({
        _assetPath: jsonEncode({'id': 1, 'name': 'Asset Level', 'schemaVersion': 1}),
      }),
      fetchRemote: () async => badShape,
    );

    await pack.load();
    await pack.refreshed;

    expect(pack.current!.name, 'Asset Level');
  });

  test('load() không throw khi cả asset lẫn fetchRemote đều không có gì dùng được', () async {
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
  });

  group('BUG-37: schemaVersion vắng mặt — default phải khớp VersionedJsonStore (0, không phải "current")', () {
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
        final envelope = signExport(
          {'id': 10, 'label': 'Legacy Remote Level'},
          _secret,
        );
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
            _assetPath: jsonEncode({'id': 1, 'name': 'Asset Level', 'schemaVersion': 1}),
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
        final envelope = signExport(
          {'id': 10, 'name': 'Legacy Remote Level'},
          _secret,
        );
        final pack = RemoteContentPack<_Level>(
          assetPath: _assetPath,
          schemaVersion: 1,
          fromJson: _Level.fromJson,
          contentSecret: _secret,
          bundle: _FakeAssetBundle({
            _assetPath: jsonEncode({'id': 1, 'name': 'Asset Level', 'schemaVersion': 1}),
          }),
          fetchRemote: () async => envelope,
        );

        await pack.load();
        await pack.refreshed;

        expect(pack.current!.name, 'Asset Level'); // giữ nguyên, không nhận nội dung thiếu version
      },
    );
  });
}
