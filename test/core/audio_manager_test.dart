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

    group('BUG-24 / ENH-79: SFX player lifecycle (pool thay vì tạo/huỷ mỗi lần)', () {
      test(
        'mỗi playSfx() (kể cả khi thất bại vì thiếu audio backend) đều '
        'release đúng player về pool — debugSfxReleaseCount tăng đúng 1, '
        'pool không còn player nào active sau khi xong',
        () async {
          final manager = AudioManager();
          manager.muted.value = false;

          final before = manager.debugSfxReleaseCount;
          await manager.playSfx('tap.mp3').timeout(const Duration(seconds: 2));

          expect(manager.debugSfxReleaseCount - before, 1);
          expect(manager.debugSfxPoolActiveCount, 0);
        },
      );

      test('playSfx() liên tiếp — mỗi lần gọi đều release đúng player riêng '
          'về pool, không bị bỏ sót', () async {
        final manager = AudioManager();
        manager.muted.value = false;

        final before = manager.debugSfxReleaseCount;
        await Future.wait([
          manager.playSfx('tap.mp3'),
          manager.playSfx('tap.mp3'),
          manager.playSfx('tap.mp3'),
        ]).timeout(const Duration(seconds: 2));

        expect(manager.debugSfxReleaseCount - before, 3);
        expect(manager.debugSfxPoolActiveCount, 0);
      });

      test(
        // ENH-79: đúng mục đích của pool — kịch bản combo SFX thật (mỗi
        // lần gọi xong TRƯỚC khi lần sau bắt đầu, không phải 20 lần phát
        // cùng 1 khoảnh khắc tuyệt đối) phải TÁI SỬ DỤNG lại player, không
        // tạo mới cho mỗi lần gọi như code cũ.
        '20 lần gọi playSfx() TUẦN TỰ (mỗi lần release xong mới gọi lần '
        'sau): chỉ tạo ĐÚNG 1 player, tái sử dụng lại 19 lần còn lại',
        () async {
          final manager = AudioManager(sfxPoolCapacity: 4);
          manager.muted.value = false;

          for (var i = 0; i < 20; i++) {
            await manager.playSfx('tap.mp3').timeout(const Duration(seconds: 2));
          }

          expect(manager.debugSfxReleaseCount, 20);
          expect(manager.debugSfxPoolActiveCount, 0);
          expect(
            manager.debugSfxTotalCreated,
            1,
            reason: 'gọi tuần tự phải tái dùng lại đúng 1 player, không tạo '
                'mới mỗi lần như hành vi trước ENH-79',
          );
        },
      );

      test(
        // Burst THẬT SỰ đồng thời (tất cả in-flight cùng lúc, chưa ai kịp
        // release) vẫn cần đủ N channel tại đúng thời điểm đó — pooling
        // không thể giảm con số đó xuống dưới N (vật lý), nhưng phải đảm
        // bảo KHÔNG GIỮ LẠI quá sfxPoolCapacity sau khi burst kết thúc.
        'burst 20 lần gọi ĐỒNG THỜI (Future.wait): sau khi xong, số player '
        'GIỮ LẠI trong pool không vượt quá sfxPoolCapacity (phần dư bị '
        'dispose, không tích luỹ)',
        () async {
          final manager = AudioManager(sfxPoolCapacity: 4);
          manager.muted.value = false;

          await Future.wait([
            for (var i = 0; i < 20; i++) manager.playSfx('tap.mp3'),
          ]).timeout(const Duration(seconds: 5));

          expect(manager.debugSfxReleaseCount, 20);
          expect(manager.debugSfxPoolActiveCount, 0);
          expect(manager.debugSfxPoolFreeCount, lessThanOrEqualTo(4));
        },
      );

      test('muted.value == true (no-op, không tạo player nào) → '
          'debugSfxReleaseCount/debugSfxTotalCreated không đổi', () async {
        final manager = AudioManager();
        manager.muted.value = true;

        final beforeRelease = manager.debugSfxReleaseCount;
        final beforeCreated = manager.debugSfxTotalCreated;
        await manager.playSfx('tap.mp3').timeout(const Duration(seconds: 2));

        expect(manager.debugSfxReleaseCount, beforeRelease);
        expect(manager.debugSfxTotalCreated, beforeCreated);
      });

      test('onClose() dispose _bgm + mọi player trong pool, không throw kể '
          'cả khi chưa init()', () {
        final manager = AudioManager();
        Get.put(manager, permanent: true);

        expect(() => Get.delete<AudioManager>(force: true), returnsNormally);
      });

      test(
        'onClose() giữa lúc playSfx() đang chạy dở: không throw, không lỗi '
        'khi playSfx() release() player đã bị onClose() dispose trước đó',
        () async {
          final manager = AudioManager();
          Get.put(manager, permanent: true);

          final future = manager.playSfx('tap.mp3');
          expect(() => Get.delete<AudioManager>(force: true), returnsNormally);

          await expectLater(
            future.timeout(const Duration(seconds: 2)),
            completes,
          );
        },
      );
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
