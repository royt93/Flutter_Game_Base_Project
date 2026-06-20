import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../core/app_info.dart';
import '../../core/neon_theme.dart';
import '../../data/side_mode_records.dart';
import '../../core/storage_service.dart';
import '../../core/utils/format.dart';
import '../controllers/achievement_controller.dart';
import '../controllers/battle_pass_controller.dart';
import '../controllers/collection_controller.dart';
import '../controllers/game_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/piggy_controller.dart';
import '../controllers/puzzle_controller.dart';
import '../controllers/season_league_controller.dart';
import '../controllers/side_mode_record_controller.dart';
import '../controllers/lucky_wheel_controller.dart';
import '../controllers/story_controller.dart';
import '../widgets/lucky_wheel_view.dart';
import '../widgets/neon_bg.dart';
import '../widgets/neon_dialog.dart';
import 'achievements_screen.dart';
import 'battle_pass_screen.dart';
import 'collection_screen.dart';
import 'game_screen.dart';
import 'guide_screen.dart';
import 'level_select_screen.dart';
import 'piggy_screen.dart';
import 'puzzle_select_screen.dart';
import 'season_league_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'temple_screen.dart';
import 'versus_screen.dart';
import 'world_map_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = Get.put(GameController(), permanent: true);
    final hc = Get.put(HomeController(g));
    final ac = Get.put(AchievementController(g), permanent: true);
    final lw = Get.put(LuckyWheelController(g), permanent: true);
    final bp = Get.put(BattlePassController(g), permanent: true);
    final lc = Get.put(SeasonLeagueController(g), permanent: true);
    final cc = Get.put(CollectionController(g), permanent: true);
    final pc = Get.put(PiggyController(g), permanent: true);
    Get.put(SideModeRecordController(g), permanent: true);
    Get.put(PuzzleController(g), permanent: true);
    Get.put(StoryController(), permanent: true);
    g.refillLives(); // cập nhật mạng hồi được khi quay về Home
    return Scaffold(
      body: NeonBg(
        child: SafeArea(
          child: Stack(
            children: [
              _menu(g, ac, bp, lc, cc, pc),
              // Thanh trên: mạng (trái) + quà hằng ngày (phải)
              Positioned(
                top: NeonTheme.s8,
                left: NeonTheme.s16,
                child: Row(
                  children: [
                    Obx(
                      () => GestureDetector(
                        onTap: g.lives.value < GameController.maxLives
                            ? hc.openLivesBuy
                            : null,
                        child: _LivesChip(g: g),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _coinsChip(g),
                  ],
                ),
              ),
              Positioned(
                top: NeonTheme.s8,
                right: NeonTheme.s16,
                child: Obx(() {
                  hc.lastReward.value; // refresh badge sau khi nhận
                  return _dailyButton(g, hc);
                }),
              ),
              // Vòng quay may mắn (trái nút quà)
              Positioned(
                top: NeonTheme.s8,
                right: 64,
                child: Obx(() {
                  lw.resultIndex.value; // refresh badge sau khi quay
                  return _wheelButton(lw);
                }),
              ),
              // Overlay daily (trong cây — route dialog no-op ở full-screen)
              Obx(
                () => hc.dailyOpen.value
                    ? _dailyOverlay(g, hc)
                    : const SizedBox.shrink(),
              ),
              // Overlay mua đầy mạng
              Obx(
                () => hc.livesBuyOpen.value
                    ? _livesBuyOverlay(g, hc)
                    : const SizedBox.shrink(),
              ),
              // Overlay vòng quay may mắn
              Obx(
                () =>
                    lw.open.value ? _wheelOverlay(lw) : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menu(
    GameController g,
    AchievementController ac,
    BattlePassController bp,
    SeasonLeagueController lc,
    CollectionController cc,
    PiggyController pc,
  ) {
    // FULL chiều rộng + KHÔNG scroll. PHÂN BỐ DỌC bằng Column(max) + Spacer:
    //  • Logo TRÊN CÙNG
    //  • CHƠI NGAY + Thử thách Ở GIỮA (2 Spacer kẹp 2 đầu → tự căn giữa khoảng thở)
    //  • Phần thưởng DƯỚI, cách version ĐÚNG 16px; version + copyright ở ĐÁY.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  NeonTheme.s16,
                  58,
                  NeonTheme.s16,
                  NeonTheme.s8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
          // Logo TO, nổi bật trên cùng.
          _GemSparkle(size: 24, gap: 12),
          const SizedBox(height: NeonTheme.s8),
          Text(
                'NEON',
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 9,
                  shadows: NeonTheme.gemColors
                      .take(3)
                      .map((c) => Shadow(color: c, blurRadius: 30))
                      .toList(),
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .shimmer(duration: 2200.ms, color: NeonTheme.cyan)
              .scaleXY(begin: 1, end: 1.04, duration: 1600.ms),
          const Text(
            'JEWELS',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              color: NeonTheme.magenta,
              letterSpacing: 14,
              shadows: [Shadow(color: NeonTheme.magenta, blurRadius: 34)],
            ),
          ),
          // W18.2: danh hiệu đang đeo (từ Thành tựu) — "khoe thành tích".
          Obx(() {
            final key = ac.equippedTitleKey;
            if (key == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      color: NeonTheme.yellow, size: 14),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      key.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NeonTheme.yellow,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Spacer(), // đẩy khối GIỮA (CHƠI NGAY + Thử thách) xuống
          // NÚT CHÍNH — TO + full-width + glow mạnh + nhịp đập nhẹ để hút mắt.
          _playButton(() {
            final grid =
                StorageService.to.getInt(StorageKeys.viewMode, def: 0) == 1;
            Get.to(
              () => grid ? const LevelSelectScreen() : const WorldMapScreen(),
            );
          }),
          const SizedBox(height: NeonTheme.s8),
          // KHU THỬ THÁCH — lưới 2×5 (10 mode): thêm Sinh tồn + Mê cung (Wave 15)
          // mà KHÔNG tăng chiều cao (giữ no-scroll) → version/copyright vẫn hiện.
          _sectionLabel('challenge_modes'.tr),
          const SizedBox(height: NeonTheme.s8),
          // Hàng 1: HẰNG NGÀY · VÔ TẬN · TRÙM · QUÉT MÀU · TRỌNG LỰC.
          // Daily nổi bật: lime + badge 🔥/✓ ở góc (Obx theo streak).
          Row(
            children: [
              Expanded(
                child: Obx(
                  () => _modeCard(
                    Icons.event_rounded,
                    'daily_ch_short'.tr,
                    NeonTheme.lime,
                    () {
                      g.startDaily();
                      Get.to(() => const GameScreen());
                    },
                    corner: _dailyCorner(g),
                  ),
                ),
              ),
              const SizedBox(width: NeonTheme.s8),
              Expanded(
                child: Obx(
                  () => _modeCard(
                    Icons.all_inclusive_rounded,
                    'endless_title'.tr,
                    NeonTheme.purple,
                    () {
                      g.startEndless();
                      Get.to(() => const GameScreen());
                    },
                    corner: _modeRecordCorner(SideModeKind.endless),
                  ),
                ),
              ),
              const SizedBox(width: NeonTheme.s8),
              Expanded(
                child: Obx(
                  () => _modeCard(
                    Icons.coronavirus_rounded,
                    'boss_title'.tr,
                    NeonTheme.orange,
                    () {
                      final stage =
                          (1 + (g.unlockedLevel.value - 1) ~/ 20).clamp(1, 5);
                      g.startBoss(stage);
                      Get.to(() => const GameScreen());
                    },
                    corner: _modeRecordCorner(SideModeKind.boss),
                  ),
                ),
              ),
              const SizedBox(width: NeonTheme.s8),
              Expanded(
                child: Obx(
                  () => _modeCard(
                    Icons.local_fire_department_rounded,
                    'color_rush_short'.tr,
                    NeonTheme.magenta,
                    () {
                      g.startColorRush();
                      Get.to(() => const GameScreen());
                    },
                    corner: _modeRecordCorner(SideModeKind.colorRush),
                  ),
                ),
              ),
              const SizedBox(width: NeonTheme.s8),
              Expanded(
                child: Obx(
                  () => _modeCard(
                    Icons.swap_vert_rounded,
                    'gravity_title'.tr,
                    NeonTheme.cyan,
                    () {
                      g.startGravity();
                      Get.to(() => const GameScreen());
                    },
                    corner: _modeRecordCorner(SideModeKind.gravity),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NeonTheme.s8),
          // Hàng 2: NHỊP ĐIỆU · 2 NGƯỜI · NƯỚC DÂNG · SINH TỒN · MÊ CUNG.
          Row(
            children: [
              Expanded(
                child: Obx(
                  () => _modeCard(
                    Icons.graphic_eq_rounded,
                    'rhythm_title'.tr,
                    NeonTheme.magenta,
                    () {
                      g.startRhythm();
                      Get.to(() => const GameScreen());
                    },
                    corner: _modeRecordCorner(SideModeKind.rhythm),
                  ),
                ),
              ),
              const SizedBox(width: NeonTheme.s8),
              Expanded(
                child: _modeCard(
                  Icons.groups_rounded,
                  'versus_title'.tr,
                  NeonTheme.yellow,
                  () => Get.to(() => const VersusScreen()),
                ),
              ),
              const SizedBox(width: NeonTheme.s8),
              Expanded(
                child: Obx(
                  () => _modeCard(
                    Icons.local_drink_rounded,
                    'soda_short'.tr,
                    NeonTheme.cyan,
                    () {
                      g.startSoda();
                      Get.to(() => const GameScreen());
                    },
                    corner: _modeRecordCorner(SideModeKind.soda),
                  ),
                ),
              ),
              const SizedBox(width: NeonTheme.s8),
              Expanded(
                child: Obx(
                  () => _modeCard(
                    Icons.timer_rounded,
                    'survival_short'.tr,
                    NeonTheme.orange,
                    () {
                      g.startSurvival();
                      Get.to(() => const GameScreen());
                    },
                    corner: _modeRecordCorner(SideModeKind.survival),
                  ),
                ),
              ),
              const SizedBox(width: NeonTheme.s8),
              Expanded(
                child: Obx(
                  () => _modeCard(
                    Icons.account_tree_rounded,
                    'labyrinth_short'.tr,
                    NeonTheme.lime,
                    () {
                      g.startLabyrinth();
                      Get.to(() => const GameScreen());
                    },
                    corner: _modeRecordCorner(SideModeKind.labyrinth),
                  ),
                ),
              ),
              const SizedBox(width: NeonTheme.s8),
              Expanded(
                child: Obx(
                  () => _modeCard(
                    Icons.extension_rounded,
                    'puzzle_short'.tr,
                    NeonTheme.purple,
                    () => Get.to(() => const PuzzleSelectScreen()),
                    corner: _puzzleCorner(),
                  ),
                ),
              ),
            ],
          ),
          // Cách section Phần thưởng đúng 32px (khối Chơi ngay + Thử thách dời
          // xuống sát mép trên của Phần thưởng nhờ Spacer phía trên logo).
          const SizedBox(height: 32),
          // KHU PHẦN THƯỞNG (kinh tế) + TIỆN ÍCH riêng (gọn 1 màn, KHÔNG scroll).
          // W18.4: khu "Phần thưởng" CHỈ còn hệ kinh tế. Hướng dẫn + Cài đặt là
          // TIỆN ÍCH → tách xuống hàng riêng. W18.1: Giải đấu gộp vào Mùa giải.
          // Hàng 1: Đền · Pass · Mùa giải · Cửa hàng. Hàng 2: Album · Heo · Thành tựu.
          _sectionLabel('meta_section'.tr),
          const SizedBox(height: NeonTheme.s8),
          Row(
            children: [
              Expanded(
                child: _circleNav(
                  Icons.account_balance_rounded,
                  NeonTheme.cyan,
                  'temple_title'.tr,
                  () => Get.to(() => const TempleScreen()),
                  small: true,
                ),
              ),
              Expanded(
                child: Obx(() {
                  bp.xp.value;
                  bp.claimed.length;
                  return _circleNav(
                    Icons.military_tech_rounded,
                    NeonTheme.orange,
                    'bp_title'.tr,
                    () => Get.to(() => const BattlePassScreen()),
                    badge: bp.hasClaimable,
                    small: true,
                  );
                }),
              ),
              Expanded(
                child: Obx(() {
                  lc.points.value;
                  lc.claimedMilestones.length;
                  lc.claimedRankThisWeek.value;
                  return _circleNav(
                    Icons.workspace_premium_rounded,
                    NeonTheme.accentForWorld(lc.worldAccent),
                    'season_title'.tr,
                    () => Get.to(() => const SeasonLeagueScreen()),
                    badge: lc.hasClaimable,
                    small: true,
                  );
                }),
              ),
              Expanded(
                child: _circleNav(
                  Icons.storefront_rounded,
                  NeonTheme.magenta,
                  'shop_title'.tr,
                  () => Get.to(() => const ShopScreen()),
                  small: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: NeonTheme.s8),
          Row(
            children: [
              Expanded(
                child: Obx(() {
                  cc.points.value; // hasClaimable phụ thuộc điểm → đọc để rebuild
                  cc.claimed.length;
                  cc.setRewardClaimed.value; // W18.2: rebuild khi thưởng bộ thay đổi
                  return _circleNav(
                    Icons.photo_album_rounded,
                    NeonTheme.cyan,
                    'coll_title'.tr,
                    () => Get.to(() => const CollectionScreen()),
                    badge: cc.hasClaimable,
                    small: true,
                  );
                }),
              ),
              Expanded(
                child: Obx(() {
                  pc.saved.value;
                  return _circleNav(
                    Icons.savings_rounded,
                    NeonTheme.magenta,
                    'piggy_title'.tr,
                    () => Get.to(() => const PiggyScreen()),
                    badge: pc.canSmash,
                    small: true,
                  );
                }),
              ),
              Expanded(
                child: Obx(() {
                  ac.claimed.length;
                  return _circleNav(
                    Icons.emoji_events_rounded,
                    NeonTheme.yellow,
                    'achievements'.tr,
                    () => Get.to(() => const AchievementsScreen()),
                    badge: ac.hasUnclaimed,
                    small: true,
                  );
                }),
              ),
              // W18.4: Hướng dẫn + Cài đặt vào 2 ô cuối (tiện ích, không phải thưởng).
              // Gộp cùng row thay vì section riêng → giữ no-scroll [[home-fullwidth-no-fittedbox]].
              Expanded(
                child: _circleNav(
                  Icons.menu_book_rounded,
                  NeonTheme.magenta,
                  'guide'.tr,
                  () => Get.to(() => const GuideScreen()),
                  small: true,
                ),
              ),
              Expanded(
                child: _circleNav(
                  Icons.settings_rounded,
                  NeonTheme.purple,
                  'settings'.tr,
                  () => Get.to(() => const SettingsScreen()),
                  small: true,
                ),
              ),
            ],
          ),
          // ĐÚNG 16px giữa Phần thưởng và version, rồi version + copyright
          // sát đáy device (edge-to-edge, căn giữa).
          const SizedBox(height: NeonTheme.s16),
          Text(
            'v$kAppVersion',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(color: NeonTheme.cyan, blurRadius: 12),
                Shadow(color: NeonTheme.cyan, blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            kCopyright,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(color: NeonTheme.magenta, blurRadius: 12),
                Shadow(color: NeonTheme.magenta, blurRadius: 4),
              ],
            ),
          ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Chip xu trên top bar.
  Widget _coinsChip(GameController g) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: NeonTheme.panel.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: NeonTheme.yellow, width: 1.5),
      boxShadow: NeonTheme.glow(NeonTheme.yellow, blur: 6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.monetization_on_rounded,
          color: NeonTheme.yellow,
          size: 18,
        ),
        const SizedBox(width: 5),
        Obx(
          () => Text(
            fmtNum(g.coins.value),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ],
    ),
  );

  /// Nhãn tiêu đề khu (canh trái, mảnh).
  Widget _sectionLabel(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
    ),
  );

  /// Thẻ chế độ gọn (icon + nhãn) — dùng trong hàng "Thử thách".

  /// Nút "CHƠI NGAY" NỔI BẬT: full-width, cao, gradient + glow mạnh + nhịp đập
  /// nhẹ (scale lặp) để hút mắt — tâm điểm hành động chính của Home.
  Widget _playButton(VoidCallback onTap) {
    const color = NeonTheme.lime;
    return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.22),
                  NeonTheme.panel.withValues(alpha: 0.6),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color, width: 2.5),
              boxShadow: NeonTheme.glow(color, blur: 16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow_rounded, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  'play_now'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    shadows: [Shadow(color: color, blurRadius: 12)],
                  ),
                ),
              ],
            ),
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1,
          end: 1.03,
          duration: 1100.ms,
          curve: Curves.easeInOut,
        );
  }

  /// Ô thử thách vuông (icon + nhãn). [corner] = badge tuỳ chọn ở góc phải-trên
  /// (vd streak Daily). Dùng chung cho cả 6 ô lưới (2 hàng × 3) → đồng nhất.
  Widget _modeCard(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap, {
    Widget? corner,
  }) {
    final card = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: NeonTheme.panel.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1.6),
          boxShadow: NeonTheme.glow(color, blur: 8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 5),
            // Wave 15: FittedBox(scaleDown) → nhãn TỰ CO vừa bề rộng ô (nhãn ngắn
            // giữ to, nhãn dài như SUPERVIVENCIA/ВЫЖИВАННЯ co lại, KHÔNG ellipsis).
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  shadows: [Shadow(color: color, blurRadius: 8)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (corner == null) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(top: -6, right: -6, child: corner),
      ],
    );
  }

  /// Badge góc của ô Daily: ✓ khi done; khi chưa done hiện 🔥streak + tất cả
  /// mutator hôm nay (W17.3). Column pills xếp dọc — tối đa 3 pills (hiếm).
  /// Badge góc card Daily: ✓ khi done, 🔥streak khi đang có chuỗi, null khác.
  /// Mutator KHÔNG hiện ở Home (trông kỳ, chật) — chỉ hiện khi vào màn chơi (HUD).
  Widget? _dailyCorner(GameController g) {
    final done = g.dailyChallengeDoneToday;
    if (done) return _cornerPill(Icons.check_rounded, NeonTheme.lime, null);
    final streak = g.dailyChStreak.value;
    if (streak > 0) {
      return _cornerPill(
        Icons.local_fire_department_rounded,
        NeonTheme.orange,
        '$streak',
      );
    }
    return null;
  }

  /// W19.1 — badge mốc kỷ lục (huy chương Bronze/Silver/Gold) cho card side-mode.
  /// null nếu chưa đạt mốc nào. Gọi trong Obx (đọc claimedTier Rx).
  Widget? _modeRecordCorner(SideModeKind kind) {
    final rec = SideModeRecordController.maybe;
    if (rec == null) return null;
    final tier = rec.tierOf(kind);
    if (tier == RecordTier.none) return null;
    final Color color;
    switch (tier) {
      case RecordTier.gold:
        color = NeonTheme.yellow;
      case RecordTier.silver:
        color = Colors.white;
      case RecordTier.bronze:
        color = NeonTheme.orange;
      case RecordTier.none:
        return null;
    }
    return _cornerPill(Icons.emoji_events_rounded, color, null);
  }

  /// W19.2 — badge góc card Cấu đố: ✓ khi giải hết, số đã giải khi đang dở.
  Widget? _puzzleCorner() {
    final pc = PuzzleController.maybe;
    if (pc == null) return null;
    final solved = pc.solvedCount;
    if (solved == 0) return null;
    if (pc.allSolved) {
      return _cornerPill(Icons.workspace_premium_rounded, NeonTheme.yellow, null);
    }
    return _cornerPill(Icons.extension_rounded, NeonTheme.purple, '$solved');
  }

  Widget _cornerPill(IconData icon, Color color, String? text) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: text == null ? 4 : 6,
      vertical: 3,
    ),
    decoration: BoxDecoration(
      color: NeonTheme.bgDark,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color, width: 1.3),
      boxShadow: NeonTheme.glow(color, blur: 6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        if (text != null) ...[
          const SizedBox(width: 2),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    ),
  );

  /// Nút điều hướng phụ: icon tròn neon + nhãn nhỏ + badge tuỳ chọn.
  Widget _circleNav(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap, {
    bool badge = false,
    bool small = false,
  }) {
    final circle = Container(
      padding: EdgeInsets.all(small ? 9 : 15),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.55),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: small ? 1.6 : 2),
        boxShadow: NeonTheme.glow(color, blur: small ? 6 : 10),
      ),
      child: Icon(icon, color: color, size: small ? 18 : 26),
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          badge
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    circle,
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: NeonTheme.lime,
                          shape: BoxShape.circle,
                          boxShadow: NeonTheme.glow(NeonTheme.lime, blur: 8),
                        ),
                      ),
                    ),
                  ],
                )
              : circle,
          SizedBox(height: small ? 5 : 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: small ? 9 : 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              shadows: [Shadow(color: color, blurRadius: 8)],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- Lives chip
  // ------------------------------------------------------------ Daily button
  Widget _dailyButton(GameController g, HomeController hc) {
    final can = g.canClaimDaily;
    final btn = Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.6),
        shape: BoxShape.circle,
        border: Border.all(color: NeonTheme.yellow, width: 1.5),
        boxShadow: NeonTheme.glow(NeonTheme.yellow, blur: can ? 12 : 5),
      ),
      child: const Icon(
        Icons.card_giftcard_rounded,
        color: NeonTheme.yellow,
        size: 22,
      ),
    );
    return GestureDetector(
      onTap: hc.openDaily,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          can
              ? btn
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(begin: 1, end: 1.12, duration: 700.ms)
              : btn,
          if (can)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: NeonTheme.lime,
                  shape: BoxShape.circle,
                  boxShadow: NeonTheme.glow(NeonTheme.lime, blur: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Wheel button
  Widget _wheelButton(LuckyWheelController lw) {
    final can = lw.canSpin;
    final btn = Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: NeonTheme.panel.withValues(alpha: 0.6),
        shape: BoxShape.circle,
        border: Border.all(color: NeonTheme.lime, width: 1.5),
        boxShadow: NeonTheme.glow(NeonTheme.lime, blur: can ? 12 : 5),
      ),
      child: const Icon(Icons.casino_rounded, color: NeonTheme.lime, size: 22),
    );
    return GestureDetector(
      onTap: lw.openWheel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          can
              ? btn
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .rotate(begin: -0.03, end: 0.03, duration: 700.ms)
              : btn,
          if (can)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: NeonTheme.magenta,
                  shape: BoxShape.circle,
                  boxShadow: NeonTheme.glow(NeonTheme.magenta, blur: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- Wheel overlay
  Widget _wheelOverlay(LuckyWheelController lw) {
    return NeonDialog.overlay(
      onBarrier: lw.closeWheel,
      panel: NeonDialog.panel(
        title: 'wheel_title'.tr,
        color: NeonTheme.lime,
        icon: Icons.casino_rounded,
        content: LuckyWheelView(ctrl: lw),
        actions: [
          NeonDialogAction(
            label: 'btn_home'.tr,
            color: NeonTheme.cyan,
            onTap: lw.closeWheel,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- Daily overlay
  Widget _dailyOverlay(GameController g, HomeController hc) {
    final can = g.canClaimDaily;
    final got = hc.lastReward.value;
    final message = got > 0
        ? 'daily_got'.trParams({'n': fmtNum(got)})
        : (!can ? 'daily_claimed'.tr : null);
    return NeonDialog.overlay(
      onBarrier: hc.closeDaily,
      panel: NeonDialog.panel(
        title: 'daily_title'.tr,
        color: NeonTheme.yellow,
        icon: Icons.card_giftcard_rounded,
        message: message,
        content: _dailyGrid(g),
        actions: [
          if (can)
            NeonDialogAction(
              label: 'daily_claim'.tr,
              color: NeonTheme.lime,
              onTap: hc.claim,
            )
          else
            NeonDialogAction(
              label: 'btn_home'.tr,
              color: NeonTheme.cyan,
              onTap: hc.closeDaily,
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------- Mua đầy mạng
  Widget _livesBuyOverlay(GameController g, HomeController hc) {
    return NeonDialog.overlay(
      onBarrier: hc.closeLivesBuy,
      panel: NeonDialog.panel(
        title: 'lives_buy_title'.tr,
        color: NeonTheme.magenta,
        icon: Icons.favorite_rounded,
        message: hc.buyFailed.value
            ? 'not_enough_coins'.tr
            : 'lives_buy_msg'.trParams({'n': '${HomeController.refillPrice}'}),
        actions: [
          NeonDialogAction(
            label: 'cancel'.tr,
            color: NeonTheme.cyan,
            onTap: hc.closeLivesBuy,
          ),
          NeonDialogAction(
            label: '${'buy'.tr} (${fmtNum(HomeController.refillPrice)}💰)',
            color: NeonTheme.lime,
            onTap: hc.buyLives,
          ),
        ],
      ),
    );
  }

  Widget _dailyGrid(GameController g) {
    final streak = g.dailyStreak.value;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: List.generate(7, (i) {
        final day = i + 1;
        final reward = g.dailyRewardFor(day);
        // ngày đã nhận trong chu kỳ hiện tại (1..streak trong vòng 7)
        final claimedInCycle = ((streak - 1) % 7) + 1;
        final claimed = streak > 0 && day <= claimedInCycle;
        return Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: claimed
                ? NeonTheme.lime.withValues(alpha: 0.18)
                : NeonTheme.panel.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: claimed ? NeonTheme.lime : NeonTheme.yellow,
              width: claimed ? 2 : 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'daily_day'.trParams({'n': '$day'}),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                claimed
                    ? Icons.check_circle_rounded
                    : Icons.monetization_on_rounded,
                color: claimed ? NeonTheme.lime : NeonTheme.yellow,
                size: 18,
              ),
              const SizedBox(height: 2),
              Text(
                fmtNum(reward),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Cụm gem nhỏ lấp lánh trên logo.
class _GemSparkle extends StatelessWidget {
  final double size;
  final double gap;
  const _GemSparkle({this.size = 30, this.gap = 12});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: gap,
      children: [
        for (int i = 0; i < 5; i++)
          Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: NeonTheme.gemColors[i],
                  borderRadius: BorderRadius.circular(size * 0.27),
                  boxShadow: NeonTheme.glow(NeonTheme.gemColors[i], blur: 14),
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.8, end: 1.2, duration: (800 + i * 160).ms)
              .then()
              .rotate(begin: 0, end: 0.04),
      ],
    );
  }
}

class _LivesChip extends StatefulWidget {
  final GameController g;
  const _LivesChip({required this.g});

  @override
  State<_LivesChip> createState() => _LivesChipState();
}

class _LivesChipState extends State<_LivesChip> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    if (widget.g.lives.value < GameController.maxLives) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        widget.g.refillLives();
        if (!mounted) return;
        if (widget.g.lives.value >= GameController.maxLives) {
          _timer?.cancel();
          _timer = null;
        }
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lives = widget.g.lives.value;
      final full = lives >= GameController.maxLives;
      final next = widget.g.timeToNextLife;
      if (full && _timer != null) {
        _timer?.cancel();
        _timer = null;
      } else if (!full && _timer == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncTimer();
        });
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: NeonTheme.panel.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NeonTheme.magenta, width: 1.5),
          boxShadow: NeonTheme.glow(NeonTheme.magenta, blur: 6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite_rounded,
              color: NeonTheme.magenta,
              size: 18,
            ),
            const SizedBox(width: 5),
            Text(
              '$lives',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            if (!full && next > Duration.zero) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.schedule_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 13,
              ),
              const SizedBox(width: 3),
              Text(
                fmtDur(next),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
