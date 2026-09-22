import 'dart:async';

import 'package:flame_audio/bgm.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'debug_log.dart';
import 'storage_service.dart';
import 'utils/object_pool.dart';

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
  /// ENH-79: how many `AudioPlayer`s [playSfx] keeps warm and reuses for
  /// one-shot SFX, instead of creating (and disposing) a fresh native
  /// audio channel on every single call — a combo/win-streak casual game
  /// firing 15-20 SFX/second would otherwise open that many concurrent
  /// native channels, which can stutter/drop audio on a low-end Android
  /// device. A burst beyond [sfxPoolCapacity] still always plays (never
  /// refused/dropped) — [ObjectPool] just disposes the excess instead of
  /// retaining it, so the pool's resting size never grows past this.
  AudioManager({this.sfxPoolCapacity = 6});

  final int sfxPoolCapacity;

  static const _bgmTrack = 'bkg.ogg';
  static const _prefix = 'packages/roy_casual_kit/asset/audio/';

  /// Normal bgm volume — also what a duck (see [playSfx]'s `duck` param)
  /// restores to once every ducked SFX has finished.
  static const _bgmVolume = 0.35;

  /// Bgm volume while at least one ducked SFX is playing (IDEA-45) —
  /// quieter, not silent, so the SFX reads as more important without the
  /// music fully cutting out.
  static const _bgmDuckedVolume = 0.08;

  final AudioCache _cache = AudioCache(prefix: _prefix);
  late final Bgm _bgm = Bgm(audioCache: _cache);

  /// Separate cache for one-shot SFX from a CONSUMING app's own assets
  /// (e.g. `assets/audio/tap.mp3` in the app's project) — kept apart from
  /// [_cache] (this package's own bgm asset, hardcoded to the
  /// `packages/roy_casual_kit/...` prefix) for the exact multi-tenant-prefix
  /// reason documented above for BUG-04. Uses audioplayers' own default
  /// prefix (`assets/`) so a host app's normal asset paths resolve as-is.
  final AudioCache _sfxCache = AudioCache();

  /// ENH-79: reusable `AudioPlayer`s for [playSfx] — see [sfxPoolCapacity]'s
  /// doc comment. `reset` stops any lingering playback before an instance
  /// goes back into the free list (fire-and-forget, same style as
  /// [_ignoreAudio] — nothing meaningful to await once it's back in the
  /// pool); `dispose` only ever runs for the rare instance evicted for
  /// being over capacity, or via [onClose]'s full teardown.
  late final ObjectPool<AudioPlayer> _sfxPool = ObjectPool<AudioPlayer>(
    create: () => AudioPlayer()..audioCache = _sfxCache,
    reset: (player) => unawaited(player.stop().catchError((_) {})),
    dispose: (player) {
      debugSfxDisposeCount++;
      unawaited(player.dispose().catchError((_) {}));
    },
    maxCapacity: sfxPoolCapacity,
  );

  final RxBool muted = false.obs;

  bool _bgmPlaying = false;
  bool _ready = false;

  /// Count of SFX `AudioPlayer`s actually disposed — a player is only ever
  /// disposed when [_sfxPool] evicts one over [sfxPoolCapacity] (a burst
  /// wider than the pool) or on [onClose]'s full teardown; every ordinary
  /// [playSfx] call now returns its player to the pool instead (BUG-24's
  /// original "dispose every call" guarantee is superseded by
  /// [debugSfxReleaseCount]/[debugSfxPoolActiveCount] below — those, not
  /// this, are what prove a call doesn't leak post-ENH-79).
  @visibleForTesting
  int debugSfxDisposeCount = 0;

  /// Count of [playSfx] calls that returned their player to [_sfxPool] —
  /// ENH-79's regression guard: every call (success or failure) must
  /// release exactly once, so this should always equal the number of
  /// [playSfx] calls that have finished.
  @visibleForTesting
  int debugSfxReleaseCount = 0;

  /// How many SFX players [_sfxPool] currently considers "in use" — must
  /// be back to 0 once every in-flight [playSfx] call has finished; a
  /// stuck non-zero value would mean a call acquired a player and never
  /// released it.
  @visibleForTesting
  int get debugSfxPoolActiveCount => _sfxPool.activeCount;

  /// Total `AudioPlayer`s [_sfxPool] has ever created. For SEQUENTIAL
  /// [playSfx] calls (each one's player released before the next starts —
  /// the realistic staggered-combo-SFX case [sfxPoolCapacity] is about)
  /// this stays at 1 no matter how many calls run, proving reuse actually
  /// happens instead of "one new player per call" (the pre-ENH-79
  /// behavior). For genuinely SIMULTANEOUS calls (all in flight at once,
  /// e.g. via `Future.wait` with none released yet) this can still exceed
  /// [sfxPoolCapacity] — that many native channels really are needed at
  /// that exact instant regardless of pooling; [debugSfxPoolFreeCount] is
  /// what stays bounded afterward (the excess gets disposed, not
  /// retained).
  @visibleForTesting
  int get debugSfxTotalCreated => _sfxPool.totalCreated;

  /// How many SFX players [_sfxPool] is currently holding onto, idle,
  /// ready for the next [playSfx] call — bounded by [sfxPoolCapacity] even
  /// right after a burst wider than that (the excess gets disposed on
  /// release instead of retained, see [_sfxPool]'s doc comment).
  @visibleForTesting
  int get debugSfxPoolFreeCount => _sfxPool.freeCount;

  // IDEA-45: number of currently-playing ducked SFX. Bgm volume only drops
  // on the FIRST concurrent duck and only restores once the LAST one ends —
  // a counter (not a bool) so overlapping ducked SFX never leave bgm stuck
  // quiet after the first one finishes while others are still playing.
  int _duckCount = 0;

  /// Number of currently-playing ducked SFX (0 when bgm is at its normal
  /// volume) — public (not test-only) since a caller's own UI may want to
  /// show a small indicator while bgm is ducked.
  int get duckCount => _duckCount;

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
    _ignoreAudio(_bgm.play(_bgmTrack, volume: _bgmVolume));
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

  // IDEA-45: drops bgm volume on the first concurrent duck, restores it
  // once the last one ends (see _duckCount's doc comment). No-ops if bgm
  // isn't actually playing — nothing to duck.
  void _duckBgm() {
    if (_duckCount == 0 && _bgmPlaying) {
      dlog('audio ducking: bgm volume -> $_bgmDuckedVolume');
      _ignoreAudio(_bgm.audioPlayer.setVolume(_bgmDuckedVolume));
    }
    _duckCount++;
  }

  // Not gated on `muted` (unlike startBgm/pauseBgm/resumeBgm): setting
  // volume while muted/paused is harmless, and gating it would leave bgm
  // stuck at the ducked volume forever if the user muted mid-duck and later
  // unmuted, since that later resume has no other trigger to restore it.
  void _unduckBgm() {
    if (_duckCount > 0) _duckCount--;
    if (_duckCount == 0 && _bgmPlaying) {
      dlog('audio ducking: bgm volume -> $_bgmVolume (restored)');
      _ignoreAudio(_bgm.audioPlayer.setVolume(_bgmVolume));
    }
  }

  /// Plays a one-shot SFX from a CONSUMING app's own assets (e.g.
  /// `assets/audio/tap.mp3`), respecting the same [muted] state as the bgm
  /// track. No-ops immediately when muted — doesn't even touch the audio
  /// cache. Borrows an [AudioPlayer] from [_sfxPool] (ENH-79) instead of
  /// creating+disposing a fresh one every call, so rapid overlapping taps
  /// each still play independently (up to [sfxPoolCapacity] concurrently
  /// pooled, more than that still plays — just via a short-lived extra
  /// instance instead of a pooled one) without opening unbounded native
  /// audio channels during a combo/SFX burst.
  ///
  /// [duck] = true (IDEA-45) temporarily lowers the bgm volume for the
  /// duration of this SFX (e.g. a win/lose stinger that should read as more
  /// important than the music) — restored once this SFX finishes, or once
  /// every OTHER concurrently-playing ducked SFX also finishes, whichever is
  /// later.
  Future<void> playSfx(
    String fileName, {
    double volume = 1.0,
    bool duck = false,
  }) async {
    if (muted.value) return;
    if (duck) _duckBgm();
    // Acquired INSIDE the try (not before it) — the pool's `create`
    // callback (a fresh AudioPlayer constructor) can throw/reject (e.g. no
    // audio plugin available in a test), and that must be caught same as a
    // play() failure. Stays in scope for `finally` via this nullable local
    // so a failed acquire (player still null) has nothing to release.
    AudioPlayer? player;
    try {
      player = _sfxPool.acquire();
      await player.play(AssetSource(fileName), volume: volume);
      // Wait for the SFX to actually finish before releasing (BUG-24) —
      // releasing right after play() returns would cut the sound off,
      // since play() resolves once playback STARTS, not once it ends.
      // Subscribed only AFTER play() succeeds (not before): AudioPlayer's
      // own internal creation can fail (e.g. no audio plugin available, as
      // in a plain unit test), and subscribing to onPlayerComplete first
      // observably interferes with that failure reaching this catch block
      // — confirmed by reverting just this ordering and watching the same
      // existing test throw uncaught. A timeout is a safety net for a
      // platform that never fires onPlayerComplete (or a hung/looping
      // asset) — better to leak this one wait than never release at all.
      await player.onPlayerComplete.first.timeout(const Duration(seconds: 30));
    } catch (e) {
      // no audio backend (tests), missing asset, or the completion timeout
      // above → swallow, don't crash
      dlog('playSfx failed for $fileName: $e');
    } finally {
      if (duck) _unduckBgm();
      if (player != null) {
        // Synchronous, not awaited — the pool's own bookkeeping
        // (activeCount/totalCreated) updates immediately, which is what
        // debugSfxPoolActiveCount/debugSfxTotalCreated rely on being
        // deterministically testable right after this call returns. Any
        // actual native stop()/dispose() the pool triggers internally is
        // fire-and-forget (see _sfxPool's `reset`/`dispose` callbacks).
        //
        // Guarded: onClose() (see below) can run _sfxPool.disposeAll()
        // while THIS call is still in flight — that already disposes
        // `player` out from under it, so release() would otherwise throw
        // "not currently active" on top of whatever else was going on.
        // Best-effort, same as every other cleanup op in this class.
        try {
          _sfxPool.release(player);
        } catch (_) {
          // ignore — player was already torn down by onClose().
        }
        debugSfxReleaseCount++;
      }
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

  // BUG-24: Bgm.dispose() releases its AudioPlayer AND unregisters the
  // WidgetsBindingObserver it installed in its constructor — without this,
  // a non-permanent AudioManager (Get.delete'd, e.g. a test tearing down a
  // registered service) leaks both.
  @override
  void onClose() {
    // .catchError: _bgm.dispose() itself can throw the same way an SFX
    // player's dispose can (see playSfx) — e.g. onClose() running before
    // `_bgm` was ever successfully used lazily constructs it here for the
    // first time, with no guarantee its own creation succeeded.
    unawaited(_bgm.dispose().catchError((_) {}));
    // ENH-79: dispose every pooled/active SFX player — a permanent
    // AudioManager never reaches this in normal app life, but a
    // non-permanent one (test teardown) must not leak the pool's warm
    // instances.
    _sfxPool.disposeAll();
    super.onClose();
  }
}
