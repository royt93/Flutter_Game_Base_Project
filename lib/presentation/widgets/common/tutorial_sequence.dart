import 'package:flutter/material.dart';

import '../../../core/neon_theme.dart';
import 'spotlight_overlay.dart';

/// One step of a [TutorialSequence] — same fields as [SpotlightOverlay]
/// (which this composes, not reimplements), minus [SpotlightOverlay.onDismiss]
/// (the sequence supplies that itself, wired to advance to the next step).
class TutorialStep {
  const TutorialStep({
    required this.targetKey,
    required this.message,
    this.title,
    this.buttonLabel = 'Got it',
    this.color,
  });

  final GlobalKey targetKey;
  final String message;
  final String? title;
  final String buttonLabel;
  final Color? color;
}

/// Plain `ChangeNotifier` the caller creates and owns (like a
/// `TextEditingController`, same pattern as [ScreenShakeController] in
/// `screen_shake.dart`) — drives which step of a [TutorialSequence] is
/// showing, if any.
class TutorialSequenceController extends ChangeNotifier {
  List<TutorialStep> _steps = const [];
  int _index = -1;

  /// The step currently being shown, or null if the sequence isn't active
  /// (never started, or already finished/skipped).
  TutorialStep? get currentStep =>
      _index >= 0 && _index < _steps.length ? _steps[_index] : null;

  bool get isActive => _index >= 0 && _index < _steps.length;

  /// 0-based index of [currentStep] within the running sequence. Only
  /// meaningful while [isActive] (ENH-48, drives the "Step X/Y" indicator).
  int get currentIndex => _index;

  /// Total steps in the running sequence. Only meaningful while [isActive].
  int get stepCount => _steps.length;

  /// Starts a new sequence at its first step. A call with an empty [steps]
  /// list is a no-op (nothing to show).
  void start(List<TutorialStep> steps) {
    if (steps.isEmpty) return;
    _steps = steps;
    _index = 0;
    notifyListeners();
  }

  /// Advances to the next step, or ends the sequence if the current step
  /// was the last one.
  void next() {
    if (!isActive) return;
    if (_index + 1 >= _steps.length) {
      skip();
      return;
    }
    _index++;
    notifyListeners();
  }

  /// Ends the sequence immediately, regardless of which step it's on.
  void skip() {
    if (_index < 0) return;
    _index = -1;
    _steps = const [];
    notifyListeners();
  }
}

/// Orchestrates a multi-step onboarding tutorial by showing one
/// [SpotlightOverlay] at a time for whatever step [controller] is
/// currently on — composes [SpotlightOverlay] rather than reimplementing
/// its highlight/callout logic; this widget is purely the step-advancing
/// state machine around it.
///
/// Wrap the screen's content in this once; call `controller.start(steps)`
/// whenever the tutorial should begin (e.g. on first app launch).
class TutorialSequence extends StatefulWidget {
  const TutorialSequence({
    super.key,
    required this.controller,
    required this.child,
    this.onComplete,
    this.showSkip = true,
    this.skipLabel = 'Skip',
  });

  final TutorialSequenceController controller;
  final Widget child;

  /// Called once the sequence ends, however it ended (last step dismissed,
  /// or [TutorialSequenceController.skip] called) — a good place to
  /// persist "tutorial seen" so it doesn't show again.
  final VoidCallback? onComplete;

  /// Shows a "Skip" action in every step's overlay that ends the whole
  /// sequence immediately via [TutorialSequenceController.skip] (ENH-48).
  /// Set false to force the player through every step one at a time.
  final bool showSkip;

  /// Label for the skip action, only shown when [showSkip] is true.
  final String skipLabel;

  @override
  State<TutorialSequence> createState() => _TutorialSequenceState();
}

class _TutorialSequenceState extends State<TutorialSequence> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant TutorialSequence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    if (!widget.controller.isActive) widget.onComplete?.call();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.controller.currentStep;
    return Stack(
      children: [
        widget.child,
        if (step != null)
          SpotlightOverlay(
            targetKey: step.targetKey,
            message: step.message,
            title: step.title,
            buttonLabel: step.buttonLabel,
            color: step.color ?? NeonTheme.purple,
            onDismiss: widget.controller.next,
            // ENH-48: "Step X/Y" so the player knows how much is left, and
            // an optional early-exit Skip action (the controller already
            // had skip() — this just wires a button to it).
            stepIndicator:
                'Step ${widget.controller.currentIndex + 1}/'
                '${widget.controller.stepCount}',
            onSkip: widget.showSkip ? widget.controller.skip : null,
            skipLabel: widget.skipLabel,
          ),
      ],
    );
  }
}
