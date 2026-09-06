import 'package:flame_audio/flame_audio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/audio_manager.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  late StorageService store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = StorageService(await SharedPreferences.getInstance());
    Get.put(store, permanent: true);
  });

  group('AudioManager', () {
    test('maybe trả về null khi chưa Get.put', () {
      expect(AudioManager.maybe, isNull);
    });

    test('maybe trả về đúng instance khi đã đăng ký', () {
      final manager = AudioManager();
      Get.put(manager, permanent: true);
      expect(AudioManager.maybe, same(manager));
    });

    test('muted mặc định false trước khi init() đọc storage', () {
      final manager = AudioManager();
      expect(manager.muted.value, false);
    });

    test('toggleMute() đảo muted và persist qua StorageKeys.audioMuted', () {
      final manager = AudioManager();

      manager.toggleMute();
      expect(manager.muted.value, true);
      expect(store.getBool(StorageKeys.audioMuted, def: false), true);

      manager.toggleMute();
      expect(manager.muted.value, false);
      expect(store.getBool(StorageKeys.audioMuted, def: false), false);
    });

    test('init() nạp lại trạng thái muted đã lưu từ trước', () async {
      await store.setBool(StorageKeys.audioMuted, true);

      final manager = AudioManager();
      await manager.init();

      expect(manager.muted.value, true);
    });

    test(
      'BUG-04: init() không ghi đè FlameAudio.audioCache.prefix toàn cục '
      '(app dùng kit tự phát SFX riêng qua FlameAudio.play() không bị vỡ)',
      () async {
        FlameAudio.audioCache.prefix = 'assets/audio/'; // app tự set riêng
        final manager = AudioManager();

        await manager.init();

        expect(FlameAudio.audioCache.prefix, 'assets/audio/');
      },
    );

    test(
      'AudioManager dùng AudioCache riêng, đúng prefix của kit',
      () async {
        final manager = AudioManager();
        await manager.init();

        expect(
          manager.debugAudioCachePrefix,
          'packages/roy_casual_kit/asset/audio/',
        );
      },
    );
  });
}
