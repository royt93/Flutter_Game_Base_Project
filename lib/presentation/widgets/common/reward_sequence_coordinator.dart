import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';

enum RewardSequenceStep { initial, banner, content, counter, fx, ready }

class RewardSequenceController extends ChangeNotifier {
  RewardSequenceStep _step = RewardSequenceStep.initial;

  RewardSequenceStep get step => _step;
  bool get isReady => _step == RewardSequenceStep.ready;

  void advanceTo(RewardSequenceStep next) {
    if (_step == next) return;
    _step = next;
    notifyListeners();
  }

  void skipToEnd() => advanceTo(RewardSequenceStep.ready);

  void reset() => advanceTo(RewardSequenceStep.initial);
}

/// Sequences reward slots, with optional tap-to-skip and Reduce Motion support.
class RewardSequenceCoordinator extends StatefulWidget {
  RewardSequenceCoordinator({
    super.key,
    this.banner,
    this.content,
    this.counter,
    this.fx,
    this.actionButton,
    this.controller,
    this.stepDuration = const Duration(milliseconds: 300),
    this.autoStart = true,
    this.allowTapToSkip = true,
    this.onSequenceComplete,
  }) {
    if (stepDuration <= Duration.zero) {
      throw ArgumentError.value(
        stepDuration,
        'stepDuration',
        'must be positive',
      );
    }
  }

  final Widget? banner;
  final Widget? content;
  final Widget? counter;
  final Widget? fx;
  final Widget? actionButton;
  final RewardSequenceController? controller;
  final Duration stepDuration;
  final bool autoStart;
  final bool allowTapToSkip;
  final VoidCallback? onSequenceComplete;

  @override
  State<RewardSequenceCoordinator> createState() =>
      _RewardSequenceCoordinatorState();
}

class _RewardSequenceCoordinatorState extends State<RewardSequenceCoordinator> {
  RewardSequenceController? _ownedController;

  RewardSequenceController get _internalController =>
      _ownedController ??= RewardSequenceController();
  Timer? _timer;
  bool _completedFired = false;
  int _completionToken = 0;
  RewardSequenceStep _observedStep = RewardSequenceStep.initial;

