import 'dart:math';

import 'gem_data.dart';
import 'match_detector.dart';

/// Kết quả 1 lần swap trên [VersusBoard].
class SwapResult {
  final bool valid;
  final int cleared; // tổng gem bị xoá (mọi cascade)
  final int combo; // số bậc cascade
  final int gained; // điểm cộng
  final int junkToSend; // số hàng rác gửi sang đối thủ (versus)
  final int specialsMade; // số gem đặc biệt tạo ra (cho hiệu ứng)

  const SwapResult({
    required this.valid,
    this.cleared = 0,
    this.combo = 0,
    this.gained = 0,
    this.junkToSend = 0,
    this.specialsMade = 0,
  });

  const SwapResult.invalid() : this(valid: false);
}

/// Bàn match-3 THUẦN cho chế độ Versus/Co-op (không Flame) — tái dùng
/// [MatchDetector]. Tách riêng để render bằng widget nhẹ (2 bàn trên 1 màn) +
/// unit-test logic (điểm, cascade, special gem, rác). Inject [Random] để test
/// xác định.
///
/// Special gem: match 4 → striped (nổ hàng/cột), match 5 → rainbow (xoá cùng
/// màu), giao T/L → bomb (nổ 3×3). KHÔNG có combo special+special (giữ gọn cho
/// versus); special chỉ kích hoạt khi BỊ clear trong 1 match.
class VersusBoard {
  final int rows;
  final int cols;
  final int colorCount;
  final Random _rnd;

  late List<List<GemColor?>> grid;
  late List<List<GemType>> type; // song song; chỉ có nghĩa khi grid[r][c]!=null
  int score = 0;

  VersusBoard({
    this.rows = 7,
    this.cols = 7,
    this.colorCount = 6,
    Random? rnd,
  })  : assert(colorCount >= 3 && colorCount <= GemColor.values.length),
        _rnd = rnd ?? Random() {
    _fillNoMatch();
  }

  GemColor _rndColor() => GemColor.values[_rnd.nextInt(colorCount)];

  GemType typeAt(int r, int c) =>
      grid[r][c] == null ? GemType.normal : type[r][c];

  /// Sinh bàn ban đầu KHÔNG có match sẵn (reroll ô gây match, có trần lặp).
  void _fillNoMatch() {
    grid = List.generate(
        rows, (r) => List.generate(cols, (c) => _rndColor()));
    type = List.generate(
        rows, (_) => List.filled(cols, GemType.normal, growable: false));
    var guard = 0;
    while (MatchDetector.hasMatch(grid) && guard++ < 200) {
      final cells = MatchDetector.allCells(MatchDetector.findMatches(grid));
      for (final c in cells) {
        grid[c.row][c.col] = _rndColor();
      }
    }
  }

  bool _adjacent(Cell a, Cell b) =>
      (a.row - b.row).abs() + (a.col - b.col).abs() == 1;

  bool _inBounds(Cell c) =>
      c.row >= 0 && c.row < rows && c.col >= 0 && c.col < cols;

  void _swapCells(Cell a, Cell b) {
    final tc = grid[a.row][a.col];
    grid[a.row][a.col] = grid[b.row][b.col];
    grid[b.row][b.col] = tc;
    final tt = type[a.row][a.col];
    type[a.row][a.col] = type[b.row][b.col];
    type[b.row][b.col] = tt;
  }

  /// Dry-run: swap [a],[b] có tạo match không (KHÔNG đổi bàn). Cho animation
  /// quyết định trượt-rồi-commit hay trượt-rồi-trả-lại.
  bool wouldMatch(Cell a, Cell b) {
    if (!_inBounds(a) || !_inBounds(b) || !_adjacent(a, b)) return false;
    _swapCells(a, b);
    final ok = MatchDetector.hasMatch(grid);
    _swapCells(a, b);
    return ok;
  }

