import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/asset_preload_coordinator.dart';
import '../../../core/game_session_controller.dart';
import '../../../core/neon_theme.dart';
import '../../../core/utils/sdk_result.dart';
import 'retry_error_state.dart';
import 'scene_wipe_geometry.dart';

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
  /// [coverDuration] is how long the [SceneTransitionPhase.covering] phase
  /// lasts and [revealDuration] the [SceneTransitionPhase.revealing] phase;
  /// the overlay uses the same values as its animation durations.
  SceneTransitionController({
    this.coverDuration = const Duration(milliseconds: 260),
    this.revealDuration = const Duration(milliseconds: 220),
  });

  /// Time spent in [SceneTransitionPhase.covering] before loading starts.
  final Duration coverDuration;

  /// Time spent in [SceneTransitionPhase.revealing] after a successful load.
  final Duration revealDuration;

  /// Current [SceneTransitionPhase]; observable so the overlay rebuilds.
  final phase = SceneTransitionPhase.idle.obs;

  /// Load progress in 0.0–1.0, reset to 0 when a [run] starts or on [cancel].
  /// The overlay shows an indeterminate spinner while it is `<= 0`.
  final progress = 0.0.obs;

  /// The failure that put the controller in [SceneTransitionPhase.error];
  /// `null` otherwise. Cleared by [run] and [cancel].
  SdkFailure<void>? lastError;

  int _tokenCounter = 0;
  int? _activeToken;
  bool _disposed = false;

  /// Whether a transition is in progress, i.e. [phase] is anything but
  /// [SceneTransitionPhase.idle] (including [SceneTransitionPhase.error]).
  bool get isActive => phase.value != SceneTransitionPhase.idle;

  /// Runs one transition: covering → [load] → revealing → idle.
  ///
  /// Returns [load]'s own result on success or failure. A [load] that throws
  /// is turned into an [SdkErrorKind.unknown] failure carrying the cause. A
  /// failure (returned or thrown) leaves the controller in
  /// [SceneTransitionPhase.error] with [lastError] set, and it stays there
  /// until [retry], [run] or [cancel]. A run that was superseded or cancelled
  /// still returns a result, but no longer changes [phase]/[progress]; if it
  /// was superseded during the cover delay the result is an
  /// [SdkErrorKind.unknown] failure and [load] is not called. After
  /// [dispose] it returns an [SdkErrorKind.unknown] failure without touching
  /// state.
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

  /// Starts a fresh [run] with [load]; typically called from the error state's
  /// retry button. It has no extra behavior of its own.
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

  /// Marks the controller disposed: a later [run] returns a failure and any
  /// in-flight [run] stops changing state. It does not reset [phase], so call
  /// [cancel] first if the barrier must come down.
  void dispose() {
    _disposed = true;
    // `phase`/`progress` are deliberately NOT closed here: the overlay observes
    // them with Obx, and when this controller is disposed before the overlay
    // unmounts, Obx's own dispose would close an already-closed Rx and throw
    // inside GetX.
  }
}

/// Fades or shape-wipes a full-screen barrier over [child] while a
/// [controller]-driven transition runs. The underlying scene cannot receive
/// pointers or semantics while the transition is active.
class SceneTransitionOverlay extends StatefulWidget {
  const SceneTransitionOverlay({
    super.key,
    required this.controller,
    required this.child,
    this.color,
    this.retryLabel,
    this.onRetry,
    this.reducedMotion,
    this.wipeShape = SceneWipeShape.fade,
    this.wipeCenter,
  });

  /// Drives which phase the overlay shows. The overlay does not own it, so the
  /// caller creates and disposes it.
  final SceneTransitionController controller;

  /// The scene underneath. It ignores pointers and is excluded from semantics
  /// for the whole time [controller] is not idle, including the reveal.
  final Widget child;

  /// Barrier color; defaults to `NeonTheme.bgMid`.
  final Color? color;

  /// Label of the retry button in the error state; forwarded to
  /// `RetryErrorState.fromSdkFailure`.
  final String? retryLabel;

  /// Called when the retry button in the error state is tapped. Usually calls
  /// [SceneTransitionController.retry]; the overlay does not do that itself.
  final Future<void> Function()? onRetry;

  /// Forces reduced motion on or off. When `null`, follows
  /// `MediaQuery.disableAnimations` (treated as off if there is no
  /// `MediaQuery`). Reduced motion removes the fade duration and makes a
  /// shape wipe jump straight to its end state instead of animating.
  final bool? reducedMotion;

