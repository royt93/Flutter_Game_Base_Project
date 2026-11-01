import 'dart:math' as math;

enum Match3Status { ready, playing, won, lost }

class Match3Swap {
  const Match3Swap(this.from, this.to);

  final int from;
  final int to;
}

class Match3Engine {
  Match3Engine({
    math.Random? random,
    List<int>? initialBoard,
    this.score = 0,
    int? moves,
    this.status = Match3Status.ready,
  }) : _random = random ?? math.Random(),
       moves = moves ?? maxMoves {
    if (score < 0) throw ArgumentError.value(score, 'score', 'must be >= 0');
    if (this.moves < 0 || this.moves > maxMoves) {
      throw ArgumentError.value(
        this.moves,
        'moves',
        'must be between 0 and $maxMoves',
      );
    }
    if (initialBoard != null &&
        (initialBoard.length != cellCount ||
            initialBoard.any((tile) => tile < 0 || tile >= tileKinds))) {
      throw ArgumentError.value(
        initialBoard,
        'initialBoard',
        'must contain $cellCount valid tile kinds',
      );
    }
    _board = initialBoard == null
        ? List<int>.filled(cellCount, -1)
        : List.of(initialBoard);
    if (initialBoard == null) {
      _fillBoardWithoutMatches();
      _ensurePlayableBoard();
    } else if (_matches().isNotEmpty) {
      throw ArgumentError.value(
        initialBoard,
        'initialBoard',
        'must not contain pre-existing matches',
      );
    }
    if (status == Match3Status.ready && this.moves < maxMoves) {
      throw ArgumentError.value(
        status,
        'status',
        'reduced moves require a playing or terminal state',
      );
    }
  }

  static const width = 6;
  static const cellCount = width * width;
  static const maxMoves = 20;
  static const scoreGoal = 500;
  static const tileKinds = 5;
  static const pointsPerTile = 10;

  final math.Random _random;
  late final List<int> _board;
  int score = 0;
  int moves = maxMoves;
  Match3Status status = Match3Status.ready;
  Match3Swap? lastSwap;

  List<int> get board => List.unmodifiable(_board);
  bool get isTerminal =>
      status == Match3Status.won || status == Match3Status.lost;
  bool get hasLegalMove => _hasLegalSwap();

  void shuffle() {
    _board.fillRange(0, cellCount, -1);
    _fillBoardWithoutMatches();
    _ensurePlayableBoard();
    lastSwap = null;
  }

  void _fillBoardWithoutMatches() {
    for (var index = 0; index < cellCount; index++) {
      _board[index] = _drawTileAvoidingMatch(index);
    }
  }

  void _ensurePlayableBoard() {
    if (_hasLegalSwap()) return;
    for (var i = _board.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final tile = _board[i];
      _board[i] = _board[j];
      _board[j] = tile;
    }
    if (_matches().isEmpty && _hasLegalSwap()) return;
    _fillBoardWithoutMatches();
    if (!_hasLegalSwap()) {
      _makeKnownLegalMove();
    }
  }

  void _makeKnownLegalMove() {
    _board.setAll(0, const [
      0,
      1,
      0,
      2,
      3,
      4,
      2,
      0,
      3,
      4,
      1,
      2,
      4,
      2,
      0,
      1,
      3,
      4,
      1,
      3,
      4,
      0,
      2,
      1,
      3,
      4,
      1,
      2,
      0,
      3,
      4,
      2,
      3,
      1,
      4,
      0,
    ]);
  }

  bool _hasLegalSwap() {
    for (var i = 0; i < cellCount; i++) {
      if (i % width < width - 1) {
        _swapTiles(i, i + 1);
        final matched = _matches().isNotEmpty;
        _swapTiles(i, i + 1);
        if (matched) return true;
      }
      if (i ~/ width < width - 1) {
        _swapTiles(i, i + width);
        final matched = _matches().isNotEmpty;
        _swapTiles(i, i + width);
        if (matched) return true;
      }
    }
    return false;
  }

  int _drawTileAvoidingMatch(int index) {
    final x = index % width;
    final y = index ~/ width;
    final candidates = List<int>.generate(tileKinds, (i) => i);
    candidates.shuffle(_random);
    for (final tile in candidates) {
      final horizontal =
          x >= 2 && _board[index - 1] == tile && _board[index - 2] == tile;
      final vertical =
          y >= 2 &&
          _board[index - width] == tile &&
          _board[index - 2 * width] == tile;
      if (!horizontal && !vertical) return tile;
    }
    return candidates.first;
  }

  Set<int> _matches() {
    final result = <int>{};
    for (var y = 0; y < width; y++) {
      var start = 0;
      while (start < width) {
        final tile = _board[y * width + start];
        var end = start + 1;
        while (end < width && _board[y * width + end] == tile) {
          end++;
        }
        if (end - start >= 3) {
          for (var x = start; x < end; x++) {
            result.add(y * width + x);
          }
        }
        start = end;
      }
    }
    for (var x = 0; x < width; x++) {
      var start = 0;
      while (start < width) {
        final tile = _board[start * width + x];
        var end = start + 1;
        while (end < width && _board[end * width + x] == tile) {
          end++;
        }
        if (end - start >= 3) {
          for (var y = start; y < end; y++) {
            result.add(y * width + x);
          }
        }
        start = end;
      }
    }
    return result;
  }

  bool swap(int from, int to) {
    if (status == Match3Status.won || status == Match3Status.lost) {
      return false;
    }
    if (from < 0 || from >= cellCount || to < 0 || to >= cellCount) {
      return false;
    }
    if ((from % width - to % width).abs() +
            (from ~/ width - to ~/ width).abs() !=
        1) {
      return false;
    }

    _swapTiles(from, to);
    if (_matches().isEmpty) {
      _swapTiles(from, to);
      return false;
    }

    status = Match3Status.playing;
    lastSwap = Match3Swap(from, to);
    moves--;
    _resolveCascades();
    status = score >= scoreGoal
        ? Match3Status.won
        : (moves == 0 ? Match3Status.lost : Match3Status.playing);
    return true;
  }

  void _swapTiles(int a, int b) {
    final tile = _board[a];
    _board[a] = _board[b];
    _board[b] = tile;
  }

  void _resolveCascades() {
    var cascade = 0;
    while (true) {
      final matches = _matches();
      if (matches.isEmpty) {
        _ensurePlayableBoard();
        return;
      }
      cascade++;
      score += matches.length * pointsPerTile * cascade;
      for (final index in matches) {
        _board[index] = -1;
      }
      for (var x = 0; x < width; x++) {
        var writeY = width - 1;
        for (var y = width - 1; y >= 0; y--) {
          final index = y * width + x;
          if (_board[index] != -1) {
            _board[writeY * width + x] = _board[index];
            writeY--;
          }
        }
        while (writeY >= 0) {
          _board[writeY * width + x] = _random.nextInt(tileKinds);
          writeY--;
        }
      }
    }
  }

  void reset() {
    _board.fillRange(0, cellCount, -1);
    _fillBoardWithoutMatches();
    _ensurePlayableBoard();
    score = 0;
    moves = maxMoves;
    status = Match3Status.ready;
    lastSwap = null;
  }
}
