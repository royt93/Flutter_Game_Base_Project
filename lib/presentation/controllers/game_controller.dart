import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, IconData, Icons;
import 'package:get/get.dart';
import '../../core/debug_log.dart';
import '../../core/neon_theme.dart';
import '../../core/storage_service.dart';
import '../../data/achievements.dart';
import '../../data/battle_pass.dart';
import '../../data/collection.dart';
import '../../data/cosmetics.dart';
import '../../data/levels.dart';
import '../../data/progression_tree.dart';
import '../../data/puzzles.dart';
import '../../data/season.dart';
import '../../data/side_mode_records.dart';
import '../../data/story.dart';
import '../../data/temple.dart';
import '../../logic/boss_attack.dart';
import '../../logic/gem_data.dart';
import '../../logic/rhythm_clock.dart';
import 'achievement_controller.dart';
import 'battle_pass_controller.dart';
import 'challenge_card_controller.dart';
import 'clan_controller.dart';
import 'collection_controller.dart';
import 'lucky_wheel_controller.dart';
import 'piggy_controller.dart';
import 'progression_tree_controller.dart';
import 'puzzle_controller.dart';
import 'season_league_controller.dart';
import 'side_mode_record_controller.dart';
import 'temple_controller.dart';

// GameController được tách vật lý thành nhiều file `part` theo trách nhiệm để
// dễ bảo trì, NHƯNG vẫn là MỘT class duy nhất (giữ nguyên public API + mọi
// call-site + Get.find). Mỗi part là 1 extension trên GameController, chia sẻ
// chung field/private state qua cơ chế thư viện `part of`.
part 'game_controller_modes.dart';
part 'game_controller_scoring.dart';
part 'game_controller_economy.dart';
part 'game_controller_booster.dart';
part 'game_controller_cosmetics.dart';
part 'game_controller_lives.dart';
part 'game_controller_progress.dart';

/// W25.2 — kiểu animation icon mở-màn theo mode (dùng bởi [_ModeIntroOverlay]).
enum ModeIntroMotion { shake, spin, pulse, riseFade, bounce, none }

/// Quản lý state ván chơi + tiến trình (GetX).
class GameController extends GetxController {
  final RxInt score = 0.obs;
  final RxInt movesLeft = 0.obs;
  final RxInt targetScore = 0.obs;
  final RxInt comboCount = 0.obs;
  final RxInt runMaxCombo =
      0.obs; // combo cao nhất trong VÁN hiện tại (cho quest)
  final RxInt currentLevel = 1.obs;

  // --- Mục tiêu màn chơi ---
  final RxInt collected = 0.obs;
  final RxInt jellyCleared = 0.obs;
  final RxInt jellyTotal = 0.obs;

  // Time Attack: thời gian còn lại (giây).
  final RxInt timeLeft = 0.obs;

  // Drop Down: số ingredient đã đưa xuống đáy.
  final RxInt dropped = 0.obs;

  // Obstacle (ice/chain/stone): tiến trình dọn sạch.
  final RxInt obstacleCleared = 0.obs;
  final RxInt obstacleTotal = 0.obs;

  // Order (mục tiêu hỗn hợp, Wave 10): tiến trình thu từng màu, song song với
  // level.orders (cùng độ dài). Cập nhật trong registerClear.
  final RxList<int> orderProgress = <int>[].obs;

  // Bom đếm ngược (Wave 10) — hazard trên vài màn score. Engine sở hữu lưới bom,
  // đẩy trạng thái vào các Rx này cho HUD. bombExploded=true → checkEnd cho THUA.
  final RxInt bombsLeft = 0.obs; // số bom còn sống trên bàn
  final RxInt bombMinTimer =
      0.obs; // đếm ngược NHỎ NHẤT còn lại (cho HUD cảnh báo)
  final RxBool bombExploded = false.obs; // 1 bom về 0 do đếm ngược → thua

  // Dispenser (Wave 11): đếm ngược tới lần PHÁT special kế (engine sync cho HUD).
  final RxInt dispenserCountdown = 0.obs;

  // --- Endless mode (Wave 6) ---
  final RxBool isEndless = false.obs;
  final RxInt endlessStage = 1.obs; // tăng theo điểm → khó hơn + đổi màu
  final RxInt endlessHigh = 0.obs; // high score riêng của Endless
  LevelConfig? _endlessCfg; // cấu hình màn endless (không thuộc kLevels)
  final RxString endlessEvent =
      ''.obs; // tên event hiện tại: 'moves'/'scoreX2'/'gems'/''
  int _endlessScoreX2Remaining = 0;
  bool _endlessGemRainPending = false;
  int _endlessLastEventCount = 0;

