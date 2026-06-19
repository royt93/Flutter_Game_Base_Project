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