  RewardSequenceController get _controller =>
      widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    _observedStep = _controller.step;
    _controller.addListener(_onControllerUpdate);
    if (_controller.isReady) {
      _queueCompletion();
    } else if (widget.autoStart) {
      _scheduleStart();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NeonTheme.reducedMotion(context) && !_controller.isReady) {
      _cancelTimer();
      _controller.skipToEnd();
    }
  }

  @override
  void didUpdateWidget(covariant RewardSequenceCoordinator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerUpdate);
      if (oldWidget.controller == null) {
        _internalController.removeListener(_onControllerUpdate);
      }
      _cancelTimer();
      _completedFired = false;
      _completionToken++;
      _observedStep = _controller.step;
      _controller.addListener(_onControllerUpdate);
      if (_controller.isReady) {
        _queueCompletion();
      } else if (widget.autoStart) {
        _scheduleStart();
      }
    }
    if (oldWidget.autoStart != widget.autoStart) {
      if (!widget.autoStart) {
        _cancelTimer();
      } else if (!_controller.isReady) {
        _scheduleStart();
      }
    } else if (oldWidget.stepDuration != widget.stepDuration &&
        _timer != null) {
      _scheduleNext();
    }
  }

  void _scheduleStart() {
    _cancelTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.autoStart || _controller.isReady) return;
      _startSequence();
    });
  }

  void _startSequence() {
    if (!mounted || _controller.isReady) return;
    if (NeonTheme.reducedMotion(context)) {
      _controller.skipToEnd();
    } else if (_controller.step == RewardSequenceStep.initial) {
      _advanceNext();
    } else {
      _scheduleNext();
    }
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleNext() {
    _cancelTimer();
    if (!mounted || !widget.autoStart || _controller.isReady) return;
    _timer = Timer(widget.stepDuration, _advanceNext);
  }

  void _advanceNext() {
    _cancelTimer();
    if (!mounted || _controller.isReady) return;
    final next = switch (_controller.step) {
      RewardSequenceStep.initial =>
        widget.banner != null ? RewardSequenceStep.banner : _nextAfterBanner(),
      RewardSequenceStep.banner => _nextAfterBanner(),
      RewardSequenceStep.content => _nextAfterContent(),
      RewardSequenceStep.counter => _nextAfterCounter(),
      RewardSequenceStep.fx => RewardSequenceStep.ready,
      RewardSequenceStep.ready => RewardSequenceStep.ready,
    };
    _controller.advanceTo(next);
    if (next != RewardSequenceStep.ready) _scheduleNext();
  }

  RewardSequenceStep _nextAfterBanner() =>
      widget.content != null ? RewardSequenceStep.content : _nextAfterContent();

  RewardSequenceStep _nextAfterContent() =>
      widget.counter != null ? RewardSequenceStep.counter : _nextAfterCounter();

  RewardSequenceStep _nextAfterCounter() =>
      widget.fx != null ? RewardSequenceStep.fx : RewardSequenceStep.ready;

  void _queueCompletion() {
    if (_completedFired || widget.onSequenceComplete == null) return;
    _completedFired = true;
    final token = ++_completionToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && token == _completionToken && _controller.isReady) {
        widget.onSequenceComplete?.call();
      }
    });
  }

  void _onControllerUpdate() {
    final current = _controller.step;
    if (current == RewardSequenceStep.initial &&
        _observedStep != RewardSequenceStep.initial) {
      _completedFired = false;
      _completionToken++;
      _cancelTimer();
      if (widget.autoStart) _scheduleStart();
    } else if (current == RewardSequenceStep.ready) {
      _cancelTimer();
      _queueCompletion();
    }
    _observedStep = current;
    if (mounted) setState(() {});
  }

  void _handleTapToSkip() {
    if (!widget.allowTapToSkip || _controller.isReady) return;
    _cancelTimer();
    _controller.skipToEnd();
  }

  Duration _motionDuration(BuildContext context) =>
      NeonTheme.motionDuration(context, NeonTheme.motionDefault);

  Widget _stage({
    required bool visible,
    required Widget child,
    required Duration duration,
    double hiddenScale = 1,
  }) {
    return ExcludeSemantics(
      excluding: !visible,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSwitcher(
          duration: duration,
          reverseDuration: duration,
          switchInCurve: NeonTheme.curveSurface,
          switchOutCurve: NeonTheme.curveSurface,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: hiddenScale, end: 1).animate(
                CurvedAnimation(parent: animation, curve: NeonTheme.curvePop),
              ),
              child: child,
            ),
          ),
          child: visible
              ? KeyedSubtree(key: const ValueKey(true), child: child)
              : const SizedBox.shrink(key: ValueKey(false)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cancelTimer();
    _completionToken++;
    widget.controller?.removeListener(_onControllerUpdate);
    final owned = _ownedController;
    if (owned != null) {
      owned.removeListener(_onControllerUpdate);
      owned.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _controller.step;
    final showBanner = step.index >= RewardSequenceStep.banner.index;
    final showContent = step.index >= RewardSequenceStep.content.index;
    final showCounter = step.index >= RewardSequenceStep.counter.index;
    final showFx = step.index >= RewardSequenceStep.fx.index;
    final showAction = step == RewardSequenceStep.ready;
    final duration = _motionDuration(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.allowTapToSkip && !showAction ? _handleTapToSkip : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.fx != null)
            _stage(visible: showFx, duration: duration, child: widget.fx!),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.banner != null)
                _stage(
                  visible: showBanner,
                  duration: duration,
                  hiddenScale: 0.8,
                  child: widget.banner!,
                ),
              if (widget.content != null) ...[
                const SizedBox(height: NeonTheme.s16),
                _stage(
                  visible: showContent,
                  duration: duration,
                  hiddenScale: 0.7,
                  child: widget.content!,
                ),
              ],
              if (widget.counter != null) ...[
                const SizedBox(height: NeonTheme.s16),
                _stage(
                  visible: showCounter,
                  duration: duration,
                  child: widget.counter!,
                ),
              ],
              if (widget.actionButton != null) ...[
                const SizedBox(height: NeonTheme.s24),
                _stage(
                  visible: showAction,
                  duration: duration,
                  hiddenScale: 0.85,
                  child: widget.actionButton!,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