  // --- Zen Mode (W20.4) — không thua, tích điểm tự do ---
  final RxBool isZen = false.obs;
  final RxInt zenHigh = 0.obs;
  // W28.1 — mốc thưởng one-time cao nhất đã nhận (0..kZenMilestones.length).
  final RxInt zenMilestoneTier = 0.obs;
  LevelConfig? _zenCfg;

  // W21 — Rush Mode (Tốc chiến): 2 phút, vô hạn lượt, match → +giây.
  final RxBool isRush = false.obs;
  final RxInt rushTimeBonus = 0.obs; // giây vừa được cộng (HUD fly-up)
  static const int kRushInitialSeconds = 120;
  static const int kRushMaxSeconds = 300;

  // --- Boss neon (Wave 8) ---
  final RxBool isBoss = false.obs;
  final RxInt bossHp = 0.obs;
  final RxInt bossMaxHp = 0.obs;
  final RxInt bossStage = 1.obs; // chọn từ Home (1..n) → máu + né tăng
  final RxInt bossWeakColor = 0.obs; // index màu điểm yếu (đổi theo phase)
  // W25.1 — loại boss (khác PROFILE đòn): pulse (cổ điển) / voidType (hung hãn).
  final Rx<BossType> bossType = BossType.pulse.obs;
  final RxInt bossAttackSignal =
      0.obs; // tăng mỗi lần boss phản đòn → HUD flash
  // W23 — tăng mỗi lần boss LÊN phase mới → HUD flash "PHASE N!".
  final RxInt bossPhaseUpSignal = 0.obs;
  int _lastBossPhase = 0;
  LevelConfig? _bossCfg;
  int _bossHitsSinceRetaliate = 0;

  /// Đã clear ÍT NHẤT 1 gem đúng màu điểm yếu trong nhịp resolve hiện tại?
  /// Bật bởi [registerClear], tiêu thụ (×2 sát thương) trong [_bossDamage].
  bool _weakHitPending = false;

  // --- Trọng lực động (Wave 8) ---
  final RxBool isGravity = false.obs;
  final RxInt gravityDir = 0.obs; // 0 = xuống (mặc định), 1 = lên (đã lật)
  LevelConfig? _gravityCfg;
  final RxInt _gravityMoveCount = 0.obs;

  // --- Color Rush (Wave 11) — màu "nóng" đổi mỗi N lượt, clear màu nóng → bội điểm ---
  final RxBool isColorRush = false.obs;
  final RxInt colorRushHot = 0.obs; // index GemColor đang "nóng"
  int _colorRushMoveCount = 0;
  LevelConfig? _colorRushCfg;
  final RxInt colorRushStreak =
      0.obs; // streak clear màu nóng liên tiếp (0..kColorRushMaxStreak)
  bool _colorRushHotClearedThisMove = false;

  // --- Soda / Ngập nước (Wave 14) — clear gem → mực nước dâng, đẩy chai nổi lên ---
  final RxBool isSoda = false.obs;
  LevelConfig? _sodaCfg;
  final RxInt sodaFill = 0.obs; // tổng gem clear tích luỹ (mực nước)
  final RxInt sodaCollected = 0.obs; // số chai đã nổi lên đỉnh
  final RxInt sodaNozzlePulse = 0.obs; // tăng mỗi lần nozzle phun (UI animate)
  int _sodaMoveCount = 0;

  // --- DDA / Pity System (Wave 16): trợ giúp ĐỘNG khi thua liên tiếp 1 màn thường.
  // KÍN ĐÁO (không báo người chơi) → giữ cảm giác tự thắng. CHỈ màn thường.
  /// Số lần thua LIÊN TIẾP màn hiện tại (đọc lúc startLevel; 0 ở side-mode).
  final RxInt pity = 0.obs;
  static const int kPityLuckyFails = 2; // ≥2: tăng tỉ lệ gem may mắn refill
  static const int kPitySpecialFails = 3; // ≥3: seed 1 special lúc mở màn
  static const int kPityMovesFails = 4; // ≥4: +lượt khởi đầu (relief ẩn)
  static const int kPityMovesBonus = 2;
  // Phase 4 RNG control (CHIỀU GIÚP): thua liên tiếp + màn collect → tỉ lệ refill
  // ra MÀU MỤC TIÊU (giúp thu). KHÔNG dùng chiều anti-player.
  static const double kPityCollectBias = 0.20;

