import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/logic/backup_code.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StorageService', () {
    late StorageService store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = StorageService(await SharedPreferences.getInstance());
    });

    test('getInt/getBool trả về def khi chưa có key', () {
      expect(store.getInt('missing'), 0);
      expect(store.getInt('missing', def: 7), 7);
      expect(store.getBool('missing'), false);
      expect(store.getBool('missing', def: true), true);
      expect(store.getString('missing'), isNull);
    });

    test('setInt/setBool/setString rồi đọc lại đúng giá trị', () async {
      await store.setInt('k_int', 42);
      await store.setBool('k_bool', true);
      await store.setString('k_str', 'hello');

      expect(store.getInt('k_int'), 42);
      expect(store.getBool('k_bool'), true);
      expect(store.getString('k_str'), 'hello');
    });

    test('remove xoá key, đọc lại trả về def', () async {
      await store.setInt('k_int', 42);
      await store.remove('k_int');
      expect(store.getInt('k_int'), 0);
    });

    test('StorageKeys.highScore/star sinh key khác nhau theo level', () {
      expect(StorageKeys.highScore(1), isNot(StorageKeys.highScore(2)));
      expect(StorageKeys.star(1), isNot(StorageKeys.highScore(1)));
    });

    test('getDouble trả về def khi chưa có key', () {
      expect(store.getDouble('missing'), 1.0);
      expect(store.getDouble('missing', def: 0.5), 0.5);
    });

    test('setDouble rồi đọc lại đúng giá trị (X2 bgm/sfx volume)', () async {
      await store.setDouble(StorageKeys.bgmVolume, 0.4);
      await store.setDouble(StorageKeys.sfxVolume, 0.7);
      expect(store.getDouble(StorageKeys.bgmVolume), 0.4);
      expect(store.getDouble(StorageKeys.sfxVolume), 0.7);
    });

    test(
      'X2 haptics: setBool persist qua StorageKeys.hapticsEnabled',
      () async {
        expect(store.getBool(StorageKeys.hapticsEnabled, def: true), true);
        await store.setBool(StorageKeys.hapticsEnabled, false);
        expect(store.getBool(StorageKeys.hapticsEnabled, def: true), false);
      },
    );

    test('exportAll trả đúng toàn bộ key/giá trị đã set', () async {
      await store.setInt('k_int', 42);
      await store.setBool('k_bool', true);
      await store.setDouble('k_double', 0.5);
      await store.setString('k_str', 'hello');

      final dump = store.exportAll();
      expect(dump['k_int'], 42);
      expect(dump['k_bool'], true);
      expect(dump['k_double'], 0.5);
      expect(dump['k_str'], 'hello');
    });

    test('importAll ghi đè storage từ map thủ công', () async {
      await store.setString('stale_key', 'must disappear');
      await store.importAll({
        'k_int': 7,
        'k_bool': true,
        'k_double': 1.5,
        'k_str': 'world',
      });

      expect(store.getInt('k_int'), 7);
      expect(store.getBool('k_bool'), true);
      expect(store.getDouble('k_double'), 1.5);
      expect(store.getString('k_str'), 'world');
      expect(store.getString('stale_key'), isNull);
    });

    test('importAll fallback xoá key cũ trước khi import', () async {
      final fallback = StorageService(null);
      await fallback.setString('stale_key', 'old');
      await fallback.importAll({'fresh_key': 'new'});

      expect(fallback.getString('stale_key'), isNull);
      expect(fallback.getString('fresh_key'), 'new');
    });

    test(
      'importAll reject value không hỗ trợ mà không làm mất dữ liệu',
      () async {
        await store.setString('existing_key', 'keep');

        await expectLater(
          store.importAll({
            'bad_key': <Object>[1, 2],
          }),
          throwsA(isA<FormatException>()),
        );

        expect(store.getString('existing_key'), 'keep');
        expect(store.getString('bad_key'), isNull);
      },
    );

    test('importAll reject null mà không xoá storage hiện tại', () async {
      await store.setString('existing_key', 'keep');

      await expectLater(
        store.importAll({'null_key': null}),
        throwsA(isA<FormatException>()),
      );

      expect(store.getString('existing_key'), 'keep');
    });

    test(
      'round-trip đầy đủ: export → encode → decode → import vào StorageService mới',
      () async {
        await store.setInt(StorageKeys.coins, 999);
        await store.setBool(StorageKeys.colorblindMode, true);
        await store.setDouble(StorageKeys.bgmVolume, 0.3);
        await store.setString(StorageKeys.playerName, 'Roy');

        final code = await encodeSecureBackupCode(store.exportAll());
        final decoded = await decodeSecureBackupCode(code);
        expect(decoded, isNotNull);

        SharedPreferences.setMockInitialValues({});
        final fresh = StorageService(await SharedPreferences.getInstance());
        await fresh.importAll(decoded!);

        expect(fresh.getInt(StorageKeys.coins), 999);
        expect(fresh.getBool(StorageKeys.colorblindMode), true);
        expect(fresh.getDouble(StorageKeys.bgmVolume), 0.3);
        expect(fresh.getString(StorageKeys.playerName), 'Roy');
      },
    );
  });
}
