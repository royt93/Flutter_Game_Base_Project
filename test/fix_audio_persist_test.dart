import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:neon_jewels/core/audio_manager.dart';
import 'package:neon_jewels/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fix 4: AudioManager persist trạng thái mute + restore khi init.
/// FlameAudio không chạy trong test (try-catch → _ready=false); chỉ test
/// logic storage và trạng thái Rx — không test âm thanh thật.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<StorageService> makeStore([
    Map<String, Object> init = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(init);
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  setUp(() => Get.reset());
  tearDown(Get.reset);

  group('StorageService.getBool / setBool (Fix 4)', () {
    test('getBool default false khi chưa có key', () async {
      final s = await makeStore();
      expect(s.getBool(StorageKeys.audioMuted, def: false), isFalse);
    });

    test('setBool lưu true, getBool đọc lại đúng', () async {
      final s = await makeStore();
      await s.setBool(StorageKeys.audioMuted, true);
      expect(s.getBool(StorageKeys.audioMuted), isTrue);
    });

    test('setBool lưu false, getBool đọc lại false', () async {
      final s = await makeStore({'audio_muted': true});
      await s.setBool(StorageKeys.audioMuted, false);
      expect(s.getBool(StorageKeys.audioMuted), isFalse);
    });
  });

  group('AudioManager.init → restore muted (Fix 4)', () {
    test('init với prefs muted=true → muted.value = true', () async {
      final store = await makeStore({'audio_muted': true});
      Get.put(store);
      final audio = AudioManager();
      await audio.init(); // FlameAudio fail silently → _ready=false
      expect(audio.muted.value, isTrue);
    });

    test('init với prefs muted=false → muted.value = false', () async {
      final store = await makeStore({'audio_muted': false});
      Get.put(store);
      final audio = AudioManager();
      await audio.init();
      expect(audio.muted.value, isFalse);
    });

    test('init không có key → muted.value = false (default)', () async {
      final store = await makeStore();
      Get.put(store);
      final audio = AudioManager();
      await audio.init();
      expect(audio.muted.value, isFalse);
    });
  });

  group('AudioManager.toggleMute → persist (Fix 4)', () {
    Future<AudioManager> mk() async {
      final store = await makeStore();
      Get.put(store);
      final a = Get.put(AudioManager());
      await a.init();
      return a;
    }

    test('toggleMute OFF→ON lưu true vào storage', () async {
      final a = await mk();
      expect(a.muted.value, isFalse);
      a.toggleMute();
      expect(a.muted.value, isTrue);
      final stored = StorageService.to.getBool(StorageKeys.audioMuted);
      expect(stored, isTrue);
    });

    test('toggleMute ON→OFF lưu false vào storage', () async {
      final a = await mk();
      a.toggleMute(); // ON
      a.toggleMute(); // OFF
      expect(a.muted.value, isFalse);
      final stored = StorageService.to.getBool(StorageKeys.audioMuted);
      expect(stored, isFalse);
    });

    test('sau nhiều toggle, muted.value khớp storage', () async {
      final a = await mk();
      for (int i = 0; i < 5; i++) {
        a.toggleMute();
      }
      final stored = StorageService.to.getBool(StorageKeys.audioMuted);
      expect(stored, equals(a.muted.value));
    });
  });
}