  // W25.1 Phase 1B — ColorRush: refill nghiêng về màu nóng (đổi cách gem rơi).
  static const double kColorRushRefillBias = 0.35;
  // W25.1 Phase 1C — Thử Thách (hard variant, tự chọn sau Gold): đổi lượt lấy
  // thưởng cao hơn. KHÔNG ép — người chơi tự bật, KHÔNG đụng campaign/lives.
  static const double kHardVariantMovesMul = 0.85; // -15% lượt
  static const double kHardVariantRewardMul = 1.5; // +50% xu thưởng

  // --- Sinh tồn (Survival — Wave 17.1 "Triều dâng"): nước dâng từ đáy, clear thấp
  // để đẩy lùi, chạm đỉnh = thua. Engine điều khiển triều + set cờ dưới đây ---
  final RxBool isSurvival = false.obs;
  LevelConfig? _survivalCfg;
  final RxInt survivalHigh = 0.obs; // điểm cao nhất (kỷ lục Survival)
  final RxBool tideOverflow =
      false.obs; // engine set true khi nước chạm đỉnh → thua
  final RxDouble tideLevel =
      0.0.obs; // 0..1 mức nguy hiểm (cho HUD), engine cập nhật

  // --- Mê cung neon (Labyrinth — Wave 15): đưa tinh thể qua mê cung xuống đáy ---
  final RxBool isLabyrinth = false.obs;
  LevelConfig? _labyrinthCfg;

  // --- Rhythm mode (Wave 8) — ghép theo nhịp ---
  final RxBool isRhythm = false.obs;
  LevelConfig? _rhythmCfg;
  final RhythmClock rhythm = RhythmClock(bpm: kRhythmBpm);
  final RxInt rhythmBeat = 0.obs; // tăng mỗi mốc beat → đập HUD
  final RxInt groove = 0.obs; // chuỗi đúng nhịp (0..[kGrooveMax])
  final RxInt lastBeatJudge = 0.obs; // 0 chưa đánh, 1 đúng nhịp, -1 lệch nhịp
  // W21 — Rhythm upgrade
  final RxInt rhythmJudge =
      0.obs; // 2=PERFECT, 1=GOOD, -1=LATE, -2=MISS, 0=neutral
  final RxDouble rhythmBpm = 80.0.obs; // BPM hiện tại (cho HUD)
  bool _rhythmBonusPending = false;

  /// Trần groove (đúng nhịp liên tiếp) → hệ số thưởng điểm tối đa.
  static const int kGrooveMax = 8;

  // --- Versus (2 người, Wave 8.7) — 1 bàn engine Flame, KHÔNG đụng tiến trình ---
  /// Khi true: bỏ qua _load (không đọc/ghi storage tiến trình), checkEnd→null
  /// (đồng hồ ngoài quyết định), không cộng xu/win-streak/bestCombo.
  final bool versus;
  final RxBool isVersus = false.obs;
  LevelConfig? _versusCfg;

  GameController({this.versus = false});

  // --- Thử thách hằng ngày (Wave 9) — 1 màn seed theo NGÀY ---
  /// Khi true: màn chơi 1 puzzle seed bằng epoch-day (mọi người cùng bàn), thắng
  /// được thưởng + cộng streak CHỈ 1 lần/ngày; KHÔNG đụng win-streak/level-unlock.
  final RxBool isDaily = false.obs;
  LevelConfig? _dailyCfg;
  int _dailySeed = 0;
  final RxInt dailyChStreak = 0.obs; // chuỗi ngày hoàn thành liên tiếp
  final RxInt dailyChBestStreak = 0.obs;

  // --- Cấu đố (W19.2) — bàn seed cố định, KHÔNG refill, mục tiêu điểm ---
  final RxBool isPuzzle = false.obs;
  LevelConfig? _puzzleCfg;
  PuzzleDef? _puzzleDef;
  PuzzleDef? get currentPuzzle => _puzzleDef;

  /// Ngưỡng combo để gây sát thương GẤP ĐÔI (đánh đúng "phase yếu").
  static const int bossWeakCombo = 4;

  // W21 — Boss phase thresholds & attack config
  static const double kBossPhase2Threshold = 0.65; // HP xuống 65% → phase 2
  static const double kBossPhase3Threshold = 0.32; // HP xuống 32% → phase 3
  // Interval (số lượt) trước khi boss retaliate, theo phase [0,1,2].
  static const List<int> kBossAttackInterval = [4, 3, 2];
  // Số lượt bị trừ khi boss retaliate, theo phase [0,1,2].
  static const List<int> kBossAttackDamage = [1, 2, 3];

