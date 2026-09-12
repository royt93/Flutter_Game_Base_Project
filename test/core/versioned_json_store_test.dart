import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/cloud_save_provider.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/versioned_json_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Profile {
  const _Profile({required this.name, required this.level});
  final String name;
  final int level;
}

class _FakeCloudSaveProvider implements CloudSaveProvider {
  Map<String, Object?>? cloudData;

  @override
  Future<void> signIn() async {}

  @override
  Future<Map<String, Object?>?> download() async => cloudData;

  @override
  Future<void> upload(Map<String, Object?> data) async => cloudData = data;
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

  test(
    'BUG-13: save() stamp syncedAtMs qua nowMsClamped(storage) — không lùi '
    'được dù đồng hồ máy bị chỉnh lùi giữa 2 lần save()',
    () async {
      final s = makeStore();
      await s.save(const _Profile(name: 'Dave', level: 1));

      final rawAfterFirst = store.getString('profile');
      final firstSyncedAt =
          (jsonDecode(rawAfterFirst!) as Map)['syncedAtMs'] as int;

      // Đẩy mốc kẹp đồng hồ (StorageKeys.maxMsSeen) lên tương lai xa —
      // mô phỏng "đã từng thấy" 1 thời điểm rất xa, y hệt cách
      // clamped_clock_test.dart giả lập tua đồng hồ mà không cần chờ thời
      // gian thật trôi qua.
      await store.setInt(StorageKeys.maxMsSeen, firstSyncedAt + 100000);

      await s.save(const _Profile(name: 'Dave', level: 2));
      final rawAfterSecond = store.getString('profile');
      final secondSyncedAt =
          (jsonDecode(rawAfterSecond!) as Map)['syncedAtMs'] as int;

      expect(
        secondSyncedAt,
        greaterThanOrEqualTo(firstSyncedAt + 100000),
        reason:
            'syncedAtMs phải theo mốc kẹp đồng hồ (nowMsClamped), không phải '
            'DateTime.now() thô — nếu không, đồng hồ máy thật (nhỏ hơn mốc '
            'đã kẹp) sẽ làm syncedAtMs lùi lại, phá last-write-wins.',
      );
    },
  );

  group('BUG-20: local save không phải nguồn tin cậy — không throw, có policy rõ ràng', () {
    test('JSON hỏng (không parse được) → load() trả về null, không throw', () async {
      await store.setString('profile', 'not valid json{{{');
      expect(makeStore().load(), isNull);
    });

    test('JSON là 1 list thay vì object → load() trả về null, không throw', () async {
      await store.setString('profile', '["a", "b"]');
      expect(makeStore().load(), isNull);
    });

    test('JSON là 1 số/chuỗi trần (không phải object) → load() trả về null', () async {
      await store.setString('profile', '42');
      expect(makeStore().load(), isNull);
    });

    test(
      'schemaVersion sai kiểu (chuỗi thay vì số) → coi như version 0, vẫn '
      'chạy migrate an toàn (không throw)',
      () async {
        await store.setString(
          'profile',
          '{"schemaVersion":"not-a-number","name":"X","level":1}',
        );
        final s = makeStore(
          schemaVersion: 2,
          migrate: (fromVersion, json) {
            expect(fromVersion, 0);
            return {...json, 'level': 9};
          },
        );
        final loaded = s.load();
        expect(loaded!.name, 'X');
        expect(loaded.level, 9);
      },
    );

    test(
      'schemaVersion CAO HƠN hiện tại (app bị hạ version) → load() trả về '
      'null, KHÔNG đưa thẳng vào fromJson/migrate hiện tại',
      () async {
        await store.setString(
          'profile',
          '{"schemaVersion":99,"name":"FromFuture","level":1}',
        );
        final s = makeStore(
          schemaVersion: 2,
          migrate: (fromVersion, json) =>
              throw StateError('migrate không nên được gọi cho version tương lai'),
        );
        expect(s.load(), isNull);
      },
    );

    test(
      'schemaVersion đúng bằng hiện tại nhưng thiếu field bắt buộc → '
      'fromJson tự throw như bình thường (KHÔNG phải trách nhiệm của '
      '_readLocalJson bọc lỗi field cụ thể — chỉ bọc lỗi decode/envelope)',
      () async {
        await store.setString('profile', '{"schemaVersion":2,"name":"NoLevel"}');
        final s = makeStore(schemaVersion: 2);
        expect(() => s.load(), throwsA(isA<TypeError>()));
      },
    );
  });

