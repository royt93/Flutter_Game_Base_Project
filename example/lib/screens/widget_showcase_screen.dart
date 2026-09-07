import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:roy_casual_kit/core/daily_login_service.dart';
import 'package:roy_casual_kit/core/energy_service.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/core/share_helper.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
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
  final GlobalKey _coinCounterKey = GlobalKey();
  final GlobalKey _victoryCardKey = GlobalKey();
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

  // FEAT-11: SpotlightOverlay demo — highlights the "Primary" CommonButton
  // from the Buttons & Interactive section above.
  final _spotlightTargetKey = GlobalKey();
  bool _spotlightActive = false;

  void _startTutorial() => setState(() => _spotlightActive = true);
  void _endTutorial() => setState(() => _spotlightActive = false);

  // IDEA-14: TutorialSequence demo — chains 2 existing spotlight targets
  // (the same Primary button as above, then the CurrencyCounter) into one
  // guided sequence instead of a single one-off SpotlightOverlay.
  final _tutorialSequenceController = TutorialSequenceController();

  void _startTutorialSequence() {
    _tutorialSequenceController.start([
      TutorialStep(
        targetKey: _spotlightTargetKey,
        title: 'Step 1 of 2',
        message: 'This is the Primary button — the main action on any screen.',
        color: NeonTheme.cyan,
      ),
      TutorialStep(
        targetKey: _coinCounterKey,
        title: 'Step 2 of 2',
        message: 'Your coin balance lives here — it updates live as you earn.',
        color: NeonTheme.gold,
      ),
    ]);
  }

  // IDEA-08: Game Feel demo state — SquashStretch tap count, a
  // ScreenShakeController the caller owns/disposes, and a cycling combo
  // heat value.
  int _squashTapCount = 0;
  final _screenShakeController = ScreenShakeController();
  double _comboHeat = 0.0;

  void _bumpSquashTapCount() => setState(() => _squashTapCount++);

  void _cycleComboHeat() => setState(
    () => _comboHeat = (_comboHeat + 0.25) > 1 ? 0 : _comboHeat + 0.25,
  );

  @override
  void initState() {
    super.initState();
    if (StorageService.maybe == null) {
      Get.put(StorageService(null), permanent: true);
    }
    _dailyLogin =
        DailyLoginService.maybe ??
        Get.put(DailyLoginService(), permanent: true);
    _energy = EnergyService.maybe ?? Get.put(EnergyService(), permanent: true);
  }

  @override
  void dispose() {
    _dotsPageController.dispose();
    _screenShakeController.dispose();
    _tutorialSequenceController.dispose();
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

  // DailyLoginCalendarWidget / EnergyBar demos wire to a real service
  // instance — self-registered here (permanent: true, like main.dart's own
  // singletons) if a host app hasn't already put one, so this section works
  // standalone in a widget test too. `StorageService(null)` is the same
  // safe in-memory fallback `storage_service.dart` already uses when
  // `SharedPreferences.getInstance()` fails at boot.
  late final DailyLoginService _dailyLogin;
  late final EnergyService _energy;

  void _claimDailyLogin() => setState(() => _dailyLogin.claimToday());

  void _consumeEnergy() => setState(() => _energy.consumeEnergy());

  void _bumpCoins() => setState(() => _coins += 25);

  // FEAT-12: fly 5 coins from the button toward the CurrencyCounter's
  // GlobalKey, bumping the displayed value by 5 (25 ~/ 5) per arrival so
  // the running total lands on +25 once the last coin lands.
  void _flyCoins() {
    const totalAmount = 25;
    const coinCount = 5;
    final size = MediaQuery.of(context).size;
    CoinFlyOverlay.show(
      context,
      from: Offset(size.width / 2, size.height - 80),
      targetKey: _coinCounterKey,
      coinCount: coinCount,
      onArrive: () {
        if (mounted) setState(() => _coins += totalAmount ~/ coinCount);
      },
    );
  }

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
            leading: Icon(Icons.replay_rounded, color: NeonTheme.cyan),
            onTap: Get.back,
          ),
          const SizedBox(height: NeonTheme.s8),
          CommonListTile(
            title: 'Share score',
            leading: Icon(Icons.share_rounded, color: NeonTheme.magenta),
            onTap: Get.back,
          ),
        ],
      ),
    );
  }

  // IDEA-06: proves the VictoryCardTemplate -> RepaintBoundary ->
  // shareScoreCard wiring described in that widget's doc comment actually
  // works end-to-end, not just that the card renders.
  Future<void> _shareVictoryCard() {
    return shareScoreCard(
      boundaryKey: _victoryCardKey,
      levelText: 'Level 50 Complete!',
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
                  NeonAppBar(title: 'Widget Kit', color: NeonTheme.magenta),
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
                                key: _spotlightTargetKey,
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
                              // Wrap (not Row) — on a narrower effective
                              // width (larger system font scale / display
                              // zoom, e.g. reproduced on a real Samsung
                              // device with font_scale 1.08 + a density
                              // override), 3 fixed-width items in a plain
                              // Row(mainAxisSize.min) overflow instead of
                              // shrinking; Wrap just flows the 3rd item to
                              // a new line instead.
                              Wrap(
                                spacing: NeonTheme.s16,
                                runSpacing: NeonTheme.s8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  CurrencyCounter(
                                    key: _coinCounterKey,
                                    value: _coins,
                                  ),
                                  CommonButton(
                                    label: '+25',
                                    width: 90,
                                    onTap: _bumpCoins,
                                  ),
                                  // FEAT-12: coins fly from the bottom of
                                  // the screen to this CurrencyCounter's
                                  // GlobalKey, bumping the value on arrival
                                  // instead of jumping instantly.
                                  CommonButton(
                                    label: 'Fly +25',
                                    width: 110,
                                    color: NeonTheme.gold,
                                    onTap: _flyCoins,
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
                          // Highlights the "Primary" CommonButton up in
                          // Buttons & Interactive (keyed via
                          // _spotlightTargetKey) — scroll up after
                          // dismissing to see which one it was.
                          label: 'SpotlightOverlay',
                          child: CommonButton(
                            label: 'Start tutorial',
                            onTap: _startTutorial,
                          ),
                        ),
                        _Demo(
                          label: 'TutorialSequence',
                          child: CommonButton(
                            label: 'Start 2-step tutorial',
                            onTap: _startTutorialSequence,
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

                        _Demo(
                          label: 'DailyLoginCalendarWidget',
                          child: DailyLoginCalendarWidget(
                            currentStreakDay: _dailyLogin.currentStreakDay,
                            claimedDaysInCycle: _dailyLogin.claimedDaysInCycle,
                            canClaimToday: _dailyLogin.canClaimToday(),
                            onClaim: _claimDailyLogin,
                          ),
                        ),
                        _Demo(
                          label: 'EnergyBar',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              EnergyBar(
                                currentEnergy: _energy.currentEnergy,
                                maxEnergy: _energy.maxEnergy,
                                timeUntilNextEnergy:
                                    _energy.timeUntilNextEnergy,
                                hasInfiniteLives: _energy.hasInfiniteLives,
                              ),
                              const SizedBox(height: NeonTheme.s16),
                              CommonButton(
                                label: 'Consume 1 energy',
                                onTap: _consumeEnergy,
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
                                leading: Icon(
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
                                leading: Icon(
                                  Icons.leaderboard_rounded,
                                  color: NeonTheme.cyan,
                                ),
                                onTap: () {},
                              ),
                            ],
                          ),
                        ),
                        _Demo(
                          label: 'LeaderboardList',
                          child: const LeaderboardList(
                            entries: [
                              LeaderboardEntry(
                                rank: 1,
                                name: 'Alice',
                                score: '12,340',
                              ),
                              LeaderboardEntry(
                                rank: 2,
                                name: 'You',
                                score: '9,870',
                                highlighted: true,
                              ),
                              LeaderboardEntry(
                                rank: 3,
                                name: 'Charlie',
                                score: '8,120',
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
                        _Demo(
                          label: 'VictoryCardTemplate (share_helper wiring)',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RepaintBoundary(
                                key: _victoryCardKey,
                                child: VictoryCardTemplate(
                                  title: 'Level 50 Complete!',
                                  statLines: const [
                                    'Score: 12,340',
                                    'Time: 01:23',
                                  ],
                                  avatar: const CircleAvatar(child: Text('RB')),
                                  qrData: 'https://example.com/invite/abc123',
                                ),
                              ),
                              const SizedBox(height: NeonTheme.s16),
                              CommonButton(
                                label: 'Share',
                                width: 140,
                                onTap: _shareVictoryCard,
                              ),
                            ],
                          ),
                        ),
                        _Demo(
                          label: 'GameOverCardTemplate',
                          child: GameOverCardTemplate(
                            title: 'Out of moves!',
                            message: 'So close — try again?',
                            icon: Icons.sentiment_dissatisfied_rounded,
                            statLines: const ['Score: 1,200'],
                            primaryActionLabel: 'Retry',
                            onPrimaryAction: () => ToastBanner.show(
                              context,
                              message: 'Retry tapped',
                              color: NeonTheme.cyan,
                            ),
                            secondaryActionLabel: 'Home',
                            onSecondaryAction: () => ToastBanner.show(
                              context,
                              message: 'Home tapped',
                              color: NeonTheme.muted,
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
                        const SectionHeader(title: 'Game Feel'),
                        const SizedBox(height: NeonTheme.s16),
                        _Demo(
                          label: 'SquashStretch (tap the card)',
                          child: SquashStretch(
                            onTap: _bumpSquashTapCount,
                            child: PanelCard(
                              alt: true,
                              child: SizedBox(
                                width: 120,
                                height: 60,
                                child: Center(
                                  child: Text(
                                    'Taps: $_squashTapCount',
                                    style: TextStyle(
                                      color: NeonTheme.ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        _Demo(
                          label: 'ScreenShake',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ScreenShake(
                                controller: _screenShakeController,
                                child: PanelCard(
                                  alt: true,
                                  child: SizedBox(
                                    width: 120,
                                    height: 60,
                                    child: Center(
                                      child: Icon(
                                        Icons.warning_amber_rounded,
                                        color: NeonTheme.orange,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: NeonTheme.s16),
                              CommonButton(
                                label: 'Shake!',
                                onTap: () => _screenShakeController.shake(),
                              ),
                            ],
                          ),
                        ),
                        _Demo(
                          label: 'ComboHeatBackground',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ComboHeatBackground(
                                heat: _comboHeat,
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 60,
                                  child: Center(
                                    child: Text(
                                      'Heat: ${(_comboHeat * 100).round()}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: NeonTheme.s16),
                              CommonButton(
                                label: 'Bump heat',
                                onTap: _cycleComboHeat,
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
          if (_spotlightActive)
            Positioned.fill(
              child: SpotlightOverlay(
                targetKey: _spotlightTargetKey,
                title: 'Try this',
                message:
                    'This is the Primary button — the main action '
                    'on any screen.',
                color: NeonTheme.cyan,
                onDismiss: _endTutorial,
              ),
            ),
          TutorialSequence(
            controller: _tutorialSequenceController,
            child: const SizedBox.shrink(),
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
