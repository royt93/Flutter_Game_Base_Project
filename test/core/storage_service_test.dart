import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/storage_service.dart';
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
  });
}
