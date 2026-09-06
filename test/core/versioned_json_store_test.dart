import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/versioned_json_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Profile {
  const _Profile({required this.name, required this.level});
  final String name;
  final int level;
}

void main() {
  late StorageService store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = StorageService(await SharedPreferences.getInstance());
  });

  VersionedJsonStore<_Profile> makeStore({
    int schemaVersion = 2,
    Map<String, Object?> Function(int fromVersion, Map<String, Object?> json)?
    migrate,
  }) {
    return VersionedJsonStore<_Profile>(
      storage: store,
      key: 'profile',
      schemaVersion: schemaVersion,
      toJson: (p) => {'name': p.name, 'level': p.level},
      fromJson: (json) => _Profile(
        name: json['name'] as String,
        level: json['level'] as int,
      ),
      migrate: migrate ?? (fromVersion, json) => json,
    );
  }

  test('chưa từng lưu → load() trả về null', () {
    expect(makeStore().load(), isNull);
  });

  test('round-trip: lưu → load lại đúng giá trị, không cần migrate', () async {
    final s = makeStore();
    await s.save(const _Profile(name: 'Alice', level: 5));

    final loaded = s.load();
    expect(loaded!.name, 'Alice');
    expect(loaded.level, 5);
  });

  test(
    'đổi schemaVersion + cung cấp migrate → dữ liệu cũ tự chuyển đổi đúng khi load',
    () async {
      // Lưu bằng "phiên bản cũ" (schema v1, chưa có field level).
      final v1 = makeStore(schemaVersion: 1);
      await store.setString('profile', '{"schemaVersion":1,"name":"Bob"}');

      // Load bằng "phiên bản mới" (schema v2), migrate thêm level mặc định.
      final v2 = makeStore(
        schemaVersion: 2,
        migrate: (fromVersion, json) {
          expect(fromVersion, 1);
          return {...json, 'level': 1};
        },
      );

      final loaded = v2.load();
      expect(loaded!.name, 'Bob');
      expect(loaded.level, 1);
      // v1 không dùng trong test này, chỉ minh hoạ dữ liệu "cũ" — tránh
      // cảnh báo biến không dùng.
      expect(v1.schemaVersion, 1);
    },
  );

  test('dữ liệu đã ở đúng schemaVersion hiện tại → không gọi migrate', () async {
    final s = makeStore(
      schemaVersion: 2,
      migrate: (fromVersion, json) =>
          throw StateError('migrate không nên được gọi'),
    );
    await s.save(const _Profile(name: 'Carol', level: 3));

    final loaded = s.load();
    expect(loaded!.name, 'Carol');
  });
}
