import 'dart:math';

enum BossSkillType { freezeRandomCells, spawnObstacle }

/// Pure spec cho boss skill.
class BossSkill {
  const BossSkill({
    required this.skillType,
    required this.triggerEveryNMoves,
    this.paramCount = 2,
  });

  final BossSkillType skillType;
  final int triggerEveryNMoves;
  final int paramCount;

  bool shouldTrigger(int currentMoves) =>
      currentMoves > 0 && currentMoves % triggerEveryNMoves == 0;
}

/// Pure function: Đóng băng N ô ngẫu nhiên trong [grid]/[lockGrid] dùng [seed] cố định.
/// Trả về số ô thực sự vừa bị đóng băng.
int freezeRandomCells({
  required List<List<int?>> grid,
  required List<List<int>> lockGrid,
  required int count,
  required int seed,
  int lockDuration = 3,
}) {
  final rows = grid.length;
  if (rows == 0) return 0;
  final cols = grid[0].length;

  final candidates = <Point<int>>[];
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      // Chỉ đóng băng ô có gem màu (grid[r][c] >= 0) và CHƯA bị lock (lockGrid[r][c] == 0)
      if (grid[r][c] != null && grid[r][c]! >= 0 && lockGrid[r][c] == 0) {
        candidates.add(Point(r, c));
      }
    }
  }

  if (candidates.isEmpty) return 0;

  final rng = Random(seed);
  candidates.shuffle(rng);

  final toFreezeCount = min(count, candidates.length);
  for (var i = 0; i < toFreezeCount; i++) {
    final p = candidates[i];
    lockGrid[p.x][p.y] = lockDuration;
  }

  return toFreezeCount;
}

/// Pure function: Sinh [count] obstacle mới (-1) trên ô trống (null) trong [grid] dùng [seed] cố định.
/// Trả về số obstacle thực sự vừa sinh.
int spawnObstacles({
  required List<List<int?>> grid,
  required int count,
  required int seed,
}) {
  final rows = grid.length;
  if (rows == 0) return 0;
  final cols = grid[0].length;

  final emptyCells = <Point<int>>[];
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (grid[r][c] == null) {
        emptyCells.add(Point(r, c));
      }
    }
  }

  if (emptyCells.isEmpty) return 0;

  final rng = Random(seed);
  emptyCells.shuffle(rng);

  final toSpawn = min(count, emptyCells.length);
  for (var i = 0; i < toSpawn; i++) {
    final p = emptyCells[i];
    grid[p.x][p.y] = -1; // Standard obstacle durability -1
  }

  return toSpawn;
}