  /// Thử swap 2 ô KỀ nhau. Nếu không tạo match → đảo lại, trả invalid.
  /// Nếu hợp lệ → giải toàn bộ cascade (xoá → tạo special → trọng lực → refill),
  /// cộng điểm, tính số hàng rác cần gửi (combo lớn → gửi nhiều).
  SwapResult swap(Cell a, Cell b) {
    if (!_inBounds(a) || !_inBounds(b) || !_adjacent(a, b)) {
      return const SwapResult.invalid();
    }
    _swapCells(a, b);
    var groups = MatchDetector.findMatches(grid);
    if (groups.isEmpty) {
      _swapCells(a, b); // đảo lại
      return const SwapResult.invalid();
    }
    var totalCleared = 0;
    var combo = 0;
    var gained = 0;
    var specials = 0;
    while (groups.isNotEmpty) {
      combo++;
      final base = MatchDetector.allCells(groups);
      // special CẦN TẠO step này (sống sót, không bị xoá)
      final creates = <Cell, GemType>{};
      for (final cell in MatchDetector.bombCells(groups)) {
        creates[cell] = GemType.bomb;
      }
      for (final g in groups) {
        if (g.special != GemType.normal && g.specialAt != null) {
          creates.putIfAbsent(g.specialAt!, () => g.special);
        }
      }
      // mở rộng theo special ĐANG có trong tập clear (nổ hàng/cột/3x3/màu)
      final toClear = _expand(base)..removeAll(creates.keys);
      totalCleared += toClear.length;
      gained += (toClear.length * 10 * (1 + (combo - 1) * 0.5)).round();
      for (final c in toClear) {
        grid[c.row][c.col] = null;
        type[c.row][c.col] = GemType.normal;
      }
      // đặt special mới (màu giữ nguyên, đổi type)
      creates.forEach((cell, sp) {
        if (grid[cell.row][cell.col] != null) {
          type[cell.row][cell.col] = sp;
          specials++;
        }
      });
      _collapse();
      groups = MatchDetector.findMatches(grid);
    }
    score += gained;
    final junk = combo >= 2 ? combo - 1 : 0;
    return SwapResult(
      valid: true,
      cleared: totalCleared,
      combo: combo,
      gained: gained,
      junkToSend: junk,
      specialsMade: specials,
    );
  }

  /// Mở rộng tập ô bị xoá theo hiệu ứng special (lan tới khi ổn định):
  /// striped → cả hàng/cột; bomb → 3×3; rainbow → mọi ô cùng màu.
  Set<Cell> _expand(Set<Cell> seed) {
    final out = <Cell>{...seed};
    final queue = <Cell>[...seed];
    while (queue.isNotEmpty) {
      final c = queue.removeLast();
      final color = grid[c.row][c.col];
      if (color == null) continue;
      final blast = <Cell>[];
      switch (type[c.row][c.col]) {
        case GemType.stripedH:
          for (int cc = 0; cc < cols; cc++) {
            blast.add(Cell(c.row, cc));
          }
          break;
        case GemType.stripedV:
          for (int rr = 0; rr < rows; rr++) {
            blast.add(Cell(rr, c.col));
          }
          break;
        case GemType.bomb:
          for (int dr = -1; dr <= 1; dr++) {
            for (int dc = -1; dc <= 1; dc++) {
              final n = Cell(c.row + dr, c.col + dc);
              if (_inBounds(n)) blast.add(n);
            }
          }
          break;
        case GemType.rainbow:
          for (int rr = 0; rr < rows; rr++) {
            for (int cc = 0; cc < cols; cc++) {
              if (grid[rr][cc] == color) blast.add(Cell(rr, cc));
            }
          }
          break;
        case GemType.normal:
          break;
      }
      for (final b in blast) {
        if (out.add(b)) queue.add(b);
      }
    }
    return out;
  }

  /// Trọng lực: dồn gem (kèm type) xuống đáy từng cột rồi sinh gem mới lấp trên.
  void _collapse() {
    for (int c = 0; c < cols; c++) {
      int write = rows - 1;
      for (int r = rows - 1; r >= 0; r--) {
        if (grid[r][c] != null) {
          grid[write][c] = grid[r][c];
          type[write][c] = type[r][c];
          if (write != r) {
            grid[r][c] = null;
            type[r][c] = GemType.normal;
          }
          write--;
        }
      }
      for (int r = write; r >= 0; r--) {
        grid[r][c] = _rndColor();
        type[r][c] = GemType.normal;
      }
    }
  }

  /// Nhận [n] hàng rác từ đối thủ: đẩy toàn bàn LÊN [n] hàng (mất hàng trên
  /// cùng), lấp [n] hàng đáy bằng gem ngẫu nhiên → gây áp lực/đảo lộn bàn.
  void receiveJunk(int n) {
    if (n <= 0) return;
    final shift = n.clamp(0, rows);
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows - shift; r++) {
        grid[r][c] = grid[r + shift][c];
        type[r][c] = type[r + shift][c];
      }
      for (int r = rows - shift; r < rows; r++) {
        grid[r][c] = _rndColor();
        type[r][c] = GemType.normal;
      }
    }
  }

  /// Còn ít nhất 1 nước đi hợp lệ (swap 2 ô kề tạo match)?
  bool hasMove() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        for (final d in const [Cell(0, 1), Cell(1, 0)]) {
          final b = Cell(r + d.row, c + d.col);
          if (!_inBounds(b)) continue;
          _swapCells(Cell(r, c), b);
          final has = MatchDetector.hasMatch(grid);
          _swapCells(Cell(r, c), b);
          if (has) return true;
        }
      }
    }
    return false;
  }
}
