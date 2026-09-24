import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/consent_state_service.dart';
import '../../../core/neon_theme.dart';
import '../../../core/onboarding_coordinator_service.dart';
import '../neon_dialog.dart';

/// Wraps [child] and shows a one-time GDPR/CCPA-style consent banner
/// (IDEA-69) before any [ConsentCategory] the app might gate analytics or
/// personalization behind is ever decided — `ConsentStateService` has the
/// state (`grant`/`deny`/`reset`) and `ConsentGatedAnalyticsProvider` has
/// the enforcement, but nothing in the kit actually asked the player until
/// this widget.
///
/// MVP scope: 1 "accept all / decline all" pair covering every
/// [ConsentCategory] at once, not a per-category picker — a consumer app
/// that needs finer-grained consent should call [ConsentStateService.grant]
/// / [ConsentStateService.deny] directly per category instead of using this
/// widget.
///
/// Shown at most once: gated behind
/// [OnboardingCoordinatorService.isFlowSeen]/[OnboardingCoordinatorService.markFlowSeen]
/// (registered via [OnboardingCoordinatorService.registerFlow]) rather than
/// a banner-local flag — same "reuse the existing seen-tracker" convention
/// `SaveHealthCard` (IDEA-59) already follows for `save_integrity.dart`. If
/// no `OnboardingCoordinatorService` is registered, the banner still shows
/// (can't know it was already seen) but can't remember that decision across
/// restarts — same defensive "no crash, degrade gracefully" convention as
/// `AchievementUnlockListener` for a missing service.
///
/// Dismissing without tapping a button (Android back/gesture pops the
/// topmost route regardless of the dialog's own `dismissible` flag — see
/// `showConfirmDialog`'s doc for why) defaults to decline-all, the
/// privacy-conservative choice, and still marks the flow seen so the
/// banner doesn't loop back every time the player backs out of it.
class ConsentBanner extends StatefulWidget {
  const ConsentBanner({
    super.key,
    required this.child,
    this.flowId = 'consent_banner',
    this.version = 1,
    this.title = 'Chúng tôi coi trọng quyền riêng tư của bạn',
    this.message =
        'Ứng dụng dùng dữ liệu phân tích (analytics) và cá nhân hoá '
        '(personalization) để cải thiện trải nghiệm. Bạn có đồng ý không?',
    this.acceptAllLabel = 'Chấp nhận tất cả',
    this.declineAllLabel = 'Từ chối tất cả',
  });

  final Widget child;

  /// Passed to [OnboardingCoordinatorService.registerFlow]/`isFlowSeen`/
  /// `markFlowSeen` — change this if an app already uses `'consent_banner'`
  /// for something else.
  final String flowId;

  /// Passed through to the same 3 [OnboardingCoordinatorService] calls —
  /// bump this to re-ask every player again after a material privacy-policy
  /// change, same as [OnboardingCoordinatorService]'s own `version` doc.
  final int version;

  final String title;
  final String? message;
  final String acceptAllLabel;
  final String declineAllLabel;

  @override
  State<ConsentBanner> createState() => _ConsentBannerState();
}

class _ConsentBannerState extends State<ConsentBanner> {
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    OnboardingCoordinatorService.maybe?.registerFlow(
      widget.flowId,
      version: widget.version,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (!mounted) return;
    final onboarding = OnboardingCoordinatorService.maybe;
    if (onboarding != null &&
        onboarding.isFlowSeen(widget.flowId, version: widget.version)) {
      return;
    }
    final accepted = await _showDialog();
    if (!mounted) return;
    final consent = ConsentStateService.maybe;
    for (final category in ConsentCategory.values) {
      if (accepted) {
        consent?.grant(category);
      } else {
        consent?.deny(category);
      }
    }
    onboarding?.markFlowSeen(widget.flowId, version: widget.version);
  }

  Future<bool> _showDialog() {
    final completer = Completer<bool>();
    NeonDialog.show<void>(
      context: context,
      title: widget.title,
      message: widget.message,
      color: NeonTheme.purple,
      actions: [
        NeonDialogAction(
          label: widget.declineAllLabel,
          color: NeonTheme.muted,
          onTap: () => completer.complete(false),
        ),
        NeonDialogAction(
          label: widget.acceptAllLabel,
          color: NeonTheme.lime,
          onTap: () => completer.complete(true),
        ),
      ],
    ).then((_) {
      // Same "route closed some other way (back button/gesture)" guard as
      // showConfirmDialog/showSmartReviewFunnel — defer past any
      // already-scheduled action callback instead of racing it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!completer.isCompleted) completer.complete(false);
      });
    });
    return completer.future;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
