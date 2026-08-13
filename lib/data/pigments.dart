import 'package:flutter/material.dart';

import '../core/neon_theme.dart';
import '../core/storage_service.dart';

/// I62: một màu pha chế có thể mua bằng xu, mở bằng achievement, hoặc miễn phí.
class Pigment {
  const Pigment({
    required this.id,
    required this.nameKey,
    required this.color,
    this.coinPrice,
    this.unlockAchievementId,
    this.fusionOnly = false,
  }) : assert(
         // F19: thêm dạng mở khoá thứ tư (fusion). Pigment fusion KHÔNG được
         // vừa mua bằng xu vừa pha ra — nếu mua được thì công thức chỉ là
         // đường vòng dài hơn.
         !fusionOnly || (coinPrice == null && unlockAchievementId == null),
       ),
       assert(
         (coinPrice == null) != (unlockAchievementId == null) ||
             (coinPrice == null && unlockAchievementId == null),
       );

  final String id;
  final String nameKey;
  final Color color;
  final int? coinPrice;
  final String? unlockAchievementId;

  /// F19: chỉ lấy được bằng cách pha (xem [kPigmentRecipes]).
  final bool fusionOnly;

  bool get isFree =>
      coinPrice == null && unlockAchievementId == null && !fusionOnly;
}

const kPigments = <Pigment>[
  Pigment(id: 'aqua', nameKey: 'pigment_aqua', color: NeonTheme.cyan),
  Pigment(
    id: 'coral',
    nameKey: 'pigment_coral',
    color: Color(0xFFFF6F61),
    coinPrice: 180,
  ),
  Pigment(
    id: 'mint',
    nameKey: 'pigment_mint',
    color: Color(0xFF42E6B1),
    coinPrice: 240,
  ),
  Pigment(
    id: 'midnight',
    nameKey: 'pigment_midnight',
    color: Color(0xFF4054B2),
    unlockAchievementId: 'combo_25',
  ),
  Pigment(
    id: 'sunset',
    nameKey: 'pigment_sunset',
    color: Color(0xFFFF7A45),
    unlockAchievementId: 'clear_400',
  ),
  // F19 — pigment hiếm, CHỈ pha ra được.
  Pigment(
    id: 'seafoam',
    nameKey: 'pigment_seafoam',
    color: Color(0xFF7FE7C4),
    fusionOnly: true,
  ),
  Pigment(
    id: 'orchid',
    nameKey: 'pigment_orchid',
    color: Color(0xFFC77DFF),
    fusionOnly: true,
  ),
  Pigment(
    id: 'ember',
    nameKey: 'pigment_ember',
    color: Color(0xFFFF9E3D),
    fusionOnly: true,
  ),
  Pigment(
    id: 'twilight',
    nameKey: 'pigment_twilight',
    color: Color(0xFF6C63FF),
    fusionOnly: true,
  ),
  Pigment(
    id: 'moss',
    nameKey: 'pigment_moss',
    color: Color(0xFF6FBF73),
    fusionOnly: true,
  ),
  Pigment(
    id: 'rose_quartz',
    nameKey: 'pigment_rose_quartz',
    color: Color(0xFFFFA8C5),
    fusionOnly: true,
  ),
];

/// F19: giá pha một công thức, tính bằng craft point.
const int kFusionCraftCost = 8;

/// Bảng công thức: cặp pigment (**không** phân biệt thứ tự) → pigment hiếm.
///
/// Dữ liệu, không phải code nhánh. Khoá chuẩn hoá bằng [recipeKey] để
/// `aqua+coral` và `coral+aqua` là một.
const Map<String, String> kPigmentRecipes = {
  'aqua|coral': 'seafoam',
  'aqua|mint': 'moss',
  'coral|mint': 'ember',
  'aqua|midnight': 'twilight',
  'coral|sunset': 'rose_quartz',
  'midnight|sunset': 'orchid',
};

/// Khoá công thức chuẩn hoá — sắp xếp để đổi chỗ hai nguyên liệu vẫn ra một.
String recipeKey(String a, String b) {
  final pair = [a, b]..sort();
  return '${pair[0]}|${pair[1]}';
}

/// Kết quả pha [a] với [b], `null` nếu không có công thức.
String? fusionResultFor(String a, String b) {
  if (a == b) return null; // pha một màu với chính nó không có nghĩa
  return kPigmentRecipes[recipeKey(a, b)];
}

/// Map persisted as JSON-like `slot:id,slot:id`; malformed entries are ignored.
Map<int, String> decodeGemColorOverrides(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  final result = <int, String>{};
  for (final entry in raw.split(',')) {
    final parts = entry.split(':');
    if (parts.length != 2) continue;
    final slot = int.tryParse(parts.first);
    if (slot != null && slot >= 0) result[slot] = parts.last;
  }
  return result;
}

String encodeGemColorOverrides(Map<int, String> overrides) {
  final entries = overrides.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries.map((e) => '${e.key}:${e.value}').join(',');
}

/// Display-only color resolution. Matching continues to use the integer slot.
Color resolvedGemColor(int colorIndex) {
  final fallback = NeonTheme.gemColors[colorIndex % NeonTheme.gemColors.length];
  final store = StorageService.maybe;
  if (store == null) return fallback;
  final id = decodeGemColorOverrides(
    store.getString(StorageKeys.gemColorOverrides),
  )[colorIndex];
  if (id == null) return fallback;
  return kPigments.where((p) => p.id == id).firstOrNull?.color ?? fallback;
}
