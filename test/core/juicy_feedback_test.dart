import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/audio_manager.dart';
import 'package:roy_casual_kit/core/haptics.dart';
import 'package:roy_casual_kit/core/juicy_feedback.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingAudioManager extends AudioManager {
  _RecordingAudioManager(this.events);

  final List<String> events;

  @override
  Future<void> playSfx(
    String fileName, {
    double volume = 1,
    bool duck = false,
  }) async {
    events.add('audio:$fileName');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each juicy preset maps to expected haptic level', () {
    expect(hapticLevelForJuicyPreset(JuicyPreset.tap), HapticLevel.light);
    expect(hapticLevelForJuicyPreset(JuicyPreset.pop), HapticLevel.light);
    expect(hapticLevelForJuicyPreset(JuicyPreset.success), HapticLevel.medium);
    expect(hapticLevelForJuicyPreset(JuicyPreset.warning), HapticLevel.medium);
    expect(hapticLevelForJuicyPreset(JuicyPreset.chestOpen), HapticLevel.heavy);
    expect(hapticLevelForJuicyPreset(JuicyPreset.coinTick), HapticLevel.light);
  });

  test('throws for empty caller SFX path', () {
    expect(
      () => JuicyFeedback.trigger(JuicyPreset.tap, sfxAsset: ''),
      throwsArgumentError,
    );
  });

  group('JuicyFeedback.trigger', () {
    late List<MethodCall> platformCalls;
    late List<String> events;
    late StorageService storage;
    late _RecordingAudioManager audio;

    setUp(() async {
      platformCalls = [];
      events = [];
      SharedPreferences.setMockInitialValues({});
      storage = StorageService(await SharedPreferences.getInstance());
      Get.put<StorageService>(storage, permanent: true);
      audio = _RecordingAudioManager(events);
      Get.put<AudioManager>(audio, permanent: true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            platformCalls.add(call);
            events.add('haptic:${call.arguments}');
            return null;
          });
    });

    tearDown(() {
      Get.reset();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test(
      'starts consumer SFX and matching preference-aware haptic together',
      () async {
        JuicyFeedback.trigger(
          JuicyPreset.success,
          sfxAsset: 'audio/win.ogg',
          audioManager: audio,
        );
        await Future<void>.delayed(Duration.zero);

        expect(audio.events, [
          'audio:audio/win.ogg',
          'haptic:HapticFeedbackType.mediumImpact',
        ]);
        expect(events, [
          'audio:audio/win.ogg',
          'haptic:HapticFeedbackType.mediumImpact',
        ]);
        expect(platformCalls, hasLength(1));
        expect(
          platformCalls.single.arguments,
          'HapticFeedbackType.mediumImpact',
        );
      },
    );

    test(
      'mute suppresses only SFX; disabled haptics suppress haptic',
      () async {
        audio.muted.value = true;
        await storage.setBool(StorageKeys.hapticsEnabled, false);
        JuicyFeedback.trigger(
          JuicyPreset.chestOpen,
          sfxAsset: 'audio/chest.ogg',
        );
        await Future<void>.delayed(Duration.zero);
        expect(audio.events, isEmpty);
        expect(platformCalls, isEmpty);
      },
    );
  });

  test('missing services are a safe no-op', () {
    Get.reset();
    expect(
      () => JuicyFeedback.trigger(
        JuicyPreset.coinTick,
        sfxAsset: 'audio/coin.ogg',
      ),
      returnsNormally,
    );
  });
}
