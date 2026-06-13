import 'package:flame_audio/flame_audio.dart';
import 'package:get/get.dart';

/// Quản lý toàn bộ âm thanh: nhạc nền + SFX nốt nhạc theo combo.
///
/// Dùng asset trong `asset/audio/`:
/// - bkg.mp3 / bkg1.mp3 / bkg2.mp3: nhạc nền
/// - notes/n01..n24.mp3: 24 nốt tăng dần cao độ (combo càng cao nốt càng cao)
class AudioManager extends GetxService {
  static const _bgmTracks = ['bkg.mp3', 'bkg1.mp3', 'bkg2.mp3'];
  static const int noteCount = 24;

  final RxBool muted = false.obs;
  bool _bgmPlaying = false;
  bool _ready = false;

  /// Lấy instance nếu đã đăng ký (an toàn khi gọi từ game/widget test).
  static AudioManager? get maybe =>
      Get.isRegistered<AudioManager>() ? Get.find<AudioManager>() : null;

  Future<void> init() async {
    FlameAudio.audioCache.prefix = 'asset/audio/';
    try {
      await FlameAudio.audioCache.loadAll([
        for (int i = 1; i <= noteCount; i++) 'notes/n${_pad(i)}.mp3',
      ]);
      _ready = true;
    } catch (_) {
      // môi trường không có audio (vd: một số test) → bỏ qua, không crash
      _ready = false;
    }
  }

  String _pad(int i) => i.toString().padLeft(2, '0');

  void startBgm({int track = 0}) {
    if (_bgmPlaying || muted.value) return;
    final name = _bgmTracks[track % _bgmTracks.length];
    FlameAudio.bgm.play(name, volume: 0.35);
    _bgmPlaying = true;
  }

  void stopBgm() {
    if (!_bgmPlaying) return;
    FlameAudio.bgm.stop();
    _bgmPlaying = false;
  }

  void toggleMute() {
    muted.toggle();
    if (muted.value) {
      FlameAudio.bgm.pause();
    } else {
      FlameAudio.bgm.resume();
    }
  }

  /// Phát nốt theo bước combo (1 = thấp nhất). Combo lớn → nốt cao → cảm giác leo thang.
  void playNote(int step) {
    if (muted.value || !_ready) return;
    final idx = step.clamp(1, noteCount);
    FlameAudio.play('notes/n${_pad(idx)}.mp3', volume: 0.6);
  }

  /// Âm cho gem special (nốt cao nhất, to hơn).
  void playSpecial() {
    if (muted.value || !_ready) return;
    FlameAudio.play('notes/n${_pad(noteCount)}.mp3', volume: 0.85);
  }
}
