import 'package:flutter/material.dart';

import 'mascot_skins.dart';

/// I65: 1 loại pet — tái dùng `MascotPalette` (I30) làm bảng màu thay vì
/// định nghĩa struct màu riêng trùng lặp.
class PetType {
  const PetType({
    required this.id,
    required this.nameKey,
    required this.palette,
    required this.hatchCost,
  });

  final String id;
  final String nameKey;
  final MascotPalette palette;
  final int hatchCost;
}

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
int idleRewardCoins({
  required int lastCollectMs,
  required int nowMs,
  required int petCount,
}) {
  if (petCount <= 0) return 0;
  final elapsedMs = nowMs - lastCollectMs;
  if (elapsedMs <= 0) return 0;
  final cappedMs = elapsedMs > idlePetRewardCapMs
      ? idlePetRewardCapMs
      : elapsedMs;
  final hours = cappedMs / (60 * 60 * 1000);
  return (hours * idlePetCoinsPerHour * petCount).floor();
}
