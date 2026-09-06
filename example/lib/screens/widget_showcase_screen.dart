import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_widgets.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_app_bar.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_bg.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_dialog.dart';

/// Living demo of every widget in `lib/presentation/widgets/common/` — the
/// reference a future developer reads to see how each one is meant to be
/// used. Each section is a minimal, realistic call, not a stress test.
///
/// Dogfoods the kit's own [SectionHeader] (one per category) and [PanelCard]
/// (one per example) to lay itself out.
class WidgetShowcaseScreen extends StatefulWidget {
  const WidgetShowcaseScreen({super.key});

  @override
  State<WidgetShowcaseScreen> createState() => _WidgetShowcaseScreenState();
}

class _WidgetShowcaseScreenState extends State<WidgetShowcaseScreen> {
  bool _toggleOn = false;
  int _tabIndex = 0;
  int _coins = 100;
  int _starsEarned = 1;
  double _progress = 0.4;
  bool _showLoadingOverlay = false;
  bool _rewardPopupOpen = false;

  void _bumpCoins() => setState(() => _coins += 25);

  void _cycleStars() => setState(() => _starsEarned = (_starsEarned + 1) % 4);

  void _bumpProgress() =>
      setState(() => _progress = (_progress + 0.2) > 1 ? 0 : _progress + 0.2);