  /// Phase boss hiện tại (0 = đầu, 1 = giữa, 2 = cuối). Computed từ HP ratio.
  int get bossPhase {
    if (bossMaxHp.value == 0) return 0;
    final ratio = bossHp.value / bossMaxHp.value;
    if (ratio <= kBossPhase3Threshold) return 2;
    if (ratio <= kBossPhase2Threshold) return 1;
    return 0;
  }

  /// W23.2B — kiểu đòn boss theo phase hiện tại (engine ánh xạ ra hiệu ứng).
  /// W25.1 — profile đòn phụ thuộc [bossType].
  BossAttack get bossAttackPattern =>
      bossAttackPatternFor(bossPhase, bossType.value);

  /// Key i18n nhãn đòn boss (HUD flash) theo phase.
  String get bossAttackLabelKey {
    switch (bossAttackPattern) {
      case BossAttack.meteor:
        return 'boss_atk_meteor';
      case BossAttack.shuffle:
        return 'boss_atk_shuffle';
      case BossAttack.block:
        return 'boss_atk_block';
    }
  }

  /// W25.1 — Key i18n tên loại boss (HUD/intro).
  String get bossTypeNameKey => bossType.value == BossType.voidType
      ? 'boss_type_void'
      : 'boss_type_pulse';

  /// W25.2 — NGUỒN DUY NHẤT cho "identity" mode: màu accent (nền+aura) + key tên
  /// mở-màn + icon/motion mở-màn + câu luật thắng 1 dòng. Gộp về 1 chỗ (review
  /// #6) để không lệch giữa nhiều dispatch. Side-mode → spec riêng; campaign →
  /// accent theo thế giới, không mở-màn.
  ({
    Color accent,
    String? introKey,
    IconData? icon,
    ModeIntroMotion motion,
    String? ruleKey,
  })
  get _modeSpec {
    if (isBoss.value) {
      return (
        accent: NeonTheme.red,
        introKey: 'boss_title',
        icon: Icons.coronavirus_rounded,
        motion: ModeIntroMotion.shake,
        ruleKey: 'rule_boss',
      );
    }
    if (isRhythm.value) {
      return (
        accent: NeonTheme.pink,
        introKey: 'rhythm_title',
        icon: Icons.graphic_eq_rounded,
        motion: ModeIntroMotion.pulse,
        ruleKey: 'rule_rhythm',
      );
    }
    if (isSurvival.value) {
      return (
        accent: NeonTheme.cyan,
        introKey: 'survival_title',
        icon: Icons.waves_rounded,
        motion: ModeIntroMotion.riseFade,
        ruleKey: 'rule_survival',
      );
    }
    if (isLabyrinth.value) {
      return (
        accent: NeonTheme.purple,
        introKey: 'labyrinth_title',
        icon: Icons.account_tree_rounded,
        motion: ModeIntroMotion.spin,
        ruleKey: 'rule_labyrinth',
      );
    }
    if (isColorRush.value) {
      return (
        accent: NeonTheme.orange,
        introKey: 'color_rush_title',
        icon: Icons.bolt_rounded,
        motion: ModeIntroMotion.pulse,
        ruleKey: 'rule_color_rush',
      );
    }
    if (isSoda.value) {
      return (
        accent: NeonTheme.blue,
        introKey: 'soda_title',
        icon: Icons.local_drink_rounded,
        motion: ModeIntroMotion.riseFade,
        ruleKey: 'rule_soda',
      );
    }
    if (isEndless.value) {
      // review #3: giữ XOAY accent theo stage (không cố định 1 màu).
      return (
        accent:
            NeonTheme.worldAccents[(endlessStage.value - 1) %
                NeonTheme.worldAccents.length],
        introKey: 'endless_title',
        icon: Icons.all_inclusive_rounded,
        motion: ModeIntroMotion.none,
        ruleKey: 'rule_endless',
      );
    }
    if (isDaily.value) {
      return (
        accent: NeonTheme.lime,
        introKey: 'daily_ch_title',
        icon: Icons.today_rounded,
        motion: ModeIntroMotion.bounce,
        ruleKey: 'rule_daily',
      );
    }
    if (isPuzzle.value) {
      return (
        accent: NeonTheme.gold,
        introKey: 'puzzle_title',
        icon: Icons.extension_rounded,
        motion: ModeIntroMotion.bounce,
        ruleKey: 'rule_puzzle',
      );
    }
    if (isZen.value) {
      return (
        accent: NeonTheme.teal,
        introKey: 'zen_title',
        icon: Icons.spa_rounded,
        motion: ModeIntroMotion.none,
        ruleKey: 'rule_zen',
      );
    }
    if (isGravity.value) {
      return (
        accent: NeonTheme.indigo,
        introKey: 'gravity_title',
        icon: Icons.south_rounded,
        motion: ModeIntroMotion.spin,
        ruleKey: 'rule_gravity',
      );
    }
    if (isRush.value) {
      return (
        accent: NeonTheme.red,
        introKey: 'rush_title',
        icon: Icons.rocket_launch_rounded,
        motion: ModeIntroMotion.shake,
        ruleKey: 'rule_rush',
      );
    }
    // Versus chạy ở VersusScreen riêng (không dùng mở-màn GameScreen) → introKey null.
    if (isVersus.value) {
      return (
        accent: NeonTheme.yellow,
        introKey: null,
        icon: null,
        motion: ModeIntroMotion.none,
        ruleKey: null,
      );
    }
    return (
      accent: NeonTheme.accentForWorld(worldOfLevel(currentLevel.value).index),
      introKey: null,
      icon: null,
      motion: ModeIntroMotion.none,
      ruleKey: null,
    );
  }

