// Settle engine THUẦN (pure Dart) cho match-3 có BỐ CỤC ĐA DẠNG (Wave 15).
//
// Tách khỏi Flame để unit-test trọng lực/refill không cần engine. Engine
// (`neon_jewel_game.dart`) gọi các hàm ở đây để biết "gem nào dời đi đâu" +
// "ô trống nào cần sinh gem mới", rồi tự lo phần animation.
//
// Phase 0 (hiện tại): WALL (ô chặn, không gem) + trọng lực LỖ-CẮT-CỘT — mỗi cột
// bị wall chia thành các ĐOẠN liền mạch; gem trong 1 đoạn chỉ dồn xuống đáy đoạn
// đó (wall chặn không cho xuyên qua), refill từ đỉnh đoạn.
//
// Mở rộng dự kiến: Phase 1 thêm trượt-chéo (gem vòng qua wall), Phase 2 thêm
// `FlowDir` (hướng trọng lực theo ô — Gravity Streams).

/// Loại ô trên bàn.
/// - play: ô chơi bình thường (có thể chứa gem, gem rơi theo trọng lực).
/// - wall: ô CHẶN — không bao giờ chứa gem, chặn gem rơi qua (tạo lỗ/hình bàn).
/// - noDrop: ô có gem nhưng gem KHÔNG bị trọng lực kéo (đảo nổi — Phase 3).
enum CellKind { play, wall, noDrop }

/// Ký tự bản đồ → CellKind. `#`/`X` = wall, `o`/`O` = noDrop, còn lại = play.
CellKind cellKindFromChar(String ch) {
  switch (ch) {
    case '#':
    case 'X':
      return CellKind.wall;
    case 'o':
    case 'O':
      return CellKind.noDrop;
    default:
      return CellKind.play;
  }
}

/// Parse bản đồ ký tự (mỗi String = 1 hàng) thành lưới [CellKind]. Mọi hàng phải
/// cùng độ dài. Khoảng trắng/`.` = ô chơi.
List<List<CellKind>> parseLayout(List<String> rowsText) {
  return [
    for (final line in rowsText)
      [for (final ch in line.split('')) cellKindFromChar(ch)],
  ];
}

/// 1 phép dời gem hiện có: từ (fromR,fromC) → (toR,toC).
class SettleMove {
  final int fromR, fromC, toR, toC;
  const SettleMove(this.fromR, this.fromC, this.toR, this.toC);

  @override
  bool operator ==(Object other) =>
      other is SettleMove &&
      other.fromR == fromR &&
      other.fromC == fromC &&
      other.toR == toR &&
      other.toC == toC;

  @override
  int get hashCode => Object.hash(fromR, fromC, toR, toC);

  @override
  String toString() => '($fromR,$fromC)->($toR,$toC)';
}

/// 1 ô trống cần sinh gem mới. [depth] = thứ tự xếp chồng từ NGUỒN (0 = gần
/// nguồn nhất) → engine dùng để đặt vị trí xuất phát animation (rơi xếp tầng).
class SettleSpawn {
  final int r, c, depth;
  const SettleSpawn(this.r, this.c, this.depth);

  @override
  bool operator ==(Object other) =>
      other is SettleSpawn && other.r == r && other.c == c && other.depth == depth;

  @override
  int get hashCode => Object.hash(r, c, depth);

  @override
  String toString() => 'spawn($r,$c,d$depth)';
}

/// Kết quả settle: danh sách dời gem + danh sách ô cần sinh gem mới.
class SettleResult {
  final List<SettleMove> moves;
  final List<SettleSpawn> spawns;
  const SettleResult(this.moves, this.spawns);
}

/// Kết quả settle TỔNG QUÁT: move cho gem hiện có (orig→final) + ô spawn gem mới.
class BoardSettle {
  final List<SettleMove> moves;
  final List<SettleSpawn> spawns;
  const BoardSettle(this.moves, this.spawns);
}

