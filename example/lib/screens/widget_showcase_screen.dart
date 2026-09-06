import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/core/utils/throttle.dart';
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
  int _plainTapCount = 0;
  int _throttledTapCount = 0;
  late final _throttledIncrement = throttled(
    () => setState(() => _throttledTapCount++),
  );
  int _starsEarned = 1;
  double _progress = 0.4;
  bool _showLoadingOverlay = false;
  bool _rewardPopupOpen = false;
  bool _confettiActive = false;
  int _confettiTrigger = 0;
  final PageController _dotsPageController = PageController();
  int _dotsPageIndex = 0;
  late DateTime _countdownTarget = DateTime.now().add(
    const Duration(seconds: 15),
  );

  @override
  void dispose() {
    _dotsPageController.dispose();
    super.dispose();
  }

  // Sample world map: 3 completed (with stars), 1 unlocked, 4 locked —
  // LevelSelectGrid itself holds no progress state, this is what a real
  // save/progress system would hand in.
  final List<LevelState> _levelStates = const [
    LevelState.completed,
    LevelState.completed,
    LevelState.completed,
    LevelState.unlocked,
    LevelState.locked,
    LevelState.locked,
    LevelState.locked,
    LevelState.locked,
  ];
  final Map<int, int> _levelStars = const {1: 3, 2: 2, 3: 1};
  bool _networkConnected = true;
  bool _showShimmer = true;

  void _bumpCoins() => setState(() => _coins += 25);

  // FEAT-21: fire several in quick succession — the "spam" test the task
  // asks for. Each self-cleans via FloatingComboText.show, no state to
  // track here.
  void _spamComboText() {
    for (var i = 0; i < 5; i++) {
      Future.delayed(Duration(milliseconds: i * 90), () {
        if (!mounted) return;
        FloatingComboText.show(
          context,
          text: '+${(i + 1) * 10}',
          color: NeonTheme.gold,
        );
      });
    }
  }

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

  void _showBoughtToast() {
    ToastBanner.show(context, message: 'Purchased!', color: NeonTheme.lime);
  }

  void _openRewardPopup() => setState(() => _rewardPopupOpen = true);

  void _closeRewardPopup() => setState(() => _rewardPopupOpen = false);

  void _fireConfetti() {
    setState(() {
      _confettiTrigger++;
      _confettiActive = true;
    });
  }

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
                        // Hidden if AudioManager isn't registered — the
                        // example app always registers it (see main.dart),
                        // so it renders here.
                        const _Demo(
                          label: 'SoundToggleFab',
                          child: SoundToggleFab(),
                        ),
                        _Demo(
                          label: 'throttled() — bấm nhanh nhiều lần để so sánh',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    CommonButton(
                                      label: 'Không throttle',
                                      onTap: () =>
                                          setState(() => _plainTapCount++),
                                    ),
                                    Text('Đếm: $_plainTapCount'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: NeonTheme.s16),
                              Expanded(
                                child: Column(
                                  children: [
                                    CommonButton(
                                      label: 'Có throttle',
                                      onTap: _throttledIncrement,
                                    ),
                                    Text('Đếm: $_throttledTapCount'),
                                  ],
                                ),
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
                        _Demo(
                          label: 'Network Banner',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: NetworkStatusBanner(
                                  connected: _networkConnected,
                                ),
                              ),
                              const SizedBox(height: NeonTheme.s16),
                              CommonButton(
                                label: _networkConnected
                                    ? 'Go offline'
                                    : 'Go online',
                                variant: _networkConnected
                                    ? CommonButtonVariant.danger
                                    : CommonButtonVariant.primary,
                                onTap: () => setState(
                                  () => _networkConnected = !_networkConnected,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _Demo(
                          label: 'Shimmer Loading',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_showShimmer)
                                const Column(
                                  children: [
                                    ShimmerPlaceholder(
                                      height: 48,
                                      borderRadius: 12,
                                    ),
                                    SizedBox(height: NeonTheme.s8),
                                    ShimmerPlaceholder(
                                      height: 48,
                                      borderRadius: 12,
                                    ),
                                  ],
                                )
                              else
                                const CommonListTile(
                                  title: 'Shop item loaded',
                                  subtitle: 'Content ready',
                                ),
                              const SizedBox(height: NeonTheme.s16),
                              CommonButton(
                                label: _showShimmer
                                    ? 'Show loaded content'
                                    : 'Show shimmer',
                                onTap: () => setState(
                                  () => _showShimmer = !_showShimmer,
                                ),
                              ),
                            ],
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
                          // FloatingComboText.show() inserts into the root
                          // Overlay (screen-wide), so it pops centered over
                          // the whole screen rather than inside this card —
                          // tap repeatedly to see the spam behavior.
                          label: 'FloatingComboText',
                          child: CommonButton(
                            label: 'Spam combo x5',
                            color: NeonTheme.gold,
                            onTap: _spamComboText,
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
                          label: 'ConfettiOverlay',
                          child: SizedBox(
                            height: 160,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: CommonButton(
                                    label: 'Trigger',
                                    onTap: _fireConfetti,
                                  ),
                                ),
                                if (_confettiActive)
                                  Positioned.fill(
                                    child: ConfettiOverlay(
                                      key: ValueKey(_confettiTrigger),
                                      onFinished: () {
                                        if (mounted) {
                                          setState(
                                            () => _confettiActive = false,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                              ],
                            ),
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
                        _Demo(
                          label: 'CountdownChip',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CountdownChip(
                                key: ValueKey(_countdownTarget),
                                target: _countdownTarget,
                                onDone: () => ToastBanner.show(
                                  context,
                                  message: 'Countdown done!',
                                  color: NeonTheme.orange,
                                ),
                              ),
                              const SizedBox(height: NeonTheme.s16),
                              CommonButton(
                                label: 'Restart 15s',
                                onTap: () => setState(
                                  () => _countdownTarget = DateTime.now().add(
                                    const Duration(seconds: 15),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _Demo(
                          label: 'Page Dots',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 80,
                                child: PageView(
                                  controller: _dotsPageController,
                                  onPageChanged: (i) =>
                                      setState(() => _dotsPageIndex = i),
                                  children: List.generate(
                                    4,
                                    (i) => Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: NeonTheme.cardAlt,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Page ${i + 1}',
                                        style: TextStyle(
                                          color: NeonTheme.ink,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: NeonTheme.s16),
                              Center(
                                child: PaginatedDotsIndicator(
                                  count: 4,
                                  currentIndex: _dotsPageIndex,
                                ),
                              ),
                            ],
                          ),
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
                        const SectionHeader(title: 'Level Select'),
                        const SizedBox(height: NeonTheme.s16),
                        _Demo(
                          label: 'LevelSelectGrid',
                          child: LevelSelectGrid(
                            states: _levelStates,
                            starsEarnedByLevel: _levelStars,
                            onLevelTap: (level) => ToastBanner.show(
                              context,
                              message: 'Level $level tapped',
                              color: NeonTheme.cyan,
                            ),
                          ),
                        ),

                        const SizedBox(height: NeonTheme.s24),
                        const SectionHeader(title: 'Shop'),
                        const SizedBox(height: NeonTheme.s16),
                        _Demo(
                          label: 'RibbonBadge',
                          child: Wrap(
                            spacing: NeonTheme.s16,
                            runSpacing: NeonTheme.s16,
                            children: [
                              RibbonBadge(
                                text: 'SALE',
                                child: SizedBox(
                                  width: 100,
                                  height: 80,
                                  child: PanelCard(
                                    alt: true,
                                    child: SizedBox.expand(),
                                  ),
                                ),
                              ),
                              RibbonBadge(
                                text: 'NEW',
                                color: NeonTheme.lime,
                                child: SizedBox(
                                  width: 100,
                                  height: 80,
                                  child: PanelCard(
                                    alt: true,
                                    child: SizedBox.expand(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _Demo(
                          label: 'ShopItemCard',
                          child: Wrap(
                            spacing: NeonTheme.s16,
                            runSpacing: NeonTheme.s16,
                            children: [
                              ShopItemCard(
                                icon: Icons.diamond_rounded,
                                title: '100 Gems',
                                priceLabel: r'$0.99',
                                onBuy: _showBoughtToast,
                              ),
                              ShopItemCard(
                                icon: Icons.diamond_rounded,
                                title: 'Mega Gem Pack',
                                priceLabel: r'$4.99',
                                ribbonText: 'BEST VALUE',
                                ribbonColor: NeonTheme.gold,
                                iconColor: NeonTheme.gold,
                                onBuy: _showBoughtToast,
                              ),
                              ShopItemCard(
                                icon: Icons.block_rounded,
                                title: 'Remove Ads',
                                priceLabel: r'$2.99',
                                ribbonText: 'NEW',
                                ribbonColor: NeonTheme.lime,
                                onBuy: null,
                              ),
                            ],
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
