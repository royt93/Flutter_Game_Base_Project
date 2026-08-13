/// F21 Mirror Draft — hai người chơi trên một bàn đối xứng gương, mỗi cú tap
/// cũng nổ nhóm ở vị trí gương của nửa bên kia.
///
/// Trục gương là **dọc**, cùng trục `generateMirrorBoard` (I47) đã dùng: cột
/// `c` soi sang cột `cols - 1 - c`.
///
/// ## Luật gây tranh cãi nhất, chốt tại đây
///
/// Nhóm gương chỉ nổ **nếu nó cũng hợp lệ ở nửa bên kia** (>= 2 ô cùng màu
/// liền kề). Không hợp lệ thì chỉ nổ bên người tap.
///
/// Nghĩa là bàn **phân kỳ dần** — đó là đặc điểm, không phải lỗi: sau vài nước
/// hai nửa khác nhau, và chính sự khác nhau đó tạo ra cuộc đàm phán giữa hai
/// người ("đừng nổ chỗ đó"). Nếu ép đối xứng tuyệt đối thì nửa bên kia phải nổ
/// những ô không cùng màu — vừa vô lý vừa xoá luôn phần thú vị.
///
/// Thuần: không Flame, không GetX, không đọc storage.
library;

import 'dart:math';

import 'pop_detector.dart';

/// Cột đối xứng của [col] trên bàn rộng [cols].
int mirrorColumn(int col, int cols) => cols - 1 - col;

/// Ô nào thuộc nửa của người chơi 1 (nửa TRÁI).
///
/// Cột giữa của bàn lẻ thuộc về **cả hai** — nó tự soi vào chính nó, nên tap ở
/// đó chỉ nổ đúng một lần (xem [mirrorDraftCells]).
bool isPlayerOneHalf(int col, int cols) => col < cols ~/ 2;

/// Ô giữa của bàn có số cột lẻ — tự đối xứng với chính nó.
bool isCenterColumn(int col, int cols) => cols.isOdd && col == cols ~/ 2;

/// Kết quả một cú tap Mirror Draft.
class MirrorDraftResult {
  const MirrorDraftResult({
    required this.tappedCells,
    required this.mirroredCells,
  });

  /// Nhóm ở phía người chơi vừa tap. Rỗng = nước đi không hợp lệ.
  final Set<Point<int>> tappedCells;

  /// Nhóm ở nửa gương. Rỗng khi nhóm gương không hợp lệ **hoặc** khi tap vào
  /// cột giữa (không có nửa nào khác để soi sang).
  final Set<Point<int>> mirroredCells;

  bool get isValid => tappedCells.isNotEmpty;

  /// Toàn bộ ô cần xoá. Dùng `Set` nên hai nhóm chồng nhau không xoá hai lần.
  Set<Point<int>> get allCells => {...tappedCells, ...mirroredCells};

  /// Nước đi có nổ được cả hai bên không — UI cần biết để báo cho người chơi
  /// vì sao nửa kia **không** nổ, nếu không họ sẽ tưởng là lỗi.
  bool get mirroredToo => mirroredCells.isNotEmpty;
}

/// Ô cần nổ khi tap `(row, col)` trên [grid].
///
/// Trả về nhóm rỗng nếu chính nước đi đó không hợp lệ — caller kiểm
/// [MirrorDraftResult.isValid] trước khi áp dụng.
MirrorDraftResult mirrorDraftCells(List<List<int?>> grid, int row, int col) {
  const empty = MirrorDraftResult(tappedCells: {}, mirroredCells: {});
  if (grid.isEmpty || grid.first.isEmpty) return empty;
  final rows = grid.length;
  final cols = grid.first.length;
  if (row < 0 || row >= rows || col < 0 || col >= cols) return empty;

  final tapped = findConnectedGroup(grid, row, col);
  if (tapped.length < 2) return empty;

  // Cột giữa tự soi vào chính nó: không có nhóm gương riêng để nổ.
  if (isCenterColumn(col, cols)) {
    return MirrorDraftResult(tappedCells: tapped, mirroredCells: const {});
  }

  final mCol = mirrorColumn(col, cols);
  final mirrored = findConnectedGroup(grid, row, mCol);

  // Nhóm gương phải hợp lệ **và** không được trùng với nhóm vừa tap (bàn hẹp
  // hoặc nhóm chạy ngang qua trục thì hai bên là MỘT nhóm — nổ một lần là đủ,
  // và báo `mirroredToo = false` để UI không khoe hiệu ứng gương giả).
  if (mirrored.length < 2 || mirrored.intersection(tapped).isNotEmpty) {
    return MirrorDraftResult(tappedCells: tapped, mirroredCells: const {});
  }

  return MirrorDraftResult(tappedCells: tapped, mirroredCells: mirrored);
}