  group('BUG-20: syncWith áp dụng cùng policy cho cloud payload', () {
    test(
      'cloud schemaVersion sai kiểu NHƯNG field khác cũng hỏng → chấp nhận '
      'coi như version 0 (giống hệt policy local), rồi fromJson tự chặn vì '
      'field thật sự không đọc được — local vẫn giữ nguyên',
      () async {
        final s = makeStore(schemaVersion: 2);
        await s.save(const _Profile(name: 'LocalSafe', level: 5));

        final provider = _FakeCloudSaveProvider()
          ..cloudData = {
            'schemaVersion': 'garbage',
            'name': 'FromCloud',
            'level': 'also-garbage', // fromJson cast 'level' as int sẽ throw
            'syncedAtMs': DateTime.now().millisecondsSinceEpoch + 100000,
          };
        await s.syncWith(provider);

        final loaded = s.load();
        expect(loaded!.name, 'LocalSafe');
      },
    );

    test(
      'cloud schemaVersion CAO HƠN hiện tại → bị từ chối, local giữ nguyên '
      'dù cloud "mới hơn" theo timestamp',
      () async {
        final s = makeStore(schemaVersion: 2);
        await s.save(const _Profile(name: 'LocalSafe', level: 5));

        final provider = _FakeCloudSaveProvider()
          ..cloudData = {
            'schemaVersion': 99,
            'name': 'FromFuture',
            'level': 1,
            'syncedAtMs': DateTime.now().millisecondsSinceEpoch + 100000,
          };
        await s.syncWith(provider);

        expect(s.load()!.name, 'LocalSafe');
      },
    );

    test(
      'cloud schemaVersion CŨ HƠN, mới hơn theo timestamp → migrate đúng '
      'trước khi ghi đè local',
      () async {
        final s = makeStore(
          schemaVersion: 2,
          migrate: (fromVersion, json) => {...json, 'level': 7},
        );
        await s.save(const _Profile(name: 'Local', level: 5));

        final provider = _FakeCloudSaveProvider()
          ..cloudData = {
            'schemaVersion': 1,
            'name': 'FromCloudOldSchema',
            'syncedAtMs': DateTime.now().millisecondsSinceEpoch + 100000,
          };
        await s.syncWith(provider);

        final loaded = s.load();
        expect(loaded!.name, 'FromCloudOldSchema');
        expect(loaded.level, 7);
      },
    );

    test(
      'cloud có field sai kiểu khiến fromJson thật sự throw → không ghi đè '
      'local (kiểm tra fromJson trước khi trust)',
      () async {
        final s = makeStore(schemaVersion: 2);
        await s.save(const _Profile(name: 'LocalSafe', level: 5));

        final provider = _FakeCloudSaveProvider()
          ..cloudData = {
            'schemaVersion': 2,
            'name': 'FromCloud',
            'level': 'not-an-int', // fromJson cast 'level' as int sẽ throw
            'syncedAtMs': DateTime.now().millisecondsSinceEpoch + 100000,
          };
        await s.syncWith(provider);

        expect(s.load()!.name, 'LocalSafe');
      },
    );

    test(
      'cloud timestamp sai kiểu (chuỗi thay vì số) → coi như -1 (cũ nhất), '
      'không ghi đè local có timestamp thật',
      () async {
        final s = makeStore(schemaVersion: 2);
        await s.save(const _Profile(name: 'LocalSafe', level: 5));

        final provider = _FakeCloudSaveProvider()
          ..cloudData = {
            'schemaVersion': 2,
            'name': 'FromCloud',
            'level': 1,
            'syncedAtMs': 'not-a-number',
          };
        await s.syncWith(provider);

        expect(s.load()!.name, 'LocalSafe');
      },
    );
  });
}