/// Settle TỔNG QUÁT (Phase 1): trọng lực xuống **+ TRƯỢT CHÉO** vòng qua tường +
/// refill từ đỉnh. Tất định & HỘI TỤ: mỗi bước chỉ đẩy gem xuống (hàng tăng) hoặc
/// sinh gem mới (số gem ≤ số ô chơi) → tổng "Σ hàng" tăng nghiêm ngặt, dừng chắc.
///
/// Gem hiện có được đánh số theo thứ tự quét; trả về [SettleMove] (orig→final) CHỈ
/// cho gem ĐỔI ô. Gem mới (spawn ở đỉnh, có thể trượt chéo vào hốc) → [SettleSpawn]
/// (r,c = ô cuối; depth dùng cho stagger animation theo cột, engine tự tính lại).
///
/// Quy tắc trượt chéo (kiểu Candy Crush): gem (r,c) KHÔNG rơi thẳng được (ô dưới
/// bị tường/đầy) → trượt xuống-chéo (r+1, c±1) nếu ô đó TRỐNG và ô ngay trên đích
/// (r, c±1) KHÔNG phải gem (tường/trống → không ai rơi thẳng lấp đích). Thứ tự
/// dc cố định [-1,+1] → tất định.
BoardSettle settleBoard(
  int rows,
  int cols,
  CellKind Function(int r, int c) kindAt,
  bool Function(int r, int c) occupied, {
  bool diagonal = true,
}) {
  const empty = -1, wall = -2;
  final g = List.generate(
    rows,
    (r) => List.generate(
      cols,
      (c) => kindAt(r, c) == CellKind.wall ? wall : (occupied(r, c) ? 0 : empty),
    ),
  );
  // Đánh số gem hiện có theo thứ tự quét + ghi ô gốc.
  final origR = <int>[], origC = <int>[];
  var id = 0;
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      if (g[r][c] == 0) {
        g[r][c] = id;
        origR.add(r);
        origC.add(c);
        id++;
      }
    }
  }
  final existing = id;
  var spawnCount = 0;
  bool isGem(int v) => v >= 0;

  // Rơi thẳng 1 lượt quét (đáy-lên mỗi cột).
  bool verticalPass() {
    var moved = false;
    for (int c = 0; c < cols; c++) {
      for (int r = rows - 2; r >= 0; r--) {
        if (isGem(g[r][c]) && g[r + 1][c] == empty) {
          g[r + 1][c] = g[r][c];
          g[r][c] = empty;
          moved = true;
        }
      }
    }
    return moved;
  }

  // Trượt chéo 1 lượt: gem KHÔNG rơi thẳng được (ô dưới ≠ trống) → trượt (r+1,c±1)
  // nếu ô đó TRỐNG và ô-trên-đích là TƯỜNG (đích không thể được lấp bằng rơi thẳng
  // → không "ăn trộm" ô đáng lẽ rơi thẳng vào). Chạy SAU khi rơi-thẳng đã cạn.
  bool diagonalPass() {
    var moved = false;
    for (int c = 0; c < cols; c++) {
      for (int r = rows - 2; r >= 0; r--) {
        if (!isGem(g[r][c]) || g[r + 1][c] == empty) continue;
        for (final dc in const [-1, 1]) {
          final tc = c + dc;
          if (tc < 0 || tc >= cols) continue;
          if (g[r + 1][tc] != empty) continue;
          if (g[r][tc] != wall) continue; // ô-trên-đích phải là tường
          g[r + 1][tc] = g[r][c];
          g[r][c] = empty;
          moved = true;
          break;
        }
      }
    }
    return moved;
  }

  // Sinh gem mới ở mọi ô đỉnh (hàng 0) còn trống.
  bool spawnPass() {
    var moved = false;
    for (int c = 0; c < cols; c++) {
      if (g[0][c] == empty) {
        g[0][c] = existing + spawnCount;
        spawnCount++;
        moved = true;
      }
    }
    return moved;
  }

  var any = true, guard = 0;
  final guardMax = rows * cols * 8 + 16;
  while (any && guard++ < guardMax) {
    any = false;
    while (verticalPass()) {
      any = true; // rơi thẳng tới cạn trước
    }
    if (diagonal && diagonalPass()) any = true;
    if (spawnPass()) any = true;
  }

  final total = existing + spawnCount;
  final finalR = List.filled(total, -1), finalC = List.filled(total, -1);
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final v = g[r][c];
      if (v >= 0) {
        finalR[v] = r;
        finalC[v] = c;
      }
    }
  }
  final moves = <SettleMove>[];
  for (int i = 0; i < existing; i++) {
    if (finalR[i] != origR[i] || finalC[i] != origC[i]) {
      moves.add(SettleMove(origR[i], origC[i], finalR[i], finalC[i]));
    }
  }
  // depth = thứ hạng spawn trong cùng cột (đỉnh xa nhất → depth lớn) cho stagger.
  final perCol = <int, int>{};
  final spawns = <SettleSpawn>[];
  for (int i = existing; i < total; i++) {
    final c = finalC[i];
    final d = perCol[c] ?? 0;
    perCol[c] = d + 1;
    spawns.add(SettleSpawn(finalR[i], c, d));
  }
  return BoardSettle(moves, spawns);
}