  /// How the barrier covers the scene. The default [SceneWipeShape.fade]
  /// shows the barrier at full opacity from the covering phase and fades it
  /// out during the reveal; any other shape reveals it with a clipped wipe.
  final SceneWipeShape wipeShape;

  /// Origin of the wipe in the overlay's own coordinates; `null` means the
  /// center of the overlay. Ignored for [SceneWipeShape.fade].
  final Offset? wipeCenter;

  @override
  State<SceneTransitionOverlay> createState() => _SceneTransitionOverlayState();
}

/// State of [SceneTransitionOverlay]: owns the wipe [AnimationController] and
/// re-syncs it whenever the controller's phase changes.
class _SceneTransitionOverlayState extends State<SceneTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wipe;
  SceneTransitionPhase? _lastPhase;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _wipe = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasReduced = _reduced;
    _reduced = _isReduced;
    if (_reduced &&
        widget.controller.phase.value != SceneTransitionPhase.idle) {
      _wipe.value = 1;
    } else if (wasReduced && !_reduced) {
      _lastPhase = null;
    }
  }

  bool get _isReduced =>
      widget.reducedMotion ??
      MediaQuery.maybeOf(context)?.disableAnimations ??
      false;

  @override
  void didUpdateWidget(covariant SceneTransitionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _lastPhase = null;
      _wipe.value = 0;
    }
  }

  void _syncWipe(SceneTransitionPhase phase, bool reduced) {
    if (widget.wipeShape == SceneWipeShape.fade || _lastPhase == phase) return;
    _lastPhase = phase;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.wipeShape == SceneWipeShape.fade) return;
      if (reduced) {
        _wipe.value = phase == SceneTransitionPhase.idle ? 0 : 1;
      } else {
        switch (phase) {
          case SceneTransitionPhase.covering:
            _wipe.duration = widget.controller.coverDuration;
            _wipe.forward(from: 0);
          case SceneTransitionPhase.loading:
          case SceneTransitionPhase.error:
            _wipe.value = 1;
          case SceneTransitionPhase.revealing:
            _wipe.duration = widget.controller.revealDuration;
            _wipe.reverse(from: 1);
          case SceneTransitionPhase.idle:
            _wipe.value = 0;
        }
      }
    });
  }

  @override
  void dispose() {
    _wipe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _reduced = _isReduced;
    return Obx(() {
      final phase = widget.controller.phase.value;
      final active = phase != SceneTransitionPhase.idle;
      _syncWipe(phase, _reduced);

      final barrier = ColoredBox(
        color: widget.color ?? NeonTheme.bgMid,
        child: Center(
          child: phase == SceneTransitionPhase.error
              ? RetryErrorState.fromSdkFailure(
                  widget.controller.lastError!,
                  onRetry: widget.onRetry,
                  retryLabel: widget.retryLabel,
                )
              : _ProgressIndicator(controller: widget.controller),
        ),
      );
      final transitionedBarrier = widget.wipeShape == SceneWipeShape.fade
          ? AnimatedOpacity(
              opacity: phase == SceneTransitionPhase.revealing ? 0 : 1,
              duration: _reduced
                  ? Duration.zero
                  : (phase == SceneTransitionPhase.revealing
                        ? widget.controller.revealDuration
                        : widget.controller.coverDuration),
              child: barrier,
            )
          : ClipPath(
              clipper: _SceneWipeClipper(
                animation: _wipe,
                shape: widget.wipeShape,
                center: widget.wipeCenter,
              ),
              child: barrier,
            );

      return Stack(
        children: [
          ExcludeSemantics(
            excluding: active,
            child: IgnorePointer(ignoring: active, child: widget.child),
          ),
          if (active)
            Positioned.fill(
              child: Semantics(
                container: true,
                label: phase == SceneTransitionPhase.error
                    ? 'Scene transition failed'
                    : 'Loading next scene',
                child: transitionedBarrier,
              ),
            ),
        ],
      );
    });
  }
}

class _SceneWipeClipper extends CustomClipper<Path> {
  _SceneWipeClipper({
    required this.animation,
    required this.shape,
    required this.center,
  }) : super(reclip: animation);

  final Animation<double> animation;
  final SceneWipeShape shape;
  final Offset? center;

  @override
  Path getClip(Size size) => sceneWipePath(
    size: size,
    center: center ?? size.center(Offset.zero),
    progress: animation.value,
    shape: shape,
  );

  @override
  bool shouldReclip(covariant _SceneWipeClipper oldClipper) =>
      oldClipper.shape != shape || oldClipper.center != center;
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
