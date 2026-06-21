import 'dart:async';

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
        ..._bgmTracks,
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
    _ignoreAudio(FlameAudio.bgm.play(name, volume: 0.35));
    _bgmPlaying = true;
  }

  void stopBgm() {
    if (!_bgmPlaying) return;
    _ignoreAudio(FlameAudio.bgm.stop());
    _bgmPlaying = false;
  }

  /// Tạm dừng nhạc khi app vào background (lifecycle paused/inactive/hidden).
  /// Giữ `_bgmPlaying = true` để biết có nhạc cần resume khi quay lại.
  void pauseBgm() {
    if (!_bgmPlaying || muted.value) return;
    _ignoreAudio(FlameAudio.bgm.pause());
  }

  /// Phát tiếp khi app trở lại foreground (resumed). Không resume nếu user mute.
  void resumeBgm() {
    if (!_bgmPlaying || muted.value) return;
    _ignoreAudio(FlameAudio.bgm.resume());
  }

  void toggleMute() {
    muted.toggle();
    if (muted.value) {
      _ignoreAudio(FlameAudio.bgm.pause());
    } else {
      _ignoreAudio(FlameAudio.bgm.resume());
    }
  }

  /// Phát nốt theo bước combo (1 = thấp nhất). Combo lớn → nốt cao → cảm giác leo thang.
  void playNote(int step) {
    if (muted.value || !_ready) return;
    final idx = step.clamp(1, noteCount);
    _ignoreAudio(FlameAudio.play('notes/n${_pad(idx)}.mp3', volume: 0.6));
  }

  // --------------------------------------------------------------------------
  // Giai điệu (Wave 8.1): biến chuỗi cascade thành câu nhạc du dương thay vì
  // chạy chromatic đơn điệu. 4 yếu tố:
  //  1) THANG NGŨ CUNG: mọi nốt rơi vào pentatonic → nghe hay ở mọi thứ tự.
  //  2) MÀU GEM = BẬC ÂM: mỗi màu gem giữ 1 "giọng" cố định.
  //  3) ĐỔI TÔNG THEO KHOÁ: world/stage dịch nốt gốc → 5 màu âm khác nhau.
  //  4) HỢP ÂM KHI COMBO LỚN: wombo (≥6) thêm quãng 3 + 5 (arpeggio) giải toả.
  // --------------------------------------------------------------------------

  /// Major pentatonic 1 quãng tám (bán cung từ gốc). An toàn ở mọi thứ tự.
  static const List<int> pentatonic = [0, 2, 4, 7, 9];

  /// Nốt gốc theo "khoá" (world/stage) — dịch tông cho đa dạng, giữ trong dải.
  static const List<int> keyRoots = [0, 2, 3, 5, 7];

  /// Bán cung của bậc ngũ cung [degree] (tự lên quãng tám khi vượt 5 bậc).
  static int pentaSemitone(int degree) =>
      pentatonic[degree % pentatonic.length] +
      12 * (degree ~/ pentatonic.length);

  /// THUẦN (test được): chỉ số nốt 1..24 cho 1 bước cascade.
  /// - [combo] ≥ 1: combo càng sâu → leo bậc ngũ cung (đi lên).
  /// - [colorIndex] 0..5: màu gem quyết định bậc gốc (mỗi màu 1 giọng); -1 = theo combo.
  /// - [keyIndex] ≥ 1: khoá (world/stage) dịch nốt gốc.
  static int noteIndexFor({
    required int combo,
    int colorIndex = -1,
    int keyIndex = 1,
  }) {
    final root = keyRoots[(keyIndex - 1) % keyRoots.length];
    // màu gem cho bậc gốc (mỗi màu 1 giọng); không có màu → bậc 0, combo tự dẫn.
    final baseDeg = colorIndex >= 0 ? colorIndex % pentatonic.length : 0;
    final degree = baseDeg + (combo - 1); // combo đẩy đi lên dần
    final semitone = root + pentaSemitone(degree);
    return semitone.clamp(0, noteCount - 1) + 1; // 1..24
  }

  /// Phát 1 bước cascade theo giai điệu (ngũ cung + màu + khoá + hợp âm wombo).
  void playMelodic({
    required int combo,
    int colorIndex = -1,
    int keyIndex = 1,
  }) {
    if (muted.value || !_ready) return;
    final idx = noteIndexFor(
      combo: combo,
      colorIndex: colorIndex,
      keyIndex: keyIndex,
    );
    _ignoreAudio(FlameAudio.play('notes/n${_pad(idx)}.mp3', volume: 0.6));
    // Wombo (combo lớn) → arpeggio quãng 3 + 5 ngũ cung tạo hợp âm giải toả.
    if (combo >= 6) {
      _arpAfter(
        70,
        combo: combo,
        colorIndex: colorIndex,
        keyIndex: keyIndex,
        addDegree: 2,
      );
      _arpAfter(
        140,
        combo: combo,
        colorIndex: colorIndex,
        keyIndex: keyIndex,
        addDegree: 4,
      );
    }
  }

  void _arpAfter(
    int delayMs, {
    required int combo,
    required int colorIndex,
    required int keyIndex,
    required int addDegree,
  }) {
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (muted.value || !_ready) return;
      final root = keyRoots[(keyIndex - 1) % keyRoots.length];
      final baseDeg = colorIndex >= 0 ? colorIndex % pentatonic.length : 0;
      final semitone = root + pentaSemitone(baseDeg + (combo - 1) + addDegree);
      final idx = semitone.clamp(0, noteCount - 1) + 1;
      _ignoreAudio(FlameAudio.play('notes/n${_pad(idx)}.mp3', volume: 0.5));
    });
  }

  /// Âm cho gem special (nốt cao nhất, to hơn).
  void playSpecial() {
    if (muted.value || !_ready) return;
    _ignoreAudio(
      FlameAudio.play('notes/n${_pad(noteCount)}.mp3', volume: 0.85),
    );
  }

  void _ignoreAudio(Future<dynamic> op) {
    unawaited(op.catchError((_) {}));
  }
}
