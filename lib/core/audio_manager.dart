import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:get/get.dart';
import 'storage_service.dart';

/// Manages the background music: a single track (`asset/audio/bkg.ogg`) + mute.
class AudioManager extends GetxService {
  static const _bgmTrack = 'bkg.ogg';

  final RxBool muted = false.obs;

  bool _bgmPlaying = false;
  bool _ready = false;

  /// Gets the instance if already registered (safe to call from game/widget tests).
  static AudioManager? get maybe =>
      Get.isRegistered<AudioManager>() ? Get.find<AudioManager>() : null;

  Future<void> init() async {
    // Restore the saved mute state before loading audio
    muted.value = StorageService.to.getBool(StorageKeys.audioMuted, def: false);

    FlameAudio.audioCache.prefix = 'asset/audio/';
    try {
      await FlameAudio.audioCache.loadAll([_bgmTrack]);
      _ready = true;
    } catch (_) {
      // environment has no audio (e.g. some tests) → ignore, don't crash
      _ready = false;
    }
  }

  void startBgm() {
    if (!_ready || muted.value || _bgmPlaying) return;
    _ignoreAudio(FlameAudio.bgm.play(_bgmTrack, volume: 0.35));
    _bgmPlaying = true;
  }

  void stopBgm() {
    if (!_bgmPlaying) return;
    _ignoreAudio(FlameAudio.bgm.stop());
    _bgmPlaying = false;
  }

  /// Pauses the music when the app goes to background (lifecycle
  /// paused/inactive/hidden). Keeps `_bgmPlaying = true` so it knows there's
  /// music to resume when coming back.
  void pauseBgm() {
    if (!_bgmPlaying || muted.value) return;
    _ignoreAudio(FlameAudio.bgm.pause());
  }

  /// Resumes playback when the app returns to foreground (resumed). Does
  /// not resume if the user has muted.
  void resumeBgm() {
    if (!_bgmPlaying || muted.value) return;
    _ignoreAudio(FlameAudio.bgm.resume());
  }

  void toggleMute() {
    muted.toggle();
    // Lưu trạng thái mute vào disk để giữ qua các lần khởi động
    unawaited(StorageService.to.setBool(StorageKeys.audioMuted, muted.value));
    if (muted.value) {
      _ignoreAudio(FlameAudio.bgm.pause());
    } else if (_bgmPlaying) {
      // BGM đang được track là "đang chạy" (chỉ bị pause bởi mute) → resume
      _ignoreAudio(FlameAudio.bgm.resume());
    } else {
      // BGM chưa start (mute trước khi vào game) → start
      startBgm();
    }
  }

  void _ignoreAudio(Future<dynamic> op) {
    unawaited(
      op
          .then((value) {
            if (value is AudioPlayer) {
              unawaited(
                value.onPlayerComplete.first
                    .timeout(const Duration(seconds: 5), onTimeout: () {})
                    .whenComplete(value.dispose)
                    .catchError((_) {}),
              );
            }
          })
          .catchError((_) {}),
    );
  }
}
