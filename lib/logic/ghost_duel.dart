/// F16 Ghost Duel — mô phỏng lại lượt chơi của đối thủ để biết điểm của họ
/// **sau mỗi nước đi**.
///
/// Mã duel chỉ mang điểm CUỐI. Muốn HUD hiện "ghost đang dẫn/đang bám" theo
/// từng nước thì phải biết điểm ghost tại nước thứ N — nội suy tuyến tính từ
/// điểm cuối là nói dối, nên mô phỏng lại thật.
///
/// Rẻ vì dùng lại nguyên máy logic thuần đã có: `findConnectedGroup`,
/// `applyGravityAndCollapse`, `scoreForGroup`. Không đụng Flame, không đụng
/// GetX — chạy được trong test không cần harness.
///
/// **Giới hạn có chủ ý:** mô phỏng KHÔNG tính power tile, booster, combo
/// multiplier hay ô đặc biệt. Nghĩa là điểm mô phỏng là **cận dưới** của điểm
/// thật, và tổng cuối cùng có thể lệch so với `DuelData.score`. Vì vậy phần so
/// thắng-thua luôn dùng `DuelData.score` (con số thật người kia đạt được), còn
/// đường điểm theo nước đi chỉ để tạo cảm giác đua. Xem [ghostScoreTimeline].
library;

import '../data/levels.dart' show scoreForGroup;
import 'pop_collapse.dart';
import 'pop_detector.dart';

/// Điểm ghost tích luỹ **sau mỗi nước đi** trong [taps], chơi trên [grid].
///
/// Phần tử `i` là tổng điểm sau khi ghost thực hiện `taps[0..i]`. Nước đi
/// không hợp lệ (tap vào ô trống hoặc nhóm < 2) đóng góp 0 điểm nhưng vẫn
/// chiếm một mốc — giữ đúng chỉ số với danh sách tap gốc.
///
/// [grid] bị **sao chép**, không sửa tại chỗ: caller thường truyền thẳng bàn
/// đang chơi của người dùng.
List<int> ghostScoreTimeline(List<List<int?>> grid, List<(int, int)> taps) {
  var board = grid.map((row) => List<int?>.from(row)).toList();
  var total = 0;
  final out = <int>[];

  for (final (r, c) in taps) {
    if (r >= 0 && r < board.length && c >= 0 && c < (board.first.length)) {
      final group = findConnectedGroup(board, r, c);
      if (group.length >= 2) {
        total += scoreForGroup(group.length);
        for (final cell in group) {
          board[cell.x][cell.y] = null;
        }
        board = applyGravityAndCollapse(board);
      }
    }
    out.add(total);
  }
  return out;
}

/// Điểm ghost tại nước đi thứ [moveIndex] (0-based, tính cả nước đó).
///
/// Trước nước đầu tiên → 0. Sau khi ghost hết nước → giữ nguyên điểm cuối:
/// người chơi chậm hơn vẫn thấy vạch đích của ghost thay vì con số biến mất.
int ghostScoreAtMove(List<int> timeline, int moveIndex) {
  if (timeline.isEmpty || moveIndex < 0) return 0;
  if (moveIndex >= timeline.length) return timeline.last;
  return timeline[moveIndex];
}

/// Kết quả một trận Ghost Duel.
///
/// Tên có tiền tố `Ghost` vì `DuelOutcome` đã thuộc về Pass-and-Play ([[I59]])
/// — trùng tên làm mọi file import cả hai không dựng được. Cùng lý do với
/// tiền tố `ghost_duel_` của các key i18n.
enum GhostDuelOutcome { win, lose, draw }

/// So điểm người chơi với điểm **thật** của ghost (`DuelData.score`), không
/// phải điểm mô phỏng — xem ghi chú giới hạn ở đầu file.
GhostDuelOutcome ghostDuelOutcome({required int playerScore, required int ghostScore}) {
  if (playerScore > ghostScore) return GhostDuelOutcome.win;
  if (playerScore < ghostScore) return GhostDuelOutcome.lose;
  return GhostDuelOutcome.draw;
}
