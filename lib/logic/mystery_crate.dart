import 'package:flutter/material.dart';

import '../data/board_frames.dart';
import '../data/burst_styles.dart';
import '../data/combo_text_styles.dart';
import '../data/mascot_skins.dart';

/// 4 hệ thống cosmetic khác nhau trong game.
enum CosmeticKind { mascotSkin, boardFrame, burstStyle, comboTextStyle }

/// Class bọc mỏng (thin wrapper) đọc/hiển thị thông tin tổng hợp từ 4 hệ thống cosmetic.
/// KHÔNG hợp nhất 4 pattern unlock gốc.
class CosmeticEntry {
  const CosmeticEntry({
    required this.id,
    required this.kind,
    required this.nameKey,
    required this.color,
    required this.originalItem,
  });

  final String id;
  final CosmeticKind kind;
  final String nameKey;
  final Color color;
  final Object originalItem;
}

/// Dựng danh sách tất cả CosmeticEntry từ 4 hệ thống cosmetic.
List<CosmeticEntry> getAllCosmeticEntries() {
  final entries = <CosmeticEntry>[];

  for (final skin in kMascotSkins) {
    if (skin.isFree) continue; // Bỏ qua item free mặc định
    entries.add(
      CosmeticEntry(
        id: skin.id,
        kind: CosmeticKind.mascotSkin,
        nameKey: skin.nameKey,
        color: skin.palette.glow,
        originalItem: skin,
      ),
    );
  }

  for (final frame in kBoardFrames) {
    if (frame.unlockKind == BoardFrameUnlockKind.always) continue;
    entries.add(
      CosmeticEntry(
        id: frame.id,
        kind: CosmeticKind.boardFrame,
        nameKey: frame.nameKey,
        color: frame.color,
        originalItem: frame,
      ),
    );
  }

  for (final burst in kBurstStyles) {
    if (burst.unlockThreshold == 0) continue;
    entries.add(
      CosmeticEntry(
        id: burst.kind.name,
        kind: CosmeticKind.burstStyle,
        nameKey: burst.nameKey,
        color: const Color(0xFFFF6FC1),
        originalItem: burst,
      ),
    );
  }

  for (final combo in kComboTextStyles) {
    if (combo.unlockThreshold == 0) continue;
    entries.add(
      CosmeticEntry(
        id: combo.kind.name,
        kind: CosmeticKind.comboTextStyle,
        nameKey: combo.nameKey,
        color: const Color(0xFFFFD23F),
        originalItem: combo,
      ),
    );
  }

  return entries;
}

/// Roll ngẫu nhiên 1 [CosmeticEntry] từ [eligiblePool] bằng [rng].
/// Trả về null nếu pool rỗng.
CosmeticEntry? rollCrate({
  required List<CosmeticEntry> eligiblePool,
  required Object rng, // Accept Random or dynamic to allow standard Random or custom RNG
}) {
  if (eligiblePool.isEmpty) return null;
  // Use dynamic call for nextInt so both System Random and mock/seeded Random work seamlessly
  final nextInt = (rng as dynamic).nextInt as int Function(int max);
  final index = nextInt(eligiblePool.length);
  return eligiblePool[index];
}