/// Trọng lực LỖ-CẮT-CỘT (Phase 0): mỗi cột, wall chia thành các đoạn play liền
/// mạch; gem trong đoạn dồn xuống đáy đoạn, ô trống còn lại của đoạn → spawn.
///
/// - [kindAt]: loại ô (r,c).
/// - [occupied]: ô play (r,c) hiện CÓ gem không (wall/ô trống → false).
/// - [refillCapped]: có refill cho đoạn bị WALL chặn đỉnh không. true = mọi đoạn
///   đều refill (gem xuất hiện ở đỉnh đoạn); false = chỉ đoạn hở-đỉnh (top chạm
///   hàng 0) mới refill (đoạn bị chặn để Phase 1 trượt-chéo lấp). MVP Phase 0:
///   true (đơn giản, luôn khả thi).
SettleResult settleColumnsDown(
  int rows,
  int cols,
  CellKind Function(int r, int c) kindAt,
  bool Function(int r, int c) occupied, {
  bool refillCapped = true,
}) {
  final moves = <SettleMove>[];
  final spawns = <SettleSpawn>[];

  for (int c = 0; c < cols; c++) {
    int r = rows - 1;
    while (r >= 0) {
      if (kindAt(r, c) == CellKind.wall) {
        r--;
        continue;
      }
      // Đoạn play liền mạch [top..r] (đi lên tới khi gặp wall/biên).
      int top = r;
      while (top - 1 >= 0 && kindAt(top - 1, c) != CellKind.wall) {
        top--;
      }
      // Dồn gem trong đoạn xuống đáy: quét từ đáy đoạn lên, "ghi" mỗi gem vào
      // vị trí thấp nhất chưa dùng.
      int write = r;
      for (int rr = r; rr >= top; rr--) {
        if (occupied(rr, c)) {
          if (rr != write) moves.add(SettleMove(rr, c, write, c));
          write--;
        }
      }
      // Ô top..write còn trống → spawn (nếu được phép refill đoạn này).
      final openTop = top == 0; // đoạn hở đỉnh (chạm hàng trên cùng)
      if (refillCapped || openTop) {
        final holes = write - top + 1;
        for (int i = 0; i < holes; i++) {
          // depth: ô gần đỉnh đoạn (top) là sâu nhất so với nguồn (rơi xa nhất).
          spawns.add(SettleSpawn(write - i, c, i));
        }
      }
      r = top - 1;
    }
  }
  return SettleResult(moves, spawns);
}
