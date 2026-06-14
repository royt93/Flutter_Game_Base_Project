import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/neon_theme.dart';
import '../../logic/gem_data.dart';
import '../../logic/versus_board.dart';
import 'gem_painter.dart';

/// Render 1 bàn Versus bằng widget nhẹ (CustomPaint) + vuốt để đổi gem kề, có
/// ANIMATION trượt: hợp lệ → trượt rồi đổi thật; không match → trượt-nhún rồi
/// trả lại (phản hồi rõ "đã nhận thao tác"). Dùng [paintGem] → cùng hình lá bài
/// với game chính (không còn ô vuông "kì quặc").
class VersusBoardView extends StatefulWidget {
  final VersusBoard board;
  final Color accent;

  /// Gọi khi swap HỢP LỆ (đã xác định tạo match) — tầng trên commit + tính điểm.
  final void Function(Cell a, Cell b) onSwap;

  /// Bump để vẽ lại sau mỗi nước đi / nhận rác.
  final int repaint;

  /// Cho phép tương tác (false khi ván kết thúc / đang chờ).
  final bool enabled;

  const VersusBoardView({
    super.key,
    required this.board,
    required this.accent,
    required this.onSwap,
    required this.repaint,
    this.enabled = true,
  });

  @override
  State<VersusBoardView> createState() => _VersusBoardViewState();
}

class _VersusBoardViewState extends State<VersusBoardView>
    with SingleTickerProviderStateMixin {
  Offset? _dragStart;
  Cell? _startCell;

  late final AnimationController _swap = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 170));
  Cell? _animA, _animB;
  bool _committing = false;

  @override
  void initState() {
    super.initState();
    _swap.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        final a = _animA, b = _animB, commit = _committing;
        _animA = null;
        _animB = null;
        _swap.reset();
        if (commit && a != null && b != null) widget.onSwap(a, b);
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _swap.dispose();
    super.dispose();
  }

  Cell? _cellAt(Offset local, double cell) {
    final c = (local.dx / cell).floor();
    final r = (local.dy / cell).floor();
    if (r < 0 || r >= widget.board.rows || c < 0 || c >= widget.board.cols) {
      return null;
    }
    return Cell(r, c);
  }

  void _trySwipe(Cell start, int dr, int dc) {
    if (!widget.enabled || _swap.isAnimating) return;
    final target = Cell(start.row + dr, start.col + dc);
    if (target.row < 0 ||
        target.row >= widget.board.rows ||
        target.col < 0 ||
        target.col >= widget.board.cols) {
      return;
    }
    _animA = start;
    _animB = target;
    _committing = widget.board.wouldMatch(start, target);
    _swap.forward(from: 0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final cell = side / widget.board.cols;
        return Center(
          child: SizedBox(
            width: cell * widget.board.cols,
            height: cell * widget.board.rows,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: widget.enabled
                  ? (d) {
                      _dragStart = d.localPosition;
                      _startCell = _cellAt(d.localPosition, cell);
                    }
                  : null,
              onPanUpdate: widget.enabled
                  ? (d) {
                      final start = _startCell;
                      final from = _dragStart;
                      if (start == null || from == null) return;
                      final delta = d.localPosition - from;
                      if (delta.distance < cell * 0.35) return;
                      _startCell = null;
                      _dragStart = null;
                      if (delta.dx.abs() > delta.dy.abs()) {
                        _trySwipe(start, 0, delta.dx > 0 ? 1 : -1);
                      } else {
                        _trySwipe(start, delta.dy > 0 ? 1 : -1, 0);
                      }
                    }
                  : null,
              onPanEnd: widget.enabled
                  ? (_) {
                      _startCell = null;
                      _dragStart = null;
                    }
                  : null,
              child: AnimatedBuilder(
                animation: _swap,
                builder: (context, _) => CustomPaint(
                  painter: _BoardPainter(
                    board: widget.board,
                    accent: widget.accent,
                    cell: cell,
                    repaint: widget.repaint,
                    animA: _animA,
                    animB: _animB,
                    progress: _swap.value,
                    committing: _committing,
                  ),
                  size: Size(cell * widget.board.cols, cell * widget.board.rows),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  final VersusBoard board;
  final Color accent;
  final double cell;
  final int repaint;
  final Cell? animA;
  final Cell? animB;
  final double progress;
  final bool committing;

  _BoardPainter({
    required this.board,
    required this.accent,
    required this.cell,
    required this.repaint,
    required this.animA,
    required this.animB,
    required this.progress,
    required this.committing,
  });

  Offset _center(int r, int c) =>
      Offset(c * cell + cell / 2, r * cell + cell / 2);

  @override
  void paint(Canvas canvas, Size size) {
    // khay nền
    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12));
    canvas.drawRRect(
        rrect, Paint()..color = NeonTheme.panel.withValues(alpha: 0.35));
    canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = accent.withValues(alpha: 0.5));

    // shift của 2 ô đang animate: commit → trượt hẳn (0→1); không match →
    // nhún tới 0.45 rồi về (sin) để báo "không hợp lệ".
    final shift = committing ? progress : math.sin(progress * math.pi) * 0.45;

    for (int r = 0; r < board.rows; r++) {
      for (int c = 0; c < board.cols; c++) {
        final color = board.grid[r][c];
        if (color == null) continue;
        Offset pos = _center(r, c);
        final cur = Cell(r, c);
        if (cur == animA && animB != null) {
          pos = Offset.lerp(_center(r, c), _center(animB!.row, animB!.col), shift)!;
        } else if (cur == animB && animA != null) {
          pos = Offset.lerp(_center(r, c), _center(animA!.row, animA!.col), shift)!;
        }
        paintGem(
          canvas,
          color: color,
          type: board.typeAt(r, c),
          center: pos,
          cell: cell,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) =>
      old.repaint != repaint ||
      old.progress != progress ||
      old.animA != animA ||
      old.accent != accent;
}
