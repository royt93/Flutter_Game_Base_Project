import 'package:flutter/material.dart';

import 'mascot_skins.dart';

/// I82: hiệu ứng bị động nhẹ của pet đang trang bị.
///
/// Cố ý giữ ở mức "dễ chịu", không cái nào đổi được thắng-thua: pet kiếm bằng
/// thắng 3 sao campaign và Daily Challenge, tức là phần thưởng cho kỹ năng —
/// biến nó thành sức mạnh quyết định sẽ tạo cảm giác pay-to-win dù game không
/// có IAP.
enum PetPassive {
  /// +1 lượt undo miễn phí mỗi màn (chồng với perk `extra_undo`).
  extraUndo,

  /// +1 gợi ý mỗi ván.
  extraHint,

  /// +5% xu thưởng cuối màn (chồng với perk `coin_bonus`).
  coinBonus,
}

/// I65: 1 loại pet — tái dùng `MascotPalette` (I30) làm bảng màu thay vì
/// định nghĩa struct màu riêng trùng lặp.
class PetType {
  const PetType({
    required this.id,
    required this.nameKey,
    required this.palette,
    required this.hatchCost,
    required this.passive,
  });

  final String id;
  final String nameKey;
  final MascotPalette palette;
  final int hatchCost;

  /// I82: hiệu ứng khi pet này đang được trang bị.
  final PetPassive passive;
}

/// I82: trần cứng khi cộng dồn passive với perk F14 — không để hai hệ tăng
/// sức mạnh chồng nhau thành vô hạn.
const int kMaxFreeUndoPerLevel = 3;
const int kMaxHintsPerRun = 5;

/// 3 loại pet cho bản đầu, theo gợi ý giảm scope của task spec (SP8) nếu cần.
const kStarPetTypes = <PetType>[
  PetType(
    id: 'ember',
    nameKey: 'pet_ember_name',
    palette: MascotPalette(
      glow: Color(0xFFFF8A65),
      gradientStart: Color(0xFFFFCCBC),
      gradientEnd: Color(0xFFFF7043),
      outline: Color(0xFFBF360C),
    ),
    hatchCost: 80,
    passive: PetPassive.extraUndo,
  ),
  PetType(
    id: 'aqua',
    nameKey: 'pet_aqua_name',
    palette: MascotPalette(
      glow: Color(0xFF4FC3F7),
      gradientStart: Color(0xFFB3E5FC),
      gradientEnd: Color(0xFF29B6F6),
      outline: Color(0xFF01579B),
    ),
    hatchCost: 120,
    passive: PetPassive.extraHint,
  ),
  PetType(
    id: 'luna',
    nameKey: 'pet_luna_name',
    palette: MascotPalette(
      glow: Color(0xFFCE93D8),
      gradientStart: Color(0xFFE1BEE7),
      gradientEnd: Color(0xFFAB47BC),
      outline: Color(0xFF4A148C),
    ),
    hatchCost: 200,
    passive: PetPassive.coinBonus,
  ),
];

/// Trả về `null` nếu không có type nào khớp [id] — dùng để lọc dữ liệu cũ/hỏng
/// khi hydrate từ storage (xem `GameController._load`).
PetType? petTypeById(String id) {
  for (final t in kStarPetTypes) {
    if (t.id == id) return t;
  }
  return null;
}

/// I65: khác `activeMascotSkinId` (1 id duy nhất), mỗi lần ấp ra 1 instance
/// độc lập — người chơi có thể sở hữu nhiều pet cùng loại, mỗi con cộng dồn
/// vào [idleRewardCoins].
class PetInstance {
  const PetInstance({required this.typeId, required this.hatchedAtMs});

  final String typeId;
  final int hatchedAtMs;

  Map<String, Object> toJson() => {
    'typeId': typeId,
    'hatchedAtMs': hatchedAtMs,
  };

  static PetInstance? fromJson(Map<String, Object?> json) {
    final typeId = json['typeId'];
    final hatchedAtMs = json['hatchedAtMs'];
    if (typeId is! String || hatchedAtMs is! int) return null;
    return PetInstance(typeId: typeId, hatchedAtMs: hatchedAtMs);
  }
}

/// Trần thời gian tích luỹ idle — chặn cộng dồn vô hạn nếu rời app quá lâu.
const idlePetRewardCapMs = 10 * 60 * 60 * 1000; // 10h

/// Xu mỗi pet cộng dồn mỗi giờ rời app (trước khi áp trần).
const idlePetCoinsPerHour = 6;

/// I65: phần thưởng idle thu hoạch được khi mở lại Habitat. Pure — không đụng
/// storage/đồng hồ hệ thống, test độc lập. An toàn khi đồng hồ máy lùi
/// ([nowMs] <= [lastCollectMs]): trả 0 thay vì âm.
///
/// X22: tính **theo từng pet**, mốc bắt đầu là `max(lastCollectMs,
/// pet.hatchedAtMs)`. Bản cũ nhân `petCount` hiện tại với toàn bộ khoảng
/// `nowMs - lastCollectMs` và không hề đọc `hatchedAtMs` (dù đã lưu sẵn), nên
/// trả thưởng cho thời gian pet **chưa tồn tại**:
/// - tài khoản chưa từng collect có `lastCollectMs == 0` (mốc 1970) → ấp con
///   đầu tiên rồi hốt ngay là ăn trọn trần 10 giờ;
/// - đã có 1 pet chờ đủ 10 giờ → ấp thêm con thứ 2 ngay trước khi hốt thì con
///   mới cũng được tính đủ 10 giờ dù vừa sinh ra.
///
/// Trần [idlePetRewardCapMs] áp cho **mỗi pet**, giữ đúng ngữ nghĩa cũ ("mỗi
/// pet cộng dồn tối đa 10 giờ rời app").
int idleRewardCoins({
  required int lastCollectMs,
  required int nowMs,
  required List<PetInstance> pets,
}) {
  var totalMs = 0;
  for (final pet in pets) {
    final from = pet.hatchedAtMs > lastCollectMs
        ? pet.hatchedAtMs
        : lastCollectMs;
    final elapsedMs = nowMs - from;
    if (elapsedMs <= 0) continue;
    totalMs += elapsedMs > idlePetRewardCapMs ? idlePetRewardCapMs : elapsedMs;
  }
  if (totalMs <= 0) return 0;
  final hours = totalMs / (60 * 60 * 1000);
  return (hours * idlePetCoinsPerHour).floor();
}
