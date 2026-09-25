import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/asset_preload_coordinator.dart';
import '../../../core/game_session_controller.dart';
import '../../../core/neon_theme.dart';
import '../../../core/utils/sdk_result.dart';
import 'retry_error_state.dart';

/// Lifecycle of one scene transition: [idle] (no overlay, old/new scene
/// interactive) → [covering] (fading a barrier in over the old scene) →
/// [loading] (barrier up, showing progress) → [revealing] (fading the
/// barrier back out over the new scene) → back to [idle]; or [error] instead
/// of [revealing] if the load failed.
enum SceneTransitionPhase { idle, covering, loading, revealing, error }

/// A transition's load step: does the real work (asset preload, screen
/// setup, ...) and reports progress via [onProgress] (0.0–1.0) as it goes.
typedef SceneTransitionLoad =
    Future<SdkResult<void>> Function(void Function(double progress) onProgress);

/// Pure state machine driving [SceneTransitionOverlay] — no `Animation`/
/// `BuildContext` here, so it's unit-testable without pumping a widget tree.
///
/// **Token-guarded**: every [run] mints a new token and only that token's
/// continuation is allowed to mutate [phase]/[progress]/[lastError] — a
/// previous, still-in-flight [run] whose token has been superseded by a
/// newer [run] (rapid re-navigation) silently drops its own late completion
/// instead of stomping the newer transition's state. The same guard makes
/// [cancel] and [dispose] immediately stop any in-flight [run] from mutating
/// state further, so a load that finishes after cancel/dispose can never
/// leave a stale pointer-blocking barrier up.
class SceneTransitionController {
  SceneTransitionController({
    this.coverDuration = const Duration(milliseconds: 260),
    this.revealDuration = const Duration(milliseconds: 220),
  });

  final Duration coverDuration;
  final Duration revealDuration;

  final phase = SceneTransitionPhase.idle.obs;
  final progress = 0.0.obs;
  SdkFailure<void>? lastError;

  int _tokenCounter = 0;
  int? _activeToken;
  bool _disposed = false;

  bool get isActive => phase.value != SceneTransitionPhase.idle;

  Future<SdkResult<void>> run(SceneTransitionLoad load) async {
    if (_disposed) {
      return const SdkFailure(
        kind: SdkErrorKind.unknown,
        message: 'SceneTransitionController already disposed',
      );
    }

    final token = ++_tokenCounter;
    _activeToken = token;
    progress.value = 0.0;
    lastError = null;
    phase.value = SceneTransitionPhase.covering;

    await Future<void>.delayed(coverDuration);
    if (!_isCurrent(token)) {
      return const SdkFailure(
        kind: SdkErrorKind.unknown,
        message: 'Transition superseded before loading started',
      );
    }

    phase.value = SceneTransitionPhase.loading;
    final SdkResult<void> result;
    try {
      result = await load((value) {
        if (_isCurrent(token)) progress.value = value.clamp(0.0, 1.0);
      });
    } catch (error, stack) {
      final failure = SdkFailure<void>(
        kind: SdkErrorKind.unknown,
        message: 'Scene transition load callback threw: $error',
        cause: error,
        stackTrace: stack,
      );
      if (!_isCurrent(token)) return failure;
      lastError = failure;
      phase.value = SceneTransitionPhase.error;
      return failure;
    }

    if (!_isCurrent(token)) return result;

    if (result is SdkFailure<void>) {
      lastError = result;
      phase.value = SceneTransitionPhase.error;
      return result;
    }

    phase.value = SceneTransitionPhase.revealing;
    await Future<void>.delayed(revealDuration);
    if (_isCurrent(token)) {
      phase.value = SceneTransitionPhase.idle;
      _activeToken = null;
    }
    return result;
  }

  Future<SdkResult<void>> retry(SceneTransitionLoad load) => run(load);

  /// Immediately drops back to [idle] and invalidates the active token — an
  /// in-flight [run] finishing later (success or failure) becomes a no-op.
  void cancel() {
    _activeToken = null;
    phase.value = SceneTransitionPhase.idle;
    progress.value = 0.0;
    lastError = null;
  }