  /// Màu accent theo mode (nền + aura). Xem [_modeSpec].
  Color get modeAccent => _modeSpec.accent;

  /// Key i18n tên mode cho MỞ-MÀN (null → không hiện intro). Xem [_modeSpec].
  String? get modeIntroKey => _modeSpec.introKey;

  /// W25.2 — Icon mở-màn theo mode (null → không icon). Xem [_modeSpec].
  IconData? get modeIntroIcon => _modeSpec.icon;

  /// W25.2 — Kiểu animation icon mở-màn theo mode. Xem [_modeSpec].
  ModeIntroMotion get modeIntroMotion => _modeSpec.motion;

  /// W25.2 — Key i18n câu luật thắng 1 dòng cho MỞ-MÀN (null → không hiện).
  /// Xem [_modeSpec].
  String? get modeRuleKey => _modeSpec.ruleKey;

  /// W26.1 — Nhạc nền theo nhóm mode (1 trong 3 track sẵn có, không cần asset mới).
  /// track1 = mode căng · track2 = mode nhịp/vui · track0 = campaign/còn lại.
  int get bgmTrack {
    if (isBoss.value || isSurvival.value || isRush.value || isVersus.value) {
      return 1;
    }
    if (isRhythm.value || isColorRush.value || isSoda.value || isDaily.value) {
      return 2;
    }
    return 0;
  }

  // --- Ghost Replay (W20.3) ---
  final RxBool isGhostMode = false.obs;
  final RxInt ghostScore = 0.obs; // điểm ghost run đã lưu
  final RxInt ghostStep = 0.obs; // bước replay hiện tại
  List<String> _ghostMoves =
      []; // danh sách nước đi ghost (mỗi item "r1c1r2c2")
  final List<String> _moveLog = []; // log nước đi ván hiện tại (ghi khi chơi)

  // --- Daily reward ---
  final RxInt dailyStreak = 0.obs;

  // --- Win streak + thống kê (Wave 5) ---
  final RxInt winStreak = 0.obs; // thắng liên tiếp hiện tại
  final RxInt bestWinStreak = 0.obs; // kỷ lục streak
  final RxInt totalWins = 0.obs; // tổng số màn thắng
  final RxInt bestCombo = 0.obs; // combo cao nhất từng đạt
  final RxInt coinsEarnedTotal = 0.obs; // tổng xu kiếm (lifetime)

  /// Bonus xu từ win-streak ở ván vừa thắng (cho dialog).
  int lastStreakBonus = 0;

  /// Tổng sao đã đạt (mọi màn) — dùng cho thành tựu.
  int get totalStars => stars.values.fold(0, (sum, s) => sum + s);

  // --- Lives / energy ---
  static const int maxLives = 5;
  static const int regenSeconds = 15 * 60; // hồi 1 mạng mỗi 15 phút
  final RxInt lives = maxLives.obs;

  /// Đồng hồ hệ thống — tách ra để test inject được thời điểm.
  DateTime Function() clock = DateTime.now;

  /// Level cao nhất đã mở khóa.
  final RxInt unlockedLevel = 1.obs;

  /// High score & số sao (0-3) theo từng level.
  final RxMap<int, int> highScores = <int, int>{}.obs;
  final RxMap<int, int> stars = <int, int>{}.obs;

