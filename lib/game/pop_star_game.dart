import 'dart:math';

import 'package:flame/game.dart';

import '../data/levels.dart';
import '../logic/pop_collapse.dart';
import '../logic/pop_detector.dart';
import '../presentation/controllers/game_controller.dart';
import 'block_component.dart';

/// Bàn PopStar: tap 1 ô, nổ nhóm cùng màu liền kề (≥2), cột rơi + dồn trái.
/// Không dùng Flame TapDetector — tap đến từ GestureDetector ở game_screen.dart
/// qua [handleTap], tránh rủi ro tương thích API giữa các bản Flame.
class PopStarGame extends FlameGame {
  PopStarGame(this.controller);

  final GameController controller;

  late int rows;
  late int cols;
  late double cellSize;
  double _boardLeft = 0;
  double _boardTop = 0;
  late List<List<int?>> colorGrid;
  List<List<int?>>? _undoGrid;
  final _rng = Random();

  @override
  Future<void> onLoad() async {
    final level = controller.currentLevel;
    rows = level.rows;
    cols = level.cols;
    colorGrid = List.generate(
      rows,
      (_) => List.generate(cols, (_) => _rng.nextInt(level.colorCount)),
    );
    controller.activeGame = this;
    _layout();
    _rebuildBoard();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _layout();
      _rebuildBoard();
    }
  }

  void _layout() {
    cellSize = min(size.x / cols, size.y / rows);
    // canh giữa bàn trong vùng chơi
    _boardLeft = (size.x - cols * cellSize) / 2;
    _boardTop = (size.y - rows * cellSize) / 2;
  }

  /// Ô (row, col) tại [pos] trong không gian game, hoặc null nếu ngoài bàn.
  Point<int>? cellAt(Vector2 pos) {
    final col = ((pos.x - _boardLeft) / cellSize).floor();
    final row = ((pos.y - _boardTop) / cellSize).floor();
    if (row < 0 || row >= rows || col < 0 || col >= cols) return null;
    return Point(row, col);
  }

  /// [pos] toạ độ trong không gian game (đã convert từ local position ở UI).
  void handleTap(Vector2 pos) {
    final cell = cellAt(pos);
    if (cell == null) return;
    _tryPop(cell.x, cell.y);
  }

  void _tryPop(int row, int col) {
    final group = findConnectedGroup(colorGrid, row, col);
    if (group.length < 2) return;
    _saveUndo();
    for (final p in group) {
      colorGrid[p.x][p.y] = null;
    }
    controller.addScore(scoreForGroup(group.length));
    applyGravityAndCollapse(colorGrid);
    _rebuildBoard();
    _checkEnd();
  }

  void triggerBomb(int row, int col) {
    _saveUndo();
    for (var r = row - 1; r <= row + 1; r++) {
      for (var c = col - 1; c <= col + 1; c++) {
        if (r >= 0 && r < rows && c >= 0 && c < cols) colorGrid[r][c] = null;
      }
    }
    applyGravityAndCollapse(colorGrid);
    _rebuildBoard();
    _checkEnd();
  }

  void shuffleBoard() {
    _saveUndo();
    final values = [
      for (final row in colorGrid)
        for (final v in row) ?v,
    ];
    values.shuffle(_rng);
    var i = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (colorGrid[r][c] != null) colorGrid[r][c] = values[i++];
      }
    }
    _rebuildBoard();
    _checkEnd();
  }

  bool undo() {
    final saved = _undoGrid;
    if (saved == null) return false;
    colorGrid = saved;
    _undoGrid = null;
    _rebuildBoard();
    return true;
  }

  void _saveUndo() {
    _undoGrid = colorGrid.map((row) => List<int?>.from(row)).toList();
  }

  void _checkEnd() {
    final remaining = colorGrid
        .expand((row) => row)
        .where((v) => v != null)
        .length;
    if (remaining == 0) {
      controller.addScore(clearBoardBonus);
      controller.checkEnd(true);
    } else if (!hasAnyMovableGroup(colorGrid)) {
      controller.checkEnd(false);
    }
  }

  void _rebuildBoard() {
    children.whereType<BlockComponent>().toList().forEach(remove);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final color = colorGrid[r][c];
        if (color == null) continue;
        add(
          BlockComponent(
            colorIndex: color,
            position: Vector2(
              _boardLeft + c * cellSize,
              _boardTop + r * cellSize,
            ),
            size: Vector2.all(cellSize),
          ),
        );
      }
    }
  }
}
