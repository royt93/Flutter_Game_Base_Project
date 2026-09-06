import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/cloud_save_provider.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/versioned_json_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Profile {
  const _Profile({required this.name, required this.coins});
  final String name;
  final int coins;
}

class _FakeCloudSaveProvider implements CloudSaveProvider {
  Map<String, Object?>? cloudData;
  int uploadCount = 0;

  @override
  Future<void> signIn() async {}

  @override
  Future<Map<String, Object?>?> download() async => cloudData;

  @override
  Future<void> upload(Map<String, Object?> data) async {
    cloudData = data;
    uploadCount++;
  }
}

void main() {
  late StorageService storage;
  late VersionedJsonStore<_Profile> jsonStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    jsonStore = VersionedJsonStore<_Profile>(
      storage: storage,
      key: 'profile',
      schemaVersion: 1,
      toJson: (p) => {'name': p.name, 'coins': p.coins},
      fromJson: (json) =>
          _Profile(name: json['name'] as String, coins: json['coins'] as int),
      migrate: (fromVersion, json) => json,
    );
  });

  test('không có local lẫn cloud → syncWith không crash, không upload', () async {
    final provider = _FakeCloudSaveProvider();
    await jsonStore.syncWith(provider);

    expect(jsonStore.load(), isNull);
    expect(provider.uploadCount, 0);
  });

  test('có local, chưa có cloud → sync upload local lên cloud', () async {
    await jsonStore.save(const _Profile(name: 'Alice', coins: 100));
    final provider = _FakeCloudSaveProvider();

    await jsonStore.syncWith(provider);

    expect(provider.uploadCount, 1);
    expect(provider.cloudData!['name'], 'Alice');
  });

  test('cloud mới hơn local → local bị ghi đè bằng dữ liệu cloud', () async {
    await jsonStore.save(const _Profile(name: 'Alice', coins: 100));
    final provider = _FakeCloudSaveProvider()
      ..cloudData = {
        'schemaVersion': 1,
        'name': 'Alice-from-cloud',
        'coins': 999,
        'syncedAtMs': DateTime.now().millisecondsSinceEpoch + 100000,
      };

    await jsonStore.syncWith(provider);

    final loaded = jsonStore.load();
    expect(loaded!.name, 'Alice-from-cloud');
    expect(loaded.coins, 999);
    // Đã đồng bộ, không cần upload lại đè lên bản mới hơn của cloud.
    expect(provider.uploadCount, 0);
  });

  test('local mới hơn cloud → cloud được cập nhật bằng dữ liệu local', () async {
    final provider = _FakeCloudSaveProvider()
      ..cloudData = {
        'schemaVersion': 1,
        'name': 'Old',
        'coins': 1,
        'syncedAtMs': 0,
      };
    await jsonStore.save(const _Profile(name: 'Alice', coins: 100));

    await jsonStore.syncWith(provider);

    expect(provider.uploadCount, 1);
    expect(provider.cloudData!['name'], 'Alice');
    final loaded = jsonStore.load();
    expect(loaded!.name, 'Alice');
  });
}