  /// Wires this controller's [run] to a real [AssetPreloadCoordinator]
  /// (FEAT-47) + [GameSessionController] (FEAT-41): [preload]'s progress
  /// feeds this controller's [progress], and a successful preload calls
  /// [GameSessionController.markReady]+[GameSessionController.start] so the
  /// session phase and the transition phase land in sync.
  Future<SdkResult<void>> runWithAssetPreload({
    required AssetPreloadCoordinator preload,
    required List<AssetManifestItem> manifest,
    GameSessionController? session,
  }) {
    return run((onProgress) async {
      final sub = preload.progress.listen(onProgress);
      try {
        final result = await preload.preload(manifest);
        if (result is SdkSuccess<void>) {
          session?.markReady();
          session?.start();
        }
        return result;
      } finally {
        sub.cancel();
      }
    });
  }

  bool _isCurrent(int token) => !_disposed && _activeToken == token;

  void dispose() {
    _disposed = true;
  }
}

/// Fades a full-screen barrier over [child] while a [controller]-driven
/// transition runs, showing progress while loading or [RetryErrorState] on
/// failure — see `CLAUDE.md`'s "Dialog pattern" note for why this is an
/// in-tree overlay (works over a full-screen Flame `GameWidget`) rather than
/// a pushed route, same reasoning as `NeonDialog`.
///
/// The underlying [child] is excluded from the semantics tree and ignores
/// pointer events for the whole time [controller.phase] isn't [idle] — so a
/// stray tap/screen-reader focus can never reach the scene being replaced,
/// and the barrier is released the instant [controller] returns to [idle]
/// (via a successful reveal or [SceneTransitionController.cancel]) — it can
/// never get stuck blocking pointer input.
///
/// Respects reduced-motion: when [reducedMotion] is `true` (or, if left
/// `null`, when `MediaQuery.of(context).disableAnimations` is `true`), the
/// cover/reveal fade duration collapses to zero instead of animating.
class SceneTransitionOverlay extends StatelessWidget {
  const SceneTransitionOverlay({
    super.key,
    required this.controller,
    required this.child,
    this.color,
    this.retryLabel,
    this.onRetry,
    this.reducedMotion,
  });

  final SceneTransitionController controller;
  final Widget child;
  final Color? color;
  final String? retryLabel;

  /// Re-runs the failed load. Left `null` hides the retry button (see
  /// [RetryErrorState.onRetry]) — the barrier still lifts via [cancel] on
  /// the controller in that case, it just isn't offered here.
  final Future<void> Function()? onRetry;
  final bool? reducedMotion;

  @override
  Widget build(BuildContext context) {
    final reduced =
        reducedMotion ??
        MediaQuery.maybeOf(context)?.disableAnimations ??
        false;

    return Obx(() {
      final phase = controller.phase.value;
      final active = phase != SceneTransitionPhase.idle;

      return Stack(
        children: [
          ExcludeSemantics(
            excluding: active,
            child: IgnorePointer(ignoring: active, child: child),
          ),
          if (active)
            Positioned.fill(
              child: Semantics(
                container: true,
                label: phase == SceneTransitionPhase.error
                    ? 'Scene transition failed'
                    : 'Loading next scene',
                child: AnimatedOpacity(
                  opacity: phase == SceneTransitionPhase.revealing ? 0.0 : 1.0,
                  duration: reduced
                      ? Duration.zero
                      : (phase == SceneTransitionPhase.revealing
                            ? controller.revealDuration
                            : controller.coverDuration),
                  child: ColoredBox(
                    color: color ?? NeonTheme.bgMid,
                    child: Center(
                      child: phase == SceneTransitionPhase.error
                          ? RetryErrorState.fromSdkFailure(
                              controller.lastError!,
                              onRetry: onRetry,
                              retryLabel: retryLabel,
                            )
                          : _ProgressIndicator(controller: controller),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({required this.controller});

  final SceneTransitionController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final value = controller.progress.value;
      return CircularProgressIndicator(
        value: value <= 0.0 ? null : value,
        color: Colors.white,
      );
    });
  }
}