  // --- Kinh tế & booster ---
  // Wave 9: GỘP tiền tệ về 1 loại DUY NHẤT là `coins` (xu). Shard cũ đã bỏ —
  // quy đổi 1 shard = 10 xu (migrate 1 lần ở _load). Đền Neon nay tiêu xu.
  final RxInt coins = 0.obs;
  final RxInt boosterHammer = 0.obs; // đập 1 gem
  final RxInt boosterMoves = 0.obs; // +10 lượt
  final RxInt boosterSwap = 0.obs; // đổi 2 gem bất kỳ
  final RxInt boosterBomb = 0.obs; // nổ 3x3
  final RxInt boosterColor = 0.obs; // xoá 1 màu
  // Booster độc quyền (theme lá bài)
  final RxInt boosterJoker = 0.obs; // biến 1 gem thành Rainbow
  final RxInt boosterLightning = 0.obs; // sét phá nhiều gem cùng màu
  final RxInt boosterRoyal = 0.obs; // Royal Flush: nổ cả bàn
  final RxInt boosterGravity = 0.obs; // đảo trọng lực (đảo cột)

  // W18.3 — Nâng cấp booster VĨNH VIỄN (coin-sink, mua 1 lần ở Cửa hàng).
  final RxBool hammerUpgraded = false.obs; // búa phá 3×3 thay vì 1 ô
  final RxBool movesUpgraded = false.obs; // +Lượt: +15 thay vì +10

  // --- Cửa hàng trang trí (Wave 9) ---
  /// Tập id skin gem / theme bàn đã sở hữu (item miễn phí luôn có sẵn).
  final RxSet<String> ownedSkins = <String>{}.obs;
  final RxSet<String> ownedThemes = <String>{}.obs;

  /// Id skin / theme đang trang bị (áp qua [ActiveCosmetics]).
  final RxString selectedSkin = ''.obs;
  final RxString selectedTheme = ''.obs;

  /// Số sao đạt được ở ván vừa kết thúc (cho dialog celebration).
  int lastStars = 0;
  int lastCoinReward = 0;

  /// Ván vừa thắng có phải LẦN ĐẦU thắng màn đó không (chưa có sao trước đó).
  /// Wave 14: thưởng meta (Album/Heo/Giải đấu) CHỈ tính first-clear → chống farm
  /// thắng lại màn dễ. Set trong checkEnd (nhánh màn thường) TRƯỚC _saveProgress.
  bool lastFirstClear = false;

  /// Pre-game booster (chọn trước khi vào màn) — đọc 1 lần ở GameScreenController.
  bool pendingMovesBoost = false;
  bool pendingArmHammer = false;

  bool _resolved = false;
  final StorageService _store = StorageService.to;

  /// Cap số bậc streak được thưởng + xu mỗi bậc.
  static const int _streakCap = 6;
  static const int _streakStep = 5;

  /// Wave 12 — chống farm side-mode (Boss/Rhythm/Gravity/ColorRush): [kSideModeFullPlays]
  /// trận đầu MỖI NGÀY thưởng đầy, sau đó ×[kSideModeReducedMul] (vẫn chơi được,
  /// chỉ hết lợi nhuận farm vô hạn).
  static const int kSideModeFullPlays = 3;
  static const double kSideModeReducedMul = 0.3;

  /// Trần xu an toàn: SharedPreferences trên Android/iOS lưu int 32-bit
  /// (max ~2.14 tỷ). Vượt ngưỡng → lưu xuống đĩa thành số âm. Clamp dưới ngưỡng.
  static const int maxCoins = 2000000000;

  /// W22.1 — "giảm hiệu ứng động" (accessibility): tắt slow-mo, giảm shake/flash/trail.
  final RxBool juiceReduced = false.obs;

  /// W23 — tổng đóng góp Clan tích luỹ (lifetime) — nuôi thành tựu.
  final RxInt clanContribLifetime = 0.obs;

  /// W23.2 — thế giới của mini-boss đang đánh (0 = boss thường). Set ở [startBoss].
  int _miniBossWorld = 0;
  bool get isMiniBoss => _miniBossWorld > 0;
  int get miniBossWorld => _miniBossWorld;

  void toggleJuiceReduced() {
    juiceReduced.value = !juiceReduced.value;
    ActiveCosmetics.reducedMotion = juiceReduced.value; // render đọc tĩnh
    _store.setInt(StorageKeys.juiceReduced, juiceReduced.value ? 1 : 0);
  }

  @override
  void onInit() {
    super.onInit();
    if (versus) {
      _initVersus();
    } else {
      _load();
    }
  }

  /// Khởi tạo controller cho 1 bàn Versus (score mode, lượt vô hạn).
  void _initVersus() {
    _versusCfg = buildVersusLevel();
    isVersus.value = true;
    _resetRunState(moves: _versusCfg!.moves);
  }

