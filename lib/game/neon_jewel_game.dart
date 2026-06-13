import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

import '../core/neon_theme.dart';
import '../logic/gem_data.dart';
import '../logic/match_detector.dart';
import '../presentation/controllers/game_controller.dart';
import 'gem_component.dart';

/// Game match-3 neon chính (Flame). Sở hữu lưới GemComponent và điều phối
/// toàn bộ vòng lặp: swap → match → nổ → trọng lực → cascade.
class NeonJewelGame extends FlameGame with TapCallbacks {
  final GameController controller;
  final int rows;
  final int cols;
  final int colorCount;

  /// Callback báo kết quả ván ('win' | 'lose') cho tầng UI hiển thị dialog.
  final void Function(String result) onGameEnd;

  NeonJewelGame({
    required this.controller,
    required this.rows,
    required this.cols,
    required this.colorCount,
    required this.onGameEnd,
  });

  final _rnd = math.Random();
  late List<List<GemComponent?>> grid;
  late double cellSize;
  late Vector2 boardOrigin;

  GemComponent? _selected;
  bool _busy = false;

  @override
  Color backgroundColor() => const Color(0x00000000); // để nền gradient Flutter lộ ra

  @override
  Future<void> onLoad() async {
    _layout();
    _fillInitialBoard();
  }

  void _layout() {
    final availW = size.x * 0.96;
    cellSize = availW / cols;
    final boardW = cellSize * cols;
    final boardH = cellSize * rows;
    boardOrigin = Vector2((size.x - boardW) / 2, (size.y - boardH) / 2);
  }

  Vector2 _cellCenter(int r, int c) => Vector2(
        boardOrigin.x + c * cellSize + cellSize / 2,
        boardOrigin.y + r * cellSize + cellSize / 2,
      );

  GemColor _randomColor() => GemColor.values[_rnd.nextInt(colorCount)];

