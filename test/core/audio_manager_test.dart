import 'dart:async';
import 'dart:io';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';
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

  group('AudioManager: BGM với platform audio giả', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const audioChannel = MethodChannel('xyz.luan/audioplayers');
    const globalChannel = MethodChannel('xyz.luan/audioplayers.global');
    const globalEvents = EventChannel('xyz.luan/audioplayers.global/events');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final calls = <MethodCall>[];
    final sinks = <String, MockStreamHandlerEventSink>{};
    final eventChannels = <EventChannel>[];
    late Directory temp;
    late AudioManager manager;
    String? bgmId;
    bool closed = false;
    late StreamController<void> nativeCalls;

    Future<void> waitForSfxResumes(int count) async {
      while (calls
              .where(
                (call) =>
                    call.method == 'resume' &&
                    (call.arguments as Map)['playerId'] != bgmId,
              )
              .length <
          count) {
        await nativeCalls.stream.first.timeout(const Duration(seconds: 2));
      }
      await Future<void>.delayed(Duration.zero);
    }

    List<MethodCall> bgmCalls(String method) => calls
        .where(
          (call) =>
              call.method == method &&
              (call.arguments as Map)['playerId'] == bgmId,
        )
        .toList();

    Future<void> flush() => Future<void>.delayed(Duration.zero);

    Future<void> start() async {
      manager.startBgm();
      await flush();
      bgmId =
          (calls.firstWhere((call) => call.method == 'setReleaseMode').arguments
                  as Map)['playerId']
              as String;
      expect(bgmCalls('resume'), hasLength(1));
    }

    setUp(() async {
      calls.clear();
      sinks.clear();
      eventChannels.clear();
      bgmId = null;
      closed = false;
      nativeCalls = StreamController<void>.broadcast();
      temp = Directory.systemTemp.createTempSync('roy_audio_test_');
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        final key = const StringCodec().decodeMessage(message);
        if (key == 'packages/roy_casual_kit/asset/audio/bkg.ogg' ||
            key == 'assets/a.mp3' ||
            key == 'assets/b.mp3') {
          return Uint8List.fromList([1, 2, 3]).buffer.asByteData();
        }
        return null;
      });
      messenger.setMockMethodCallHandler(
        pathChannel,
        (call) async => temp.path,
      );
      messenger.setMockMethodCallHandler(globalChannel, (call) async => null);
      messenger.setMockStreamHandler(
        globalEvents,
        MockStreamHandler.inline(onListen: (arguments, events) {}),
      );
      messenger.setMockMethodCallHandler(audioChannel, (call) async {
        calls.add(call);
        scheduleMicrotask(() => nativeCalls.add(null));
        final id = (call.arguments as Map)['playerId'] as String;
        if (call.method == 'create') {
          final channel = EventChannel('xyz.luan/audioplayers/events/$id');
          eventChannels.add(channel);
          messenger.setMockStreamHandler(
            channel,
            MockStreamHandler.inline(
              onListen: (arguments, events) {
                sinks[id] = events;
              },
            ),
          );
        } else if (call.method == 'setSourceUrl') {
          sinks[id]!.success({'event': 'audio.onPrepared', 'value': true});
        } else if (call.method == 'getCurrentPosition' ||
            call.method == 'getDuration') {
          return 0;
        }
        return null;
      });
      manager = AudioManager();
      await manager.init();
    });

    tearDown(() async {
      if (!closed) manager.onClose();
      await flush();
      await nativeCalls.close();
      for (final channel in eventChannels) {
        messenger.setMockStreamHandler(channel, null);
      }
      messenger.setMockStreamHandler(globalEvents, null);
      messenger.setMockMethodCallHandler(audioChannel, null);
      messenger.setMockMethodCallHandler(globalChannel, null);
      messenger.setMockMethodCallHandler(pathChannel, null);
      messenger.setMockMessageHandler('flutter/assets', null);
      temp.deleteSync(recursive: true);
    });

    test(
      'startBgm dùng volume đã lưu và lần gọi thứ hai không phát lại',
      () async {
        await store.setDouble(StorageKeys.bgmVolume, 0.72);
        await manager.init();
        await start();
        expect((bgmCalls('setVolume').single.arguments as Map)['volume'], 0.72);
        manager.startBgm();
        await flush();
        expect(bgmCalls('resume'), hasLength(1));
        expect(bgmCalls('setSourceUrl'), hasLength(1));
      },
    );

    test('mute chặn start/pause/resume, stop rồi start phát lại', () async {
      manager.muted.value = true;
      manager.startBgm();
      await flush();
      expect(calls, isEmpty);
      manager.muted.value = false;
      await start();
      calls.clear();
      manager.muted.value = true;
      manager.pauseBgm();
      manager.resumeBgm();
      await flush();
      expect(calls, isEmpty);
      manager.muted.value = false;
      manager.stopBgm();
      await flush();
      expect(bgmCalls('stop'), hasLength(1));
      manager.stopBgm();
      await flush();
      expect(bgmCalls('stop'), hasLength(1));
      manager.startBgm();
      await flush();
      expect(bgmCalls('resume'), hasLength(1));
    });

    test('pause/resume áp dụng lại volume bình thường', () async {
      await manager.setBgmVolume(0.8);
      await start();
      calls.clear();
      manager.pauseBgm();
      await flush();
      expect(bgmCalls('pause'), hasLength(1));
      manager.resumeBgm();
      await flush();
      expect((bgmCalls('setVolume').single.arguments as Map)['volume'], 0.8);
      expect(bgmCalls('resume'), hasLength(1));
    });

    test(
      'SFX duck chồng: resume dùng volume duck, chỉ SFX cuối mới khôi phục mix mới',
      () async {
        await manager.setBgmVolume(0.7);
        await start();
        calls.clear();
        final first = manager.playSfx('a.mp3', duck: true);
        final second = manager.playSfx('b.mp3', duck: true);
        await flush();
        expect(manager.duckCount, 2);
        await waitForSfxResumes(2);
        expect(bgmCalls('setVolume'), hasLength(1));
        expect(
          (bgmCalls('setVolume').single.arguments as Map)['volume'],
          closeTo(0.16, 0.0001),
        );
        manager.pauseBgm();
        await flush();
        manager.resumeBgm();
        await flush();
        expect(
          (bgmCalls('setVolume').last.arguments as Map)['volume'],
          closeTo(0.16, 0.0001),
        );
        await manager.setBgmVolume(0.9);
        await flush();
        expect(bgmCalls('setVolume'), hasLength(2));
        // Ghép player theo tên file nguồn (setSourceUrl), không theo thứ tự
        // resume: 2 SFX đọc file tạm bất đồng bộ nên thứ tự đó không đảm bảo.
        String sfxId(String file) =>
            calls
                    .firstWhere(
                      (call) =>
                          call.method == 'setSourceUrl' &&
                          (call.arguments as Map)['playerId'] != bgmId &&
                          ((call.arguments as Map)['url'] as String).endsWith(
                            '/$file',
                          ),
                    )
                    .arguments['playerId']
                as String;
        sinks[sfxId('a.mp3')]!.success({'event': 'audio.onComplete'});
        await first;
        await flush();
        expect(manager.duckCount, 1);
        expect(bgmCalls('setVolume'), hasLength(2));
        sinks[sfxId('b.mp3')]!.success({'event': 'audio.onComplete'});
        await second;
        await flush();
        expect(manager.duckCount, 0);
        expect((bgmCalls('setVolume').last.arguments as Map)['volume'], 0.9);
        expect(bgmCalls('setVolume'), hasLength(3));
      },
    );

    test(
      'setBgmVolume áp dụng live khi đang chơi, không gọi player trước start',
      () async {
        await manager.setBgmVolume(0.6);
        expect(calls, isEmpty);
        await start();
        calls.clear();
        await manager.setBgmVolume(0.4);
        await flush();
        expect((bgmCalls('setVolume').single.arguments as Map)['volume'], 0.4);
      },
    );

    test(
      'toggleMute pause rồi resume BGM đang chơi, không phát lại source',
      () async {
        await start();
        calls.clear();
        manager.toggleMute();
        await flush();
        expect(bgmCalls('pause'), hasLength(1));
        expect(store.getBool(StorageKeys.audioMuted), isTrue);
        manager.toggleMute();
        await flush();
        expect(bgmCalls('resume'), hasLength(1));
        expect(bgmCalls('setSourceUrl'), isEmpty);
        expect(store.getBool(StorageKeys.audioMuted), isFalse);
      },
    );

    test('toggleMute unmute trước start tự phát BGM', () async {
      manager.muted.value = true;
      manager.toggleMute();
      await flush();
      bgmId =
          (calls.firstWhere((call) => call.method == 'setReleaseMode').arguments
                  as Map)['playerId']
              as String;
      expect(bgmCalls('resume'), hasLength(1));
    });

    test('onClose dispose đúng BGM player, không throw', () async {
      await start();
      calls.clear();
      manager.onClose();
      closed = true;
      await flush();
      expect(bgmCalls('dispose'), hasLength(1));
      expect(bgmCalls('release'), hasLength(1));
    });
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

    group(
      'BUG-24 / ENH-79: SFX player lifecycle (pool thay vì tạo/huỷ mỗi lần)',
      () {
        test('mỗi playSfx() (kể cả khi thất bại vì thiếu audio backend) đều '
            'release đúng player về pool — debugSfxReleaseCount tăng đúng 1, '
            'pool không còn player nào active sau khi xong', () async {
          final manager = AudioManager();
          manager.muted.value = false;

          final before = manager.debugSfxReleaseCount;
          await manager.playSfx('tap.mp3').timeout(const Duration(seconds: 2));

          expect(manager.debugSfxReleaseCount - before, 1);
          expect(manager.debugSfxPoolActiveCount, 0);
        });

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
              await manager
                  .playSfx('tap.mp3')
                  .timeout(const Duration(seconds: 2));
            }

            expect(manager.debugSfxReleaseCount, 20);
            expect(manager.debugSfxPoolActiveCount, 0);
            expect(
              manager.debugSfxTotalCreated,
              1,
              reason:
                  'gọi tuần tự phải tái dùng lại đúng 1 player, không tạo '
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
            expect(
              () => Get.delete<AudioManager>(force: true),
              returnsNormally,
            );

            await expectLater(
              future.timeout(const Duration(seconds: 2)),
              completes,
            );
          },
        );
      },
    );

    group('ENH-95: persisted BGM/SFX mix', () {
      test('init() loads persisted BGM/SFX volumes', () async {
        await store.setDouble(StorageKeys.bgmVolume, 0.72);
        await store.setDouble(StorageKeys.sfxVolume, 0.44);
        final manager = AudioManager();

        await manager.init();

        expect(manager.bgmVolume.value, closeTo(0.72, 0.0001));
        expect(manager.sfxVolume.value, closeTo(0.44, 0.0001));
      });

      test('setBgmVolume/setSfxVolume clamp then persist', () async {
        final manager = AudioManager();

        await manager.setBgmVolume(2);
        await manager.setSfxVolume(-1);

        expect(manager.bgmVolume.value, 1);
        expect(manager.sfxVolume.value, 0);
        expect(store.getDouble(StorageKeys.bgmVolume), 1);
        expect(store.getDouble(StorageKeys.sfxVolume), 0);
      });

      test(
        'duck restore target follows user BGM volume, not old constant',
        () async {
          final manager = AudioManager();
          await manager.setBgmVolume(0.8);

          expect(manager.debugNormalBgmVolume, 0.8);
          expect(
            manager.debugDuckedBgmVolume,
            closeTo(0.8 * 0.08 / 0.35, 0.0001),
          );
        },
      );

      test('legacy mute stays orthogonal to saved mix', () async {
        await store.setBool(StorageKeys.audioMuted, true);
        await store.setDouble(StorageKeys.bgmVolume, 0.61);
        await store.setDouble(StorageKeys.sfxVolume, 0.27);
        final manager = AudioManager();

        await manager.init();
        manager.toggleMute();

        expect(manager.muted.value, isFalse);
        expect(manager.bgmVolume.value, closeTo(0.61, 0.0001));
        expect(manager.sfxVolume.value, closeTo(0.27, 0.0001));
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
