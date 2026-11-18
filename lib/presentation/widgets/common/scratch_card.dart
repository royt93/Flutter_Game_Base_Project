import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Whether [ratio] of the cover has been scratched past [threshold]. The
/// comparison is strict (`>`), so a ratio exactly equal to it is not enough.
bool scratchThresholdReached(double ratio, {double threshold = 0.6}) =>
    ratio > threshold;

/// A `columns` x `rows` bitmap of which cover cells a scratch has cleared, so
/// progress is measured on a coarse grid instead of by reading pixels.
///
/// A cell counts as cleared once its center lies within the brush radius
/// (plus half a cell diagonal) of a scratched segment, and stays cleared.
/// Throws [ArgumentError] if [columns] or [rows] is not positive.
class ScratchCoverageGrid {
  ScratchCoverageGrid({this.columns = 48, this.rows = 32})
    : _cells = List<bool>.filled(_validatedCellCount(columns, rows), false);

  static int _validatedCellCount(int columns, int rows) {
    if (columns <= 0) {
      throw ArgumentError.value(columns, 'columns', 'must be positive');
    }
    if (rows <= 0) {
      throw ArgumentError.value(rows, 'rows', 'must be positive');
    }
    return columns * rows;
  }

  final int columns;
  final int rows;
  final List<bool> _cells;
  int _covered = 0;

  /// Number of cells cleared so far.
  int get coveredCount => _covered;
  int get cellCount => _cells.length;

  /// Cleared fraction of all cells, from 0.0 to 1.0.
  double get ratio => _covered / _cells.length;

  /// Clears every cell near the line from [start] to [end], in the local
  /// coordinates of a cover of [size] with a brush of [brushWidth], and
  /// returns how many cells were newly cleared (0 for an already-cleared
  /// area). Returns 0 and changes nothing if [size] or [brushWidth] is not
  /// positive.
  int markSegment({
    required Offset start,
    required Offset end,
    required Size size,
    required double brushWidth,
  }) {
    if (size.width <= 0 || size.height <= 0 || brushWidth <= 0) return 0;
    final cellWidth = size.width / columns;
    final cellHeight = size.height / rows;
    final cellRadius =
        math.sqrt(cellWidth * cellWidth + cellHeight * cellHeight) / 2;
    final radius = brushWidth / 2 + cellRadius;
    final minX = math.max(
      0,
      ((math.min(start.dx, end.dx) - radius) / cellWidth).floor(),
    );
    final maxX = math.min(
      columns - 1,
      ((math.max(start.dx, end.dx) + radius) / cellWidth).floor(),
    );
    final minY = math.max(
      0,
      ((math.min(start.dy, end.dy) - radius) / cellHeight).floor(),
    );
    final maxY = math.min(
      rows - 1,
      ((math.max(start.dy, end.dy) + radius) / cellHeight).floor(),
    );
    var added = 0;
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final center = Offset((x + 0.5) * cellWidth, (y + 0.5) * cellHeight);
        if (_distanceToSegment(center, start, end) > radius) continue;
        final index = y * columns + x;
        if (_cells[index]) continue;
        _cells[index] = true;
        _covered++;
        added++;
      }
    }
    return added;
  }

  static double _distanceToSegment(Offset point, Offset start, Offset end) {
    final delta = end - start;
    final lengthSquared = delta.distanceSquared;
    if (lengthSquared == 0) return (point - start).distance;
    final t =
        (((point - start).dx * delta.dx + (point - start).dy * delta.dy) /
                lengthSquared)
            .clamp(0.0, 1.0);
    return (point - (start + delta * t)).distance;
  }
}