  void _flashLoadingOverlay() {
    setState(() => _showLoadingOverlay = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showLoadingOverlay = false);
    });
  }

  Future<void> _runConfirmDialog() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete save?',
      message: 'This cannot be undone.',
      confirmLabel: 'ok'.tr,
      cancelLabel: 'cancel'.tr,
      color: NeonTheme.red,
      icon: Icons.delete_outline_rounded,
    );
    if (!mounted) return;
    ToastBanner.show(
      context,
      message: confirmed ? 'Confirmed' : 'Cancelled',
      color: confirmed ? NeonTheme.lime : NeonTheme.muted,
    );
  }

  Future<void> _runBottomSheet() {
    return showCommonBottomSheet<void>(
      context,
      color: NeonTheme.cyan,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SectionHeader(title: 'Quick actions'),
          const SizedBox(height: NeonTheme.s16),
          CommonListTile(
            title: 'Restart level',
            leading: const Icon(Icons.replay_rounded, color: NeonTheme.cyan),
            onTap: Get.back,
          ),
          const SizedBox(height: NeonTheme.s8),
          CommonListTile(
            title: 'Share score',
            leading: const Icon(Icons.share_rounded, color: NeonTheme.magenta),
            onTap: Get.back,
          ),
        ],
      ),
    );
  }

  void _openRewardPopup() => setState(() => _rewardPopupOpen = true);

  void _closeRewardPopup() => setState(() => _rewardPopupOpen = false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          NeonBg(
            child: SafeArea(
              child: Column(
                children: [
                  const NeonAppBar(
                    title: 'Widget Kit',
                    color: NeonTheme.magenta,
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(NeonTheme.s16),
                      children: [
                        const SectionHeader(title: 'Buttons & Interactive'),
                        const SizedBox(height: NeonTheme.s16),
                        _Demo(
                          label: 'CommonButton',
                          child: Wrap(
                            spacing: NeonTheme.s16,
                            runSpacing: NeonTheme.s16,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              CommonButton(
                                label: 'Primary',
                                width: 140,
                                onTap: () {},
                              ),
                              CommonButton(
                                label: 'Secondary',
                                width: 140,
                                variant: CommonButtonVariant.secondary,
                                onTap: () {},
                              ),
                              CommonButton(
                                label: 'Danger',
                                width: 140,
                                variant: CommonButtonVariant.danger,
                                onTap: () {},
                              ),
                              CommonButton(
                                icon: Icons.settings_rounded,
                                variant: CommonButtonVariant.icon,
                                onTap: () {},
                              ),
                            ],
                          ),
                        ),
                        _Demo(
                          label: 'CandyToggleSwitch',
                          child: Row(
                            children: [
                              CandyToggleSwitch(
                                value: _toggleOn,
                                onChanged: (v) => setState(() => _toggleOn = v),
                              ),
                              const SizedBox(width: NeonTheme.s16),
                              Text(_toggleOn ? 'On' : 'Off'),
                            ],
                          ),
                        ),
                        _Demo(
                          label: 'SegmentedTabBar',
                          child: SegmentedTabBar(
                            labels: const ['Easy', 'Normal', 'Hard'],
                            selectedIndex: _tabIndex,
                            onChanged: (i) => setState(() => _tabIndex = i),
                          ),
                        ),
                        _Demo(
                          label: 'IconBadgeButton',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconBadgeButton(
                                icon: Icons.notifications_rounded,
                                semanticLabel: 'Notifications',
                                showBadge: true,
                                onTap: () {},
                              ),
                              const SizedBox(width: NeonTheme.s24),
                              IconBadgeButton(
                                icon: Icons.mail_rounded,
                                semanticLabel: 'Mail',
                                badgeCount: 12,
                                onTap: () {},
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: NeonTheme.s24),
                        const SectionHeader(title: 'Feedback & Overlay'),
                        const SizedBox(height: NeonTheme.s16),
                        _Demo(
                          label: 'LoadingOverlay',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 120,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Stack(
                                    children: [
                                      Container(color: NeonTheme.cardAlt),
                                      if (_showLoadingOverlay)
                                        const LoadingOverlay(
                                          message: 'Loading...',
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: NeonTheme.s16),
                              CommonButton(
                                label: 'Show for 1.2s',
                                onTap: _flashLoadingOverlay,
                              ),
                            ],
                          ),
                        ),
                        _Demo(
                          label: 'ToastBanner',
                          child: CommonButton(
                            label: 'Show toast',
                            onTap: () => ToastBanner.show(
                              context,
                              message: 'Saved!',
                              color: NeonTheme.lime,
                            ),
                          ),
                        ),
                        _Demo(
                          label: 'TooltipBubble',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TooltipBubble.text('Tap to pop!'),
                              const SizedBox(width: NeonTheme.s24),
                              TooltipBubble(
                                color: NeonTheme.cyan,
                                direction: TooltipPointerDirection.down,
                                child: Text(
                                  'Combo x3',
                                  style: TextStyle(
                                    color: NeonTheme.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _Demo(
                          label: 'BottomSheetPanel + showCommonBottomSheet',
                          child: CommonButton(
                            label: 'Open sheet',
                            onTap: _runBottomSheet,
                          ),
                        ),
                        _Demo(
                          label: 'ConfirmDialog (showConfirmDialog)',
                          child: CommonButton(
                            label: 'Delete...',
                            variant: CommonButtonVariant.danger,
                            onTap: _runConfirmDialog,
                          ),
                        ),

                        const SizedBox(height: NeonTheme.s24),
                        const SectionHeader(title: 'Progress & Reward'),
                        const SizedBox(height: NeonTheme.s16),
                        _Demo(
                          label: 'ProgressBarStars',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ProgressBarStars(progress: _progress),
                              const SizedBox(height: NeonTheme.s16),
                              CommonButton(
                                label: '+20% progress',
                                onTap: _bumpProgress,
                              ),
                            ],
                          ),
                        ),
                        _Demo(
                          label: 'CircularProgressRing',
                          child: CircularProgressRing(
                            progress: _progress,
                            label: '${(_progress * 100).round()}%',
                          ),
                        ),
                        _Demo(
                          label: 'StarRating',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StarRating(earned: _starsEarned, animate: false),
                              const SizedBox(height: NeonTheme.s16),
                              CommonButton(
                                label: 'Cycle stars',
                                onTap: _cycleStars,
                              ),
                            ],
                          ),
                        ),
                        _Demo(
                          label: 'CurrencyCounter',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CurrencyCounter(value: _coins),
                                  const SizedBox(width: NeonTheme.s24),
                                  CommonButton(
                                    label: '+25',
                                    width: 90,
                                    onTap: _bumpCoins,
                                  ),
                                ],
                              ),
                              const SizedBox(height: NeonTheme.s8),
                              // Idle-game scale value — shows
                              // fmtNumCompact's K/M/B rounding (ENH-11)
                              // instead of a raw digit string.
                              const CurrencyCounter(value: 12345678),
                            ],
                          ),
                        ),
                        _Demo(
                          label: 'RewardPopup',
                          child: CommonButton(
                            label: 'Show reward',
                            color: NeonTheme.gold,
                            onTap: _openRewardPopup,
                          ),
                        ),
                        _Demo(
                          label: 'BadgeDot',
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                Icons.notifications_none_rounded,
                                size: 32,
                                color: NeonTheme.ink,
                              ),
                              const Positioned(
                                top: -2,
                                right: -2,
                                child: BadgeDot(),
                              ),
                            ],
                          ),
                        ),
                        _Demo(
                          label: 'StreakCounter',
                          child: const StreakCounter(days: 7),
                        ),

                        const SizedBox(height: NeonTheme.s24),
                        const SectionHeader(title: 'Layout & Cards'),
                        const SizedBox(height: NeonTheme.s16),
                        _Demo(
                          label: 'CommonListTile',
                          child: Column(
                            children: [
                              CommonListTile(
                                title: 'Daily Reward',
                                subtitle: 'Claim your coins',
                                leading: const Icon(
                                  Icons.card_giftcard_rounded,
                                  color: NeonTheme.magenta,
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () {},
                              ),
                              const SizedBox(height: NeonTheme.s8),
                              CommonListTile(
                                title: 'Leaderboard',
                                leading: const Icon(
                                  Icons.leaderboard_rounded,
                                  color: NeonTheme.cyan,
                                ),
                                onTap: () {},
                              ),
                            ],
                          ),
                        ),
                        _Demo(
                          label: 'EmptyStatePlaceholder',
                          child: const EmptyStatePlaceholder(
                            icon: Icons.inbox_outlined,
                            message: 'Nothing here yet.',
                          ),
                        ),
                        _Demo(
                          label: 'AvatarFrame',
                          child: AvatarFrame(
                            color: NeonTheme.magenta,
                            child: Container(
                              color: NeonTheme.cardAlt,
                              alignment: Alignment.center,
                              child: Text(
                                'RB',
                                style: TextStyle(
                                  color: NeonTheme.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: NeonTheme.s24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_rewardPopupOpen)
            Positioned.fill(
              child: NeonDialog.overlay(
                onBarrier: _closeRewardPopup,
                panel: GestureDetector(
                  onTap: _closeRewardPopup,
                  child: RewardPopup(
                    title: 'Level Complete!',
                    message: '+50 coins earned',
                    icon: Icons.emoji_events_rounded,
                    color: NeonTheme.gold,
                    content: const StarRating(earned: 3, animate: true),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One example: a small caption naming the widget under demo (so the source
/// of a given visual is unambiguous), then the live widget itself — laid out
/// in a [PanelCard], the kit's own generic container.
class _Demo extends StatelessWidget {
  const _Demo({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NeonTheme.s16),
      child: PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: NeonTheme.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: NeonTheme.s8),
            child,
          ],
        ),
      ),
    );
  }
}
