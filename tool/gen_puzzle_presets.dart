// Sinh mã preset cho F18. Chạy: dart run tool/gen_puzzle_presets.dart
// Dùng CHÍNH encoder của game nên mã sinh ra chắc chắn decode được.
import 'package:pop_star_blast/logic/puzzle_code.dart';

typedef Pattern = int Function(int r, int c);

const rows = 9;
const cols = 8;

final patterns = <String, Pattern>{
  'stripes_h': (r, c) => r ~/ 2 % 4,
  'stripes_v': (r, c) => c ~/ 2 % 4,
  'checker': (r, c) => (r + c) % 2 == 0 ? 0 : 1,
  'blocks': (r, c) => (r ~/ 3) * 2 + (c ~/ 3) % 2,
  'diamond': (r, c) {
    final d = ((r - rows ~/ 2).abs() + (c - cols ~/ 2).abs());
    return (d ~/ 2).clamp(0, 3);
  },
  'cross': (r, c) =>
      (r == rows ~/ 2 || c == cols ~/ 2) ? 0 : ((r + c) ~/ 3) % 3 + 1,
  'zigzag': (r, c) => ((c + r ~/ 2) ~/ 2) % 4,
  'corners': (r, c) =>
      (r < rows ~/ 2 ? 0 : 2) + (c < cols ~/ 2 ? 0 : 1),
  'rings': (r, c) {
    final d = (r - rows ~/ 2).abs() > (c - cols ~/ 2).abs()
        ? (r - rows ~/ 2).abs()
        : (c - cols ~/ 2).abs();
    return d % 4;
  },
  'columns_pair': (r, c) => (c ~/ 2) % 3,
  'wave': (r, c) => ((r + (c * c) ~/ 5) ~/ 2) % 4,
  'quads': (r, c) => ((r ~/ 2) + (c ~/ 2)) % 4,
};

void main() {
  patterns.forEach((name, fn) {
    final grid = <List<int?>>[
      for (var r = 0; r < rows; r++)
        [for (var c = 0; c < cols; c++) fn(r, c)],
    ];
    final code = encodePuzzleGrid(grid);
    // Tự kiểm ngay: decode lại phải ra đúng bàn cũ.
    final back = decodePuzzleGrid(code);
    final ok = back != null &&
        back.length == rows &&
        back.every((row) => row.length == cols);
    // ignore: avoid_print
    print("  PuzzlePreset(id: '$name', code: '$code'), // ok=$ok");
  });
}