/// A scratch-off card: finger drags wipe the [cover] away to uncover [prize].
///
/// Progress is counted on a [columns] x [rows] grid. Once the cleared
/// fraction is greater than [threshold], the whole cover is removed and the
/// callbacks fire once per reveal. A revealed card stays revealed until
/// [columns] or [rows] change, which resets it to a fresh, unscratched card.
/// Only the first pointer scratches; other pointers are ignored until it is
/// lifted. For screen readers the card is a button that reveals on activate,
/// announcing [semanticLabel] and the scratched percentage.
///
/// Invalid arguments are rejected with [ArgumentError] when the state is
/// created or the widget is updated (not in the constructor): [threshold]
/// must be strictly between 0 and 1, [brushWidth] and both sides of [size]
/// finite and positive, [coverBorderRadius] finite and non-negative.
class ScratchCard extends StatefulWidget {
  const ScratchCard({
    super.key,
    required this.prize,
    required this.cover,
    this.onThresholdReached,
    this.onRevealed,
    this.threshold = 0.6,
    this.brushWidth = 36,
    this.size = const Size(280, 180),
    this.columns = 48,
    this.rows = 32,
    this.semanticLabel = 'Scratch to reveal prize',
    this.coverBorderRadius = 18,
  });

  /// Shown underneath; visible only where the cover has been scratched off.
  final Widget prize;

  /// Drawn on top and erased along the scratch path.
  final Widget cover;

  /// Called when the scratched fraction passes [threshold], just before
  /// [onRevealed]. Also fires for a screen-reader activation, and again after
  /// a reset caused by changing [columns] or [rows].
  final VoidCallback? onThresholdReached;

  /// Called right after [onThresholdReached] when the cover is removed.
  final VoidCallback? onRevealed;

  /// Cleared fraction of the cover, strictly between 0 and 1, that must be
  /// exceeded to reveal. Default 0.6.
  final double threshold;

  /// Diameter of the scratch stroke in logical pixels. Default 36.
  final double brushWidth;

  /// Fixed size of the card; the cover and prize are laid out to fill it.
  final Size size;

  /// Grid resolution used to measure progress. Finer grids measure more
  /// precisely at higher cost. Changing either resets the card.
  final int columns;
  final int rows;

  /// Screen-reader label; the scratched percentage is exposed as its value.
  final String semanticLabel;

  /// Corner radius clipping the whole card, in logical pixels.
  final double coverBorderRadius;

  @override
  State<ScratchCard> createState() => ScratchCardState();
}

/// State of [ScratchCard]; exposes read-only scratch progress.
class ScratchCardState extends State<ScratchCard> {
  late ScratchCoverageGrid _grid;
  final List<_ScratchSegment> _segments = [];
  Offset? _lastPoint;
  int? _activePointer;
  bool _revealed = false;
  bool _thresholdNotified = false;
  double _progress = 0;

  /// Cleared fraction of the cover, 0.0 to 1.0. Not forced to 1.0 on reveal:
  /// a screen-reader reveal leaves it at whatever was scratched so far.
  double get progress => _progress;

  /// True once the threshold was passed or the card was revealed through
  /// accessibility; stays true until [ScratchCard.columns] or
  /// [ScratchCard.rows] change.
  bool get isRevealed => _revealed;

  @override
  void initState() {
    super.initState();
    _validate();
    _grid = ScratchCoverageGrid(columns: widget.columns, rows: widget.rows);
  }

  void _validate() {
    if (widget.threshold <= 0 ||
        widget.threshold >= 1 ||
        !widget.threshold.isFinite) {
      throw ArgumentError.value(
        widget.threshold,
        'threshold',
        'must be between 0 and 1',
      );
    }
    if (widget.brushWidth <= 0 || !widget.brushWidth.isFinite) {
      throw ArgumentError.value(
        widget.brushWidth,
        'brushWidth',
        'must be finite and positive',
      );
    }
    if (widget.size.width <= 0 ||
        widget.size.height <= 0 ||
        !widget.size.width.isFinite ||
        !widget.size.height.isFinite) {
      throw ArgumentError.value(
        widget.size,
        'size',
        'must be finite and positive',
      );
    }
    if (widget.coverBorderRadius < 0 || !widget.coverBorderRadius.isFinite) {
      throw ArgumentError.value(
        widget.coverBorderRadius,
        'coverBorderRadius',
        'must be finite and non-negative',
      );
    }
  }

