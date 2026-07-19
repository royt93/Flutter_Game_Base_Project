import 'dart:convert';

import 'boss_tile.dart';
import 'gift_tile.dart';

/// I42: trần màu thực tế toàn game (`lib/data/levels.dart`
/// `colorCount = (colorBase + i%3 - 1).clamp(4, 7)` → tối đa 7, index 0..6).
/// Task doc gốc ghi nhầm "0..11" — dùng đúng giá trị thật của game.
const int kPuzzleMaxColorCount = 7;

/// [v] có phải giá trị cell hợp lệ trên bàn tự vẽ không: `null` (trống),
/// `0..kPuzzleMaxColorCount-1` (màu), [giftTileValue], hoặc obstacle âm khác
/// gift/boss. Boss tile (`isBossTileId`) không hỗ trợ trong Puzzle Lab.
bool isValidPuzzleCellValue(int? v) {
  if (v == null) return true;
  if (v >= 0) return v < kPuzzleMaxColorCount;
  if (v == giftTileValue) return true;
  if (isBossTileId(v)) return false;
  return true;
}

/// Có ít nhất 1 gem màu (`>= 0`) trên bàn không — bàn chỉ toàn obstacle/gift/
/// trống thì không chơi được (không có gì để pop lúc bắt đầu).
bool hasAnyGem(List<List<int?>> grid) =>
    grid.expand((row) => row).any((v) => v != null && v >= 0);

/// Lấp mọi ô trống (`null`) thành màu 0 trước khi đưa vào `PopStarGame`
/// (giữ nguyên `presetGrid` kiểu `List<List<int>>` không-null).
List<List<int>> fillEmptyCells(List<List<int?>> grid) =>
    grid.map((row) => row.map((v) => v ?? 0).toList()).toList();

/// Xoay vòng giá trị 1 cell khi user tap trong editor:
/// `null -> 0 -> 1 -> ... -> (colorCount-1) -> -1 (obstacle) -> gift -> null`.
int? cyclePuzzleCellValue(int? current, int colorCount) {
  if (current == null) return 0;
  if (current >= 0) {
    return current + 1 < colorCount ? current + 1 : -1;
  }
  if (current == -1) return giftTileValue;
  return null;
}

/// Mã hoá bàn tự vẽ: `rows|cols|v1,v2,...;v1,v2,...` (ô trống = chuỗi rỗng
/// giữa 2 dấu phẩy), rồi base64url — mirror `encodeReplay` (`replay.dart`).
String encodePuzzleGrid(List<List<int?>> grid) {
  final rows = grid.length;
  final cols = rows == 0 ? 0 : grid[0].length;
  final rowsRaw = grid
      .map((row) => row.map((v) => v?.toString() ?? '').join(','))
      .join(';');
  final raw = '$rows|$cols|$rowsRaw';
  return base64Url.encode(utf8.encode(raw));
}

/// Giải mã ngược [encodePuzzleGrid]. Trả `null` nếu: base64 hỏng, thiếu 3
/// phần `|`, số hàng/cột không khớp khai báo, hoặc có giá trị cell không hợp
/// lệ (xem [isValidPuzzleCellValue]). KHÔNG tự chặn bàn rỗng toàn gem — đó là
/// việc của caller qua [hasAnyGem] trước khi cho chơi.
List<List<int?>>? decodePuzzleGrid(String code) {
  try {
    final raw = utf8.decode(base64Url.decode(code.trim()));
    final parts = raw.split('|');
    if (parts.length != 3) return null;
    final rows = int.tryParse(parts[0]);
    final cols = int.tryParse(parts[1]);
    if (rows == null || cols == null || rows < 0 || cols < 0) return null;

    final rowsRaw = parts[2].isEmpty && rows == 0
        ? const <String>[]
        : parts[2].split(';');
    if (rowsRaw.length != rows) return null;

    final grid = <List<int?>>[];
    for (final rowRaw in rowsRaw) {
      final cellsRaw = cols == 0 && rowRaw.isEmpty
          ? const <String>[]
          : rowRaw.split(',');
      if (cellsRaw.length != cols) return null;
      final row = <int?>[];
      for (final cellRaw in cellsRaw) {
        if (cellRaw.isEmpty) {
          row.add(null);
          continue;
        }
        final v = int.tryParse(cellRaw);
        if (v == null || !isValidPuzzleCellValue(v)) return null;
        row.add(v);
      }
      grid.add(row);
    }
    return grid;
  } catch (_) {
    return null;
  }
}
