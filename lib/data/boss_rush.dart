import 'dart:math';

import '../logic/boss_tile.dart';
import 'levels.dart';
import 'worlds.dart';

/// I43: trần hệ số tăng độ khó theo stage — tránh targetScore leo vô hạn khi
/// người chơi giỏi kéo chuỗi rất dài.
const double bossRushStageScaleCap = 2.5;

/// I43: hệ số nhân targetScore theo [stage], +5%/stage, chặn ở
/// [bossRushStageScaleCap].
double bossRushStageMultiplier(int stage) =>
    (1.0 + stage * 0.05).clamp(1.0, bossRushStageScaleCap);

/// I43: sinh 1 [PopLevel] cho Boss Rush [stage], rút rows/cols/colorCount từ
/// 1 level thật thuộc world ngẫu nhiên trong khoảng đã unlock
/// (0..[maxUnlockedWorld]) — seed bằng [stage] nên deterministic (test được),
/// KHÔNG tra `kLevels` theo id (khác id âm, không đụng storage per-level).
/// Mọi bàn đều có boss tile (khối 2x2 mép trên, canh giữa — theo đúng
/// convention milestone thật ở `levels.dart`).
PopLevel bossRushLevelForStage(int stage, int maxUnlockedWorld) {
  final rng = Random(stage * 7919 + maxUnlockedWorld);
  final worldIdx = rng.nextInt(
    maxUnlockedWorld.clamp(0, kWorlds.length - 1) + 1,
  );
  final worldLevels = kLevels
      .where((l) => kWorlds[worldIdx].contains(l.id))
      .toList();
  final source = worldLevels[rng.nextInt(worldLevels.length)];
  final rows = source.rows;
  final cols = source.cols;
  final spec = BossTileSpec(
    row: 0,
    col: (cols - 2) ~/ 2,
    height: 2,
    width: 2,
    startHp: (6 + stage ~/ 2).clamp(6, 24),
  );
  assert(spec.fitsBoard(rows, cols), 'boss tile phải luôn vừa bàn nguồn');
  final baseTarget = (source.targetScore * bossTargetMultiplier).round();
  final targetScore = (baseTarget * bossRushStageMultiplier(stage)).round();
  return PopLevel(
    id: -100 - stage,
    rows: rows,
    cols: cols,
    colorCount: source.colorCount,
    targetScore: targetScore,
    bossTileSpec: spec,
  );
}
