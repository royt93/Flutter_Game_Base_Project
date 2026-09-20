import 'package:flutter/widgets.dart';

/// Standard "modal focus trap" for an in-tree overlay panel — wraps
/// [child] (the modal's own content) in a [FocusScope] that
/// autofocuses as soon as this widget mounts (i.e. exactly when the
/// overlay it belongs to appears, matching this package's "always
/// mounted, panel nullable" convention — `NeonDialog.overlaySlot`,
/// `PauseOverlay`), and restores focus to whatever had it right BEFORE
/// this widget mounted, the moment it's removed from the tree again
/// (the overlay closing).
///
/// FEAT-82 closes exactly the gap `PauseOverlay`'s own doc comment
/// (FEAT-53) flagged: a bare `FocusScope(autofocus: true)` grabs focus
/// when a modal appears but has no way to give it back to the right
/// place when the modal's subtree gets torn down — Flutter's own
/// [FocusManager] just falls back toward the tree root instead, so a
/// keyboard/gamepad player closing a dialog would otherwise lose their
/// place entirely.
///
/// **Deterministic order**: traversal WITHIN [child] uses Flutter's own
/// default [FocusTraversalPolicy] (tree/paint order) — this widget adds
/// no custom ordering, since none of the trap/release behavior it exists
/// for depends on child order.
///
/// **Purely additive for touch-only play**: nothing here changes what a
/// tap does; the whole effect is scoped to keyboard/gamepad focus, which
/// a touch-only session never engages with (same guarantee
/// `PressableScale`'s own focus-ring doc comment gives for the same
/// reason).
class FocusTrapScope extends StatefulWidget {
  const FocusTrapScope({super.key, required this.child, this.autofocus = true});

  final Widget child;
  final bool autofocus;

  @override
  State<FocusTrapScope> createState() => _FocusTrapScopeState();
}

class _FocusTrapScopeState extends State<FocusTrapScope> {
  final FocusScopeNode _scopeNode = FocusScopeNode(debugLabel: 'FocusTrapScope');
  FocusNode? _previouslyFocused;

  @override
  void initState() {
    super.initState();
    _previouslyFocused = FocusManager.instance.primaryFocus;
    if (widget.autofocus) {
      // `FocusScope`'s own `autofocus:` flag is ADVISORY, not forceful —
      // it only claims focus if the enclosing scope has nothing else
      // focused yet, so it silently does nothing when a modal opens over
      // content that already holds focus (found by actually running
      // this: a background node kept `hasFocus == true` even after the
      // trap mounted with `autofocus: true`). Calling `requestFocus()`
      // directly on our own scope node steals it unconditionally, which
      // is the actual "trap" behavior this widget exists for. Deferred
      // to a post-frame callback so it runs after this build's own focus
      // tree is fully attached.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scopeNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    final previous = _previouslyFocused;
    // `previous.context` is non-null only while still attached to a live
    // Element — a node whose own widget was ALSO removed from the tree
    // in the meantime (e.g. the whole screen navigated away) can't
    // sensibly receive focus back; silently do nothing rather than throw.
    if (previous != null && previous.context != null) {
      // Deferred: this widget's own FocusScopeNode is still being torn
      // down synchronously during dispose() itself, so requesting focus
      // elsewhere right now would have nothing stable to hand off from.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (previous.context != null) previous.requestFocus();
      });
    }
    _scopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(node: _scopeNode, child: widget.child);
  }
}