  void _load() {
    juiceReduced.value = _store.getInt(StorageKeys.juiceReduced, def: 0) == 1;
    ActiveCosmetics.reducedMotion = juiceReduced.value;
    clanContribLifetime.value = _store.getInt(
      StorageKeys.clanContribLifetime,
      def: 0,
    );
    unlockedLevel.value = _store.getInt(StorageKeys.unlockedLevel, def: 1);
    // Xu khởi điểm (lần đầu cài/chưa có key): debug 10000 (dễ test mua), release 100.
    coins.value = _store.getInt(
      StorageKeys.coins,
      def: kDebugMode ? 10000 : 100,
    );
    boosterHammer.value = _store.getInt(StorageKeys.bHammer, def: 2);
    boosterMoves.value = _store.getInt(StorageKeys.bMoves, def: 2);
    boosterSwap.value = _store.getInt(StorageKeys.bSwap, def: 1);
    boosterBomb.value = _store.getInt(StorageKeys.bBomb, def: 1);
    boosterColor.value = _store.getInt(StorageKeys.bColor, def: 0);
    boosterJoker.value = _store.getInt(StorageKeys.bJoker, def: 1);
    boosterLightning.value = _store.getInt(StorageKeys.bLightning, def: 1);
    boosterRoyal.value = _store.getInt(StorageKeys.bRoyal, def: 0);
    boosterGravity.value = _store.getInt(StorageKeys.bGravity, def: 1);
    hammerUpgraded.value = _store.getInt(StorageKeys.upgHammer) == 1; // W18.3
    movesUpgraded.value = _store.getInt(StorageKeys.upgMoves) == 1;
    for (final lv in kLevels) {
      final hs = _store.getInt(StorageKeys.highScore(lv.index), def: -1);
      if (hs >= 0) highScores[lv.index] = hs;
      final st = _store.getInt(StorageKeys.star(lv.index), def: -1);
      if (st >= 0) stars[lv.index] = st;
    }
    dailyStreak.value = _store.getInt(StorageKeys.dailyStreak, def: 0);
    dailyChStreak.value = _store.getInt(StorageKeys.dailyChStreak, def: 0);
    dailyChBestStreak.value = _store.getInt(
      StorageKeys.dailyChBestStreak,
      def: 0,
    );
    lives.value = _store.getInt(StorageKeys.lives, def: maxLives);
    winStreak.value = _store.getInt(StorageKeys.winStreak, def: 0);
    bestWinStreak.value = _store.getInt(StorageKeys.bestWinStreak, def: 0);
    totalWins.value = _store.getInt(StorageKeys.totalWins, def: 0);
    bestCombo.value = _store.getInt(StorageKeys.bestCombo, def: 0);
    coinsEarnedTotal.value = _store.getInt(StorageKeys.coinsEarned, def: 0);
    endlessHigh.value = _store.getInt(StorageKeys.endlessHigh, def: 0);
    survivalHigh.value = _store.getInt(StorageKeys.survivalHigh, def: 0);
    zenHigh.value = _store.getInt(StorageKeys.zenHigh, def: 0);
    zenMilestoneTier.value = _store.getInt(
      StorageKeys.zenMilestoneTier,
      def: 0,
    );
    _migrateShardsToCoins(); // Wave 9: shard cũ → xu (×10), chạy 1 lần
    _loadCosmetics(); // Wave 9: skin gem / theme bàn đã sở hữu + đang chọn
    refillLives();
  }

  LevelConfig get level =>
      _bossCfg ??
      _zenCfg ??
      _endlessCfg ??
      _gravityCfg ??
      _rhythmCfg ??
      _colorRushCfg ??
      _sodaCfg ??
      _survivalCfg ??
      _labyrinthCfg ??
      _versusCfg ??
      _dailyCfg ??
      _puzzleCfg ??
      kLevels[currentLevel.value - 1];

  /// True nếu đang ở CHẾ ĐỘ PHỤ (Endless/Boss/Gravity/Rhythm/Daily/Versus) —
  /// KHÔNG thuộc 100 màn thường. Các chế độ này không tốn mạng, không đụng
  /// win-streak / level-unlock / Battle Pass / Season. Gom 1 chỗ → tránh tái
  /// diễn lỗi "quên 1 mode" ở các nhánh xử lý vòng đời màn chơi.
  bool get isSideMode =>
      isEndless.value ||
      isBoss.value ||
      isGravity.value ||
      isRhythm.value ||
      isColorRush.value ||
      isSoda.value ||
      isSurvival.value ||
      isLabyrinth.value ||
      isDaily.value ||
      isPuzzle.value ||
      isZen.value ||
      isVersus.value ||
      isRush.value;