  Offset _localPosition(Offset global) {
    final box = context.findRenderObject()! as RenderBox;
    return box.globalToLocal(global);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_revealed || _activePointer != null) return;
    _activePointer = event.pointer;
    _lastPoint = _localPosition(event.position);
    _scratchSegment(_lastPoint!, _lastPoint!);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_revealed || event.pointer != _activePointer) return;
    final current = _localPosition(event.position);
    final previous = _lastPoint;
    if (previous != null) _scratchSegment(previous, current);
    _lastPoint = current;
  }

  void _handlePointerUp(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _lastPoint = null;
  }

  void _scratchSegment(Offset start, Offset end) {
    final added = _grid.markSegment(
      start: start,
      end: end,
      size: widget.size,
      brushWidth: widget.brushWidth,
    );
    if (added == 0) return;
    _segments.add(_ScratchSegment(start, end));
    _progress = _grid.ratio;
    if (scratchThresholdReached(_progress, threshold: widget.threshold)) {
      _reveal();
    } else {
      setState(() {});
    }
  }

  void _reveal() {
    if (_revealed) return;
    _revealed = true;
    _lastPoint = null;
    if (!_thresholdNotified) {
      _thresholdNotified = true;
      widget.onThresholdReached?.call();
      widget.onRevealed?.call();
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant ScratchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validate();
    if (oldWidget.rows != widget.rows || oldWidget.columns != widget.columns) {
      _grid = ScratchCoverageGrid(columns: widget.columns, rows: widget.rows);
      _segments.clear();
      _progress = 0;
      _revealed = false;
      _thresholdNotified = false;
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticLabel,
    value: '${(_progress * 100).round()}% scratched',
    button: !_revealed,
    onTap: _revealed ? null : _reveal,
    child: SizedBox.fromSize(
      size: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.coverBorderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(child: widget.prize),
            if (!_revealed)
              _ScratchCoverLayer(
                segments: _segments,
                brushWidth: widget.brushWidth,
                child: widget.cover,
              ),
            if (!_revealed)
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _handlePointerDown,
                onPointerMove: _handlePointerMove,
                onPointerUp: _handlePointerUp,
                onPointerCancel: _handlePointerUp,
              ),
          ],
        ),
      ),
    ),
  );
}

class _ScratchSegment {
  const _ScratchSegment(this.start, this.end);

  final Offset start;
  final Offset end;
}

class _ScratchCoverLayer extends SingleChildRenderObjectWidget {
  const _ScratchCoverLayer({
    required this.segments,
    required this.brushWidth,
    required super.child,
  });

  final List<_ScratchSegment> segments;
  final double brushWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderScratchCoverLayer(segments, brushWidth);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderScratchCoverLayer renderObject,
  ) {
    renderObject
      ..segments = segments
      ..brushWidth = brushWidth;
  }
}

class _RenderScratchCoverLayer extends RenderProxyBox {
  _RenderScratchCoverLayer(this._segments, this._brushWidth);

  List<_ScratchSegment> _segments;
  double _brushWidth;
  final Paint _clearPaint = Paint()
    ..blendMode = BlendMode.clear
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  set segments(List<_ScratchSegment> value) {
    _segments = value;
    markNeedsPaint();
  }

  set brushWidth(double value) {
    if (_brushWidth == value) return;
    _brushWidth = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.saveLayer(offset & size, Paint());
    canvas.clipRect(offset & size);
    super.paint(context, offset);
    _clearPaint.strokeWidth = _brushWidth;
    for (final segment in _segments) {
      canvas.drawLine(
        segment.start + offset,
        segment.end + offset,
        _clearPaint,
      );
    }
    canvas.restore();
  }
}
