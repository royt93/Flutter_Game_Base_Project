/// F18 — "Bàn hôm nay": mỗi ngày chọn tất định một bàn tự vẽ (hoặc preset) làm
/// thử thách có thưởng.
///
/// Thuần: không đọc `StorageService`/GetX/đồng hồ. Caller truyền vào epoch-day
/// và danh sách mã — đúng khuôn `daily_challenge.dart` / `lucky_color.dart`.
library;

import 'dart:math';

import '../data/levels.dart' show scoreForGroup;
import 'pop_detector.dart';
import 'puzzle_code.dart';

/// Điểm **tối đa lý thuyết** của [grid]: giả định mọi ô cùng màu gộp được vào
/// một nhóm duy nhất.
///
/// Đây là **cận trên**, cố ý. Nó không nói bàn có giải được không — nó chỉ nói
/// chắc chắn bàn **không** giải được khi cận trên đã dưới target. Nhờ vậy bộ
/// lọc không bao giờ loại nhầm một bàn giải được.
///
/// Cố ý KHÔNG viết solver: task ghi rõ nếu phần kiểm khả thi biến thành solver
/// thì bỏ. Cận trên rẻ, đúng một chiều, và đủ để chặn bàn vô vọng.
int puzzleMaxPossibleScore(List<List<int?>> grid) {
  final counts = <int, int>{};
  for (final row in grid) {
    for (final v in row) {
      if (v != null && v >= 0) counts[v] = (counts[v] ?? 0) + 1;
    }
  }
  var total = 0;
  for (final n in counts.values) {
    total += scoreForGroup(n);
  }
  return total;
}

/// Target điểm của bàn tự vẽ — cùng công thức `startPuzzleLevel` đang dùng, để
/// "Bàn hôm nay" và Puzzle Lab thường không lệch luật.
int puzzleTargetScore(int rows, int cols) => rows * cols * 6;

/// Bàn có đáng đưa vào vòng chọn không.
///
/// Ba điều kiện, rẻ dần từ trái sang: có gem thật, có **ít nhất một nước đi**
/// ngay từ đầu (bàn xen kẽ hoàn toàn như preset `checker` chết ở đây), và cận
/// trên điểm không dưới target.
bool isPuzzleBoardPlayable(List<List<int?>> grid) {
  if (grid.isEmpty || grid.first.isEmpty) return false;
  if (!hasAnyGem(grid)) return false;

  final filled = fillEmptyCells(grid);
  if (!hasAnyMovableGroup(filled)) return false;

  final target = puzzleTargetScore(grid.length, grid.first.length);
  return puzzleMaxPossibleScore(grid) >= target;
}

/// Lọc [codes] xuống những mã giải mã được **và** chơi được, giữ nguyên thứ tự.
///
/// Thứ tự quan trọng: nó là đầu vào của [pickPuzzleDailyIndex], nên đổi thứ tự
/// là đổi bàn của mọi ngày.
List<List<List<int?>>> playablePuzzleBoards(List<String> codes) {
  final out = <List<List<int?>>>[];
  for (final code in codes) {
    final grid = decodePuzzleGrid(code);
    if (grid == null) continue;
    if (!isPuzzleBoardPlayable(grid)) continue;
    out.add(grid);
  }
  return out;
}

/// Chỉ số bàn của ngày [epochDay] trong danh sách [count] bàn đã lọc.
///
/// `Random(seed)` gieo bằng epoch-day — không `DateTime.now()` trong generator,
/// nên cùng một ngày mở app bao nhiêu lần cũng ra cùng bàn, và test không cần
/// đụng đồng hồ.
///
/// Trả `-1` khi không còn bàn nào — caller phải xử lý, đây là trạng thái hợp lệ
/// (người chơi lưu toàn bàn hỏng và preset cũng rỗng ở bản dựng lỗi).
int pickPuzzleDailyIndex(int epochDay, int count) {
  if (count <= 0) return -1;
  // Gieo thẳng epoch-day, KHÔNG nhân thêm hằng số trộn.
  //
  // Bản đầu có `epochDay * 7919` kèm lời giải thích "Random(n) với n liền kề
  // cho chuỗi đầu giống nhau". Đo lại thì lời giải thích đó SAI với `Random`
  // của Dart: gieo trần đã cho đủ 11/11 và 12/12 chỉ số khác nhau trong 60
  // ngày, chuỗi lặp liên tiếp dài nhất là 3 — y hệt bản có nhân. Bỏ đi vì nó
  // không làm gì ngoài việc trông có vẻ cẩn thận.
  return Random(epochDay).nextInt(count);
}

/// Bàn của ngày [epochDay] chọn từ [codes] (bàn tự vẽ trước, preset sau).
///
/// `null` khi không mã nào chơi được.
List<List<int?>>? pickPuzzleDailyBoard(int epochDay, List<String> codes) {
  final boards = playablePuzzleBoards(codes);
  final i = pickPuzzleDailyIndex(epochDay, boards.length);
  return i < 0 ? null : boards[i];
}
