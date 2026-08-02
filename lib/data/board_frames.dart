import 'package:flutter/material.dart';

import '../core/neon_theme.dart';

enum BoardFrameUnlockKind { always, prestigeTier, achievement, treasureMap }

class BoardFrame {
  const BoardFrame({
    required this.id,
    required this.nameKey,
    required this.color,
    required this.unlockKind,
    this.requiredPrestigeTier = 0,
    this.requiredAchievementId = '',
  });

  final String id;
  final String nameKey;
  final Color color;
  final BoardFrameUnlockKind unlockKind;
  final int requiredPrestigeTier;
  final String requiredAchievementId;
}

/// I51: `classic` luôn mở khoá (mặc định). 2 khung theo [GameController.prestigeTier]
/// (I27), 1 khung theo achievement tier cao nhất `clear_400` (I22, dọn sạch
/// bàn 400 lần) — dùng state đã có sẵn, không cần persist thêm "đã mở khoá".
const List<BoardFrame> kBoardFrames = [
  BoardFrame(
    id: 'classic',
    nameKey: 'board_frame_classic',
    color: NeonTheme.teal,
    unlockKind: BoardFrameUnlockKind.always,
  ),
  BoardFrame(
    id: 'neon_cyan',
    nameKey: 'board_frame_neon_cyan',
    color: NeonTheme.cyan,
    unlockKind: BoardFrameUnlockKind.prestigeTier,
    requiredPrestigeTier: 1,
  ),
  BoardFrame(
    id: 'aurora_gold',
    nameKey: 'board_frame_aurora_gold',
    color: NeonTheme.gold,
    unlockKind: BoardFrameUnlockKind.prestigeTier,
    requiredPrestigeTier: 3,
  ),
  BoardFrame(
    id: 'diamond',
    nameKey: 'board_frame_diamond',
    color: NeonTheme.indigo,
    unlockKind: BoardFrameUnlockKind.achievement,
    requiredAchievementId: 'clear_400',
  ),
  BoardFrame(
    id: 'treasure_relic',
    nameKey: 'board_frame_treasure_relic',
    color: Color(0xFF20BFA9),
    unlockKind: BoardFrameUnlockKind.treasureMap,
  ),
];

bool isBoardFrameUnlocked(
  BoardFrame frame,
  int prestigeTier,
  Set<String> unlockedAchievementIds, {
  bool treasureMapCompleted = false,
}) {
  switch (frame.unlockKind) {
    case BoardFrameUnlockKind.always:
      return true;
    case BoardFrameUnlockKind.prestigeTier:
      return prestigeTier >= frame.requiredPrestigeTier;
    case BoardFrameUnlockKind.achievement:
      return unlockedAchievementIds.contains(frame.requiredAchievementId);
    case BoardFrameUnlockKind.treasureMap:
      return treasureMapCompleted;
  }
}