  void _fillInitialBoard() {
    grid = List.generate(rows, (_) => List<GemComponent?>.filled(cols, null));
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        GemColor color;
        // tránh tạo match-3 ngay từ đầu
        do {
          color = _randomColor();
        } while (_wouldMatchAt(r, c, color));
        final g = GemComponent(
          color: color,
          type: GemType.normal,
          row: r,
          col: c,
          position: _cellCenter(r, c),
          cellSize: cellSize,
        );
        grid[r][c] = g;
        add(g);
      }
    }
  }

  bool _wouldMatchAt(int r, int c, GemColor color) {
    if (c >= 2 && grid[r][c - 1]?.color == color && grid[r][c - 2]?.color == color) {
      return true;
    }
    if (r >= 2 && grid[r - 1][c]?.color == color && grid[r - 2][c]?.color == color) {
      return true;
    }
    return false;
  }

  List<List<GemColor?>> _colorGrid() => [
        for (int r = 0; r < rows; r++)
          [for (int c = 0; c < cols; c++) grid[r][c]?.color],
      ];

  // --------------------------------------------------------------------------
  // Tương tác chạm
  // --------------------------------------------------------------------------
  @override
  void onTapDown(TapDownEvent event) {
    if (_busy) return;
    final cell = _cellAtPosition(event.localPosition);
    if (cell == null) return;
    final gem = grid[cell.row][cell.col];
    if (gem == null) return;

    if (_selected == null) {
      _selected = gem..selected = true;
    } else if (identical(_selected, gem)) {
      gem.selected = false;
      _selected = null;
    } else if (_isAdjacent(_selected!, gem)) {
      final a = _selected!..selected = false;
      _selected = null;
      _trySwap(a, gem);
    } else {
      _selected!.selected = false;
      _selected = gem..selected = true;
    }
  }

  Cell? _cellAtPosition(Vector2 p) {
    final lx = p.x - boardOrigin.x;
    final ly = p.y - boardOrigin.y;
    if (lx < 0 || ly < 0) return null;
    final c = lx ~/ cellSize;
    final r = ly ~/ cellSize;
    if (r < 0 || r >= rows || c < 0 || c >= cols) return null;
    return Cell(r, c);
  }

  bool _isAdjacent(GemComponent a, GemComponent b) =>
      (a.row == b.row && (a.col - b.col).abs() == 1) ||
      (a.col == b.col && (a.row - b.row).abs() == 1);

  // --------------------------------------------------------------------------
  // Vòng lặp game
  // --------------------------------------------------------------------------
  Future<void> _trySwap(GemComponent a, GemComponent b) async {
    _busy = true;
    await _animateSwap(a, b);
    _swapInGrid(a, b);

    final isSpecialSwap = a.type == GemType.rainbow || b.type == GemType.rainbow;
    final matches = MatchDetector.findMatches(_colorGrid());

    if (matches.isEmpty && !isSpecialSwap) {
      // không hợp lệ → đảo lại
      await _animateSwap(a, b);
      _swapInGrid(a, b);
    } else {
      controller.useMove();
      if (isSpecialSwap) {
        // kích hoạt rainbow: xóa toàn bộ gem cùng màu với gem còn lại
        final rainbow = a.type == GemType.rainbow ? a : b;
        final other = a.type == GemType.rainbow ? b : a;
        final targetColor = other.type == GemType.rainbow ? _randomColor() : other.color;
        final toClear = <Cell>{Cell(rainbow.row, rainbow.col)};
        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            if (grid[r][c]?.color == targetColor) toClear.add(Cell(r, c));
          }
        }
        final expanded = _expandSpecials(toClear);
        await _clearCells(expanded);
        controller.addScore(expanded.length, 1);
        await _applyGravityAndRefill();
      }
      await _resolveAll();
      _finishMove();
    }
    _busy = false;
  }

  Future<void> _resolveAll() async {
    int combo = 0;
    while (true) {
      final matches = MatchDetector.findMatches(_colorGrid());
      if (matches.isEmpty) break;
      combo++;

      final toClear = <Cell>{};
      final newSpecials = <Cell, GemType>{};
      for (final g in matches) {
        toClear.addAll(g.cells);
        if (g.special != GemType.normal && g.specialAt != null) {
          newSpecials[g.specialAt!] = g.special;
        }
      }

      // kích hoạt special đã có sẵn nằm trong vùng xóa (chain reaction)
      var expanded = _expandSpecials(toClear);
      // những ô sắp biến thành special mới thì giữ lại, không xóa
      expanded = expanded..removeWhere((cell) => newSpecials.containsKey(cell));

      await _clearCells(expanded);
      controller.addScore(expanded.length, combo);

      // tạo gem special mới
      newSpecials.forEach((cell, type) {
        grid[cell.row][cell.col]?.type = type;
      });

      await _applyGravityAndRefill();
    }
  }

  /// Mở rộng tập ô xóa bằng cách kích hoạt các gem special bên trong nó.
  Set<Cell> _expandSpecials(Set<Cell> initial) {
    final result = <Cell>{...initial};
    final queue = <Cell>[...initial];
    while (queue.isNotEmpty) {
      final cell = queue.removeLast();
      final g = grid[cell.row][cell.col];
      if (g == null) continue;
      final extra = <Cell>[];
      switch (g.type) {
        case GemType.stripedH:
          for (int c = 0; c < cols; c++) {
            extra.add(Cell(cell.row, c));
          }
          break;
        case GemType.stripedV:
          for (int r = 0; r < rows; r++) {
            extra.add(Cell(r, cell.col));
          }
          break;
        case GemType.rainbow:
          for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
              if (grid[r][c]?.color == g.color) extra.add(Cell(r, c));
            }
          }
          break;
        case GemType.normal:
          break;
      }
      for (final e in extra) {
        if (!result.contains(e)) {
          result.add(e);
          queue.add(e);
        }
      }
    }
    return result;
  }

  Future<void> _clearCells(Set<Cell> cells) async {
    final gems = <GemComponent>[];
    for (final cell in cells) {
      final g = grid[cell.row][cell.col];
      if (g == null) continue;
      gems.add(g);
      grid[cell.row][cell.col] = null;
    }
    final futures = <Future>[];
    for (final g in gems) {
      _spawnBurst(g.position.clone(), neonColorOf(g.color));
      futures.add(_run(
        g,
        ScaleEffect.to(
          Vector2.zero(),
          EffectController(duration: 0.18, curve: Curves.easeIn),
        ),
      ));
    }
    await Future.wait(futures);
    for (final g in gems) {
      g.removeFromParent();
    }
  }

  Future<void> _applyGravityAndRefill() async {
    final futures = <Future>[];
    for (int c = 0; c < cols; c++) {
      int writeRow = rows - 1;
      // dồn gem hiện có xuống đáy
      for (int r = rows - 1; r >= 0; r--) {
        final g = grid[r][c];
        if (g != null) {
          if (writeRow != r) {
            grid[writeRow][c] = g;
            grid[r][c] = null;
            g.row = writeRow;
            g.col = c;
            futures.add(_run(
              g,
              MoveToEffect(
                _cellCenter(writeRow, c),
                EffectController(duration: 0.26, curve: Curves.bounceOut),
              ),
            ));
          }
          writeRow--;
        }
      }
      // sinh gem mới rơi từ phía trên
      final newCount = writeRow + 1;
      for (int i = 0; i < newCount; i++) {
        final targetRow = writeRow - i;
        final startRow = -1 - i;
        final g = GemComponent(
          color: _randomColor(),
          type: GemType.normal,
          row: targetRow,
          col: c,
          position: _cellCenter(startRow, c),
          cellSize: cellSize,
        );
        grid[targetRow][c] = g;
        add(g);
        futures.add(_run(
          g,
          MoveToEffect(
            _cellCenter(targetRow, c),
            EffectController(duration: 0.32, curve: Curves.bounceOut),
          ),
        ));
      }
    }
    await Future.wait(futures);
  }

  void _finishMove() {
    final result = controller.checkEnd();
    if (result != null) {
      onGameEnd(result);
    }
  }

  // --------------------------------------------------------------------------
  // Helpers animation & particle
  // --------------------------------------------------------------------------
  Future<void> _animateSwap(GemComponent a, GemComponent b) async {
    final pa = a.position.clone();
    final pb = b.position.clone();
    await Future.wait([
      _run(a, MoveToEffect(pb, EffectController(duration: 0.15))),
      _run(b, MoveToEffect(pa, EffectController(duration: 0.15))),
    ]);
  }

  void _swapInGrid(GemComponent a, GemComponent b) {
    grid[a.row][a.col] = b;
    grid[b.row][b.col] = a;
    final tr = a.row, tc = a.col;
    a.row = b.row;
    a.col = b.col;
    b.row = tr;
    b.col = tc;
  }

  Future<void> _run(Component target, Effect effect) {
    final completer = Completer<void>();
    effect.onComplete = completer.complete;
    target.add(effect);
    return completer.future;
  }

  void _spawnBurst(Vector2 position, Color color) {
    final particle = Particle.generate(
      count: 16,
      lifespan: 0.55,
      generator: (i) {
        final angle = _rnd.nextDouble() * math.pi * 2;
        final speed = 60 + _rnd.nextDouble() * 160;
        final velocity = Vector2(math.cos(angle), math.sin(angle))..scale(speed);
        return AcceleratedParticle(
          acceleration: Vector2(0, 160),
          speed: velocity,
          child: ComputedParticle(
            renderer: (canvas, p) {
              final t = 1 - p.progress;
              final paint = Paint()
                ..color = color.withOpacity(t)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
              canvas.drawCircle(Offset.zero, cellSize * 0.12 * t + 1, paint);
            },
          ),
        );
      },
    );
    add(ParticleSystemComponent(particle: particle, position: position));
  }
}
