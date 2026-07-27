import 'dart:math';

/// I44: quyết định có nên gắn tag Time Freeze lên 1 ô sau lần collapse này
/// không. Pure — không đọc `GameMode`/`GameController` trực tiếp (tránh phụ
/// thuộc GetX/Flutter trong `lib/logic/`), nhận trạng thái cần thiết qua
/// tham số. Chỉ tag khi đang Time Attack, chưa có ô nào đang tag (tối đa 1 ô
/// trên bàn cùng lúc), và trúng xác suất [chance].
bool shouldTagTimeFreezeTile({
  required bool isTimeAttack,
  required bool alreadyTagged,
  required Random rng,
  double chance = 0.1,
}) {
  if (!isTimeAttack || alreadyTagged) return false;
  return rng.nextDouble() < chance;
}