  /// W25.3 — số mode phụ đã đạt mốc Platinum (tối đa 9, đọc chéo
  /// [SideModeRecordController], không lưu trữ riêng). Dùng cho achievement
  /// danh hiệu + node Progression Tree.
  int get platinumMilestonesCount =>
      SideModeRecordController.maybe?.claimedTier.values
          .where((t) => t >= RecordTier.platinum.index)
          .length ??
      0;

  /// Đặt cờ chế độ ĐỘC QUYỀN (đúng 1 mode bật, hoặc tất cả false = màn thường)
  /// + xoá cfg các mode không bật. Gom 1 chỗ → 5 hàm start* khỏi lặp 8 dòng cờ.
  void _enterMode({
    bool endless = false,
    bool boss = false,
    bool gravity = false,
    bool rhythm = false,
    bool colorRush = false,
    bool soda = false,
    bool survival = false,
    bool labyrinth = false,
    bool daily = false,
    bool puzzle = false,
    bool zen = false,
    bool rush = false,
  }) {
    isEndless.value = endless;
    isBoss.value = boss;
    isGravity.value = gravity;
    isRhythm.value = rhythm;
    isColorRush.value = colorRush;
    isSoda.value = soda;
    isSurvival.value = survival;
    isLabyrinth.value = labyrinth;
    isDaily.value = daily;
    isPuzzle.value = puzzle;
    isZen.value = zen;
    isRush.value = rush;
    _miniBossWorld = 0; // W23.2 — reset; startBoss set lại nếu là mini-boss
    isGhostMode.value = false;
    ghostScore.value = 0;
    ghostStep.value = 0;
    _ghostMoves = [];
    isVersus.value =
        false; // versus chỉ bật qua _initVersus; mọi start* khác tắt
    // Wave 16 fix: pity là DDA của MÀN THƯỜNG (đọc theo currentLevel ở startLevel).
    // Reset 0 khi vào side-mode → tránh rò rỉ boost (_luckyRate/_refillColor đọc
    // thẳng pity.value) sang Survival/Endless... nếu vừa thua nhiều ở màn thường.
    pity.value = 0;
    if (!endless) _endlessCfg = null;
    if (!boss) _bossCfg = null;
    if (!zen) _zenCfg = null;
    if (!gravity) _gravityCfg = null;
    if (!rhythm) _rhythmCfg = null;
    if (!colorRush) _colorRushCfg = null;
    if (!soda) _sodaCfg = null;
    if (!survival) _survivalCfg = null;
    if (!labyrinth) _labyrinthCfg = null;
    if (!daily) _dailyCfg = null;
    if (!puzzle) {
      _puzzleCfg = null;
      _puzzleDef = null;
    }
    _versusCfg = null;
    _moveLog.clear(); // H1 fix: xóa log nước đi từ ván cũ khi bắt đầu mode mới
  }

  /// Reset state CHUNG của 1 ván mới (mọi mode dùng) → khỏi lặp 12 dòng/hàm.
  void _resetRunState({required int moves, int target = 0, int time = 0}) {
    score.value = 0;
    comboCount.value = 0;
    runMaxCombo.value = 0;
    // W25.1 Phase 1C — "Thử Thách" (hard variant, tự chọn sau Gold): ít lượt
    // hơn, đổi lấy thưởng cao hơn ở discountSideModeReward(). Chỉ áp dụng khi
    // mode có đếm lượt thật (moves > 0) — không đụng mode time/score-thuần.
    final hvKind = SideModeRecordController.maybe?.activeKind;
    final hardVariantOn =
        hvKind != null &&
        (SideModeRecordController.maybe?.hardVariantEnabled(hvKind) ?? false);
    movesLeft.value = (hardVariantOn && moves > 0)
        ? (moves * kHardVariantMovesMul).ceil()
        : moves;
    targetScore.value = target;
    collected.value = 0;
    jellyCleared.value = 0;
    jellyTotal.value = 0;
    timeLeft.value = time;
    dropped.value = 0;
    obstacleCleared.value = 0;
    obstacleTotal.value = 0;
    sodaFill.value = 0; // Soda: mực nước về 0
    sodaCollected.value = 0;
    // Order: khởi tạo bộ đếm 0 khớp số mục tiêu con của màn (rỗng cho mode khác).
    orderProgress.assignAll(List<int>.filled(level.orders.length, 0));
    // Bom: engine sẽ seed lại ở onLoad; reset trạng thái HUD + cờ nổ.
    bombsLeft.value = 0;
    bombMinTimer.value = 0;
    bombExploded.value = false;
    dispenserCountdown.value =
        0; // engine seed lại ở onLoad nếu màn có dispenser
    tideOverflow.value = false; // Triều dâng (Survival): reset trạng thái ngập
    tideLevel.value = 0.0;
    _resolved = false;
  }
}
