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
  }) : assert(
         (coinPrice == null) != (unlockAchievementId == null) ||
             (coinPrice == null && unlockAchievementId == null),
       );

  final String id;
  final String nameKey;
  final Color color;
  final int? coinPrice;
  final String? unlockAchievementId;

  bool get isFree => coinPrice == null && unlockAchievementId == null;
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
];

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
