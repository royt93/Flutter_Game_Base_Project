const magnetTileIdBase = -700;
const magnetBonusScore = 50;

bool isMagnetId(int? value) =>
    value != null && value <= magnetTileIdBase && value > -800;

int encodeMagnetTile(int colorIndex) => magnetTileIdBase - colorIndex;

int magnetColorIndex(int value) => magnetTileIdBase - value;

List<(int, int)> magnetTilesTriggeredBy(
  List<List<int?>> grid,
  int poppedColorIndex,
) {
  final matches = <(int, int)>[];
  for (var row = 0; row < grid.length; row++) {
    for (var col = 0; col < grid[row].length; col++) {
      final value = grid[row][col];
      if (isMagnetId(value) && magnetColorIndex(value!) == poppedColorIndex) {
        matches.add((row, col));
      }
    }
  }
  return matches;
}
