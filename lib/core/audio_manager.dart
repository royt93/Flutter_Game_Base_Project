import 'dart:async';

import 'package:flame_audio/bgm.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'debug_log.dart';
import 'storage_service.dart';

/// Manages the background music: a single track (`asset/audio/bkg.ogg`) + mute.
///
/// Uses its own private [AudioCache]/[Bgm] pair instead of the shared
/// `FlameAudio.audioCache`/`FlameAudio.bgm` globals (BUG-04): those globals
/// are also what `FlameAudio.play(...)` uses, so a consuming app playing its
/// own SFX through that same top-level helper would have its asset lookups
/// silently redirected into this package's own audio folder the moment this
/// class touched `FlameAudio.audioCache.prefix`. A private pair keeps the
/// kit's bgm fully independent of whatever the app does with `FlameAudio`.
class AudioManager extends GetxService {
  static const _bgmTrack = 'bkg.ogg';
  static const _prefix = 'packages/roy_casual_kit/asset/audio/';

  final AudioCache _cache = AudioCache(prefix: _prefix);
  late final Bgm _bgm = Bgm(audioCache: _cache);

  /// Separate cache for one-shot SFX from a CONSUMING app's own assets
  /// (e.g. `assets/audio/tap.mp3` in the app's project) — kept apart from
  /// [_cache] (this package's own bgm asset, hardcoded to the
  /// `packages/roy_casual_kit/...` prefix) for the exact multi-tenant-prefix
  /// reason documented above for BUG-04. Uses audioplayers' own default
  /// prefix (`assets/`) so a host app's normal asset paths resolve as-is.
  final AudioCache _sfxCache = AudioCache();

  final RxBool muted = false.obs;

  bool _bgmPlaying = false;
  bool _ready = false;

  /// Gets the instance if already registered (safe to call from game/widget tests).
  static AudioManager? get maybe =>
      Get.isRegistered<AudioManager>() ? Get.find<AudioManager>() : null;

  /// Exposes the private cache's prefix for tests — proves this instance
  /// never touches the shared `FlameAudio.audioCache` global.
  @visibleForTesting
  String get debugAudioCachePrefix => _cache.prefix;

  /// Exposes the SFX cache's prefix for tests — proves it's a separate
  /// instance from the bgm [_cache], not locked to this package's own asset
  /// location.
  @visibleForTesting
  String get debugSfxCachePrefix => _sfxCache.prefix;

  Future<void> init() async {
    // Restore the saved mute state before loading audio
    muted.value = StorageService.to.getBool(StorageKeys.audioMuted, def: false);

    try {
      await _cache.loadAll([_bgmTrack]);
      _ready = true;
    } catch (_) {
      // environment has no audio (e.g. some tests) → ignore, don't crash
      _ready = false;
    }
  }

  void startBgm() {
    if (!_ready || muted.value || _bgmPlaying) return;
    _ignoreAudio(_bgm.play(_bgmTrack, volume: 0.35));
    _bgmPlaying = true;
  }

  void stopBgm() {
    if (!_bgmPlaying) return;
    _ignoreAudio(_bgm.stop());
    _bgmPlaying = false;
  }

  /// Pauses the music when the app goes to background (lifecycle
  /// paused/inactive/hidden). Keeps `_bgmPlaying = true` so it knows there's
  /// music to resume when coming back.
  void pauseBgm() {
    if (!_bgmPlaying || muted.value) return;
    _ignoreAudio(_bgm.pause());
  }

  /// Resumes playback when the app returns to foreground (resumed). Does
  /// not resume if the user has muted.
  void resumeBgm() {
    if (!_bgmPlaying || muted.value) return;
    _ignoreAudio(_bgm.resume());
  }

  /// Plays a one-shot SFX from a CONSUMING app's own assets (e.g.
  /// `assets/audio/tap.mp3`), respecting the same [muted] state as the bgm
  /// track. No-ops immediately when muted — doesn't even touch the audio
  /// cache. A fresh [AudioPlayer] is used per call (via [_sfxCache]) so
  /// rapid overlapping taps each play independently instead of cutting each
  /// other off.
  Future<void> playSfx(String fileName, {double volume = 1.0}) async {
    if (muted.value) return;
    try {
      final player = AudioPlayer()..audioCache = _sfxCache;
      await player.play(AssetSource(fileName), volume: volume);
    } catch (e) {
      // no audio backend (tests) or missing asset → swallow, don't crash
      dlog('playSfx failed for $fileName: $e');
    }
  }

  void toggleMute() {
    muted.toggle();
    // Lưu trạng thái mute vào disk để giữ qua các lần khởi động
    unawaited(StorageService.to.setBool(StorageKeys.audioMuted, muted.value));
    if (muted.value) {
      _ignoreAudio(_bgm.pause());
    } else if (_bgmPlaying) {
      // BGM đang được track là "đang chạy" (chỉ bị pause bởi mute) → resume
      _ignoreAudio(_bgm.resume());
    } else {
      // BGM chưa start (mute trước khi vào game) → start
      startBgm();
    }
  }

  // flame_audio's Bgm.play/pause/resume/stop all resolve to Future<void> —
  // there's nothing to inspect/dispose on completion, just swallow errors so
  // a transient audio failure never crashes a fire-and-forget call site.
  void _ignoreAudio(Future<void> op) {
    unawaited(op.catchError((_) {}));
  }
}
