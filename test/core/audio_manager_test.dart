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

    test('AudioManager dùng AudioCache riêng, đúng prefix của kit', () async {
      final manager = AudioManager();
      await manager.init();

      expect(
        manager.debugAudioCachePrefix,
        'packages/roy_casual_kit/asset/audio/',
      );
    });

    test('playSfx không throw và no-op ngay khi muted.value == true', () async {
      final manager = AudioManager();
      manager.muted.value = true;

      await expectLater(
        manager.playSfx('tap.mp3').timeout(const Duration(seconds: 2)),
        completes,
      );
    });

    test(
      'playSfx khi không muted vẫn không throw dù không có audio backend thật',
      () async {
        final manager = AudioManager();
        manager.muted.value = false;

        await expectLater(
          manager.playSfx('tap.mp3').timeout(const Duration(seconds: 2)),
          completes,
        );
      },
    );

    test('playSfx dùng AudioCache riêng biệt, KHÔNG trùng prefix với bgm cache '
        '(guard chống lại lỗi kiểu BUG-04 cho SFX)', () {
      final manager = AudioManager();

      expect(manager.debugSfxCachePrefix, 'assets/');
      expect(
        manager.debugSfxCachePrefix,
        isNot(equals(manager.debugAudioCachePrefix)),
      );
    });

    test('playSfx gọi liên tiếp (rapid taps) không throw', () async {
      final manager = AudioManager();
      manager.muted.value = false;

      await expectLater(
        Future.wait([
          manager.playSfx('tap.mp3'),
          manager.playSfx('tap.mp3'),
        ]).timeout(const Duration(seconds: 2)),
        completes,
      );
    });

    group('BUG-24: AudioPlayer disposal', () {
      test(
        'mỗi playSfx() (kể cả khi thất bại vì thiếu audio backend) đều '
        'dispose đúng player của nó — debugSfxDisposeCount tăng đúng 1',
        () async {
          final manager = AudioManager();
          manager.muted.value = false;

          final before = manager.debugSfxDisposeCount;
          await manager.playSfx('tap.mp3').timeout(const Duration(seconds: 2));

          expect(manager.debugSfxDisposeCount - before, 1);
        },
      );

      test('playSfx() liên tiếp — mỗi lần gọi đều dispose đúng player riêng '
          'của nó, không bị bỏ sót', () async {
        final manager = AudioManager();
        manager.muted.value = false;

        final before = manager.debugSfxDisposeCount;
        await Future.wait([
          manager.playSfx('tap.mp3'),
          manager.playSfx('tap.mp3'),
          manager.playSfx('tap.mp3'),
        ]).timeout(const Duration(seconds: 2));

        expect(manager.debugSfxDisposeCount - before, 3);
      });

      test('muted.value == true (no-op, không tạo player nào) → '
          'debugSfxDisposeCount không đổi', () async {
        final manager = AudioManager();
        manager.muted.value = true;

        final before = manager.debugSfxDisposeCount;
        await manager.playSfx('tap.mp3').timeout(const Duration(seconds: 2));

        expect(manager.debugSfxDisposeCount, before);
      });

      test('onClose() dispose _bgm, không throw kể cả khi chưa init()', () {
        final manager = AudioManager();
        Get.put(manager, permanent: true);

        expect(() => Get.delete<AudioManager>(force: true), returnsNormally);
      });
    });

    group('IDEA-45: audio ducking', () {
      test('duckCount mặc định là 0', () {
        final manager = AudioManager();
        expect(manager.duckCount, 0);
      });

      test(
        'playSfx(duck: true) tăng duckCount lên 1 trong lúc phát, về 0 sau khi xong',
        () async {
          final manager = AudioManager();

          final future = manager.playSfx('tap.mp3', duck: true);
          // Đồng bộ ngay sau lời gọi (chưa await) — _duckBgm() đã chạy vì
          // nó nằm TRƯỚC await đầu tiên trong hàm.
          expect(manager.duckCount, 1);

          await future.timeout(const Duration(seconds: 2));

          expect(manager.duckCount, 0);
        },
      );

      test('playSfx(duck: false) (mặc định) không đụng duckCount', () async {
        final manager = AudioManager();

        final future = manager.playSfx('tap.mp3');
        expect(manager.duckCount, 0);

        await future.timeout(const Duration(seconds: 2));

        expect(manager.duckCount, 0);
      });

      test(
        'nhiều SFX duck chồng lên nhau: count lên đúng 2, không về 0 sớm khi '
        'chỉ 1 cái xong, về đúng 0 khi cả 2 đều xong',
        () async {
          final manager = AudioManager();

          final futureA = manager.playSfx('a.mp3', duck: true);
          final futureB = manager.playSfx('b.mp3', duck: true);
          expect(manager.duckCount, 2);

          await futureA.timeout(const Duration(seconds: 2));
          // futureA xong nhưng futureB coi như vẫn có thể đang chạy (dù ở
          // môi trường test cả 2 đều fail/resolve gần như ngay lập tức) —
          // điều quan trọng cần đúng là count không bao giờ âm và cuối cùng
          // về đúng 0, không kẹt ở giá trị dương.
          await futureB.timeout(const Duration(seconds: 2));

          expect(manager.duckCount, 0);
        },
      );

      test('muted.value bật giữa lúc đang duck (trước khi playSfx trả về) vẫn '
          'unduck đúng, không kẹt count', () async {
        final manager = AudioManager();

        final future = manager.playSfx('tap.mp3', duck: true);
        expect(manager.duckCount, 1);

        manager.muted.value = true;

        await future.timeout(const Duration(seconds: 2));

        expect(manager.duckCount, 0);
      });

      test(
        'muted.value == true từ đầu → playSfx(duck: true) no-op hoàn toàn, '
        'không tăng duckCount (SFX còn không phát thì không có gì để duck)',
        () async {
          final manager = AudioManager();
          manager.muted.value = true;

          await manager
              .playSfx('tap.mp3', duck: true)
              .timeout(const Duration(seconds: 2));

          expect(manager.duckCount, 0);
        },
      );

      test(
        'onClose() (dispose _bgm) giữa lúc đang duck không làm playSfx throw, '
        'count vẫn về đúng 0',
        () async {
          final manager = AudioManager();
          Get.put(manager, permanent: true);

          final future = manager.playSfx('tap.mp3', duck: true);
          expect(manager.duckCount, 1);

          expect(() => Get.delete<AudioManager>(force: true), returnsNormally);

          await future.timeout(const Duration(seconds: 2));

          expect(manager.duckCount, 0);
        },
      );
    });
  });
}
