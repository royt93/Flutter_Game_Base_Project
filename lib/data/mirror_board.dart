import 'dart:math';

/// I47 Mirror Mode: sinh bàn đối xứng gương theo trục dọc — cột [c] và cột
/// `cols - 1 - c` luôn cùng màu ở mọi hàng. Cột giữa (nếu [cols] lẻ) tự đối
/// xứng với chính nó, không ràng buộc gì thêm. Chỉ áp dụng lúc sinh bàn —
/// không phải bất biến giữ xuyên suốt (bàn có thể mất đối xứng sau khi pop).
List<List<int>> generateMirrorBoard(
  int rows,
  int cols,
  int colorCount,
  Random rng,
) {
  final half = (cols + 1) ~/ 2;
  return List.generate(rows, (_) {
    final left = List.generate(half, (_) => rng.nextInt(colorCount));
    return List.generate(cols, (c) => left[c < half ? c : cols - 1 - c]);
  });
}
