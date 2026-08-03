import 'package:flutter/material.dart';

import '../core/neon_theme.dart';

enum BoardFrameUnlockKind {
  always,
  prestigeTier,
  achievement,
  treasureMap,
  seasonal,
}

class BoardFrame {
  const BoardFrame({
    required this.id,
    required this.nameKey,
    required this.color,
    required this.unlockKind,
    this.requiredPrestigeTier = 0,
    this.requiredAchievementId = '',
    this.seasonStartMonth,
    this.seasonStartDay,
    this.seasonEndMonth,
    this.seasonEndDay,
  });

  final String id;
  final String nameKey;
  final Color color;
  final BoardFrameUnlockKind unlockKind;
  final int requiredPrestigeTier;
  final String requiredAchievementId;

  /// Chỉ có ý nghĩa khi [unlockKind] == [BoardFrameUnlockKind.seasonal].
  final int? seasonStartMonth;
  final int? seasonStartDay;
  final int? seasonEndMonth;
  final int? seasonEndDay;
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
  // I73 — Seasonal Board Skins: chỉ chọn được trong khung ngày-tháng (giờ
  // máy), người chơi tự equip thủ công, không tự động ép chuyển khi hết mùa.
  BoardFrame(
    id: 'seasonal_tet',
    nameKey: 'board_frame_seasonal_tet',
    color: NeonTheme.red,
    unlockKind: BoardFrameUnlockKind.seasonal,
    seasonStartMonth: 1,
    seasonStartDay: 20,
    seasonEndMonth: 2,
    seasonEndDay: 10,
  ),
  BoardFrame(
    id: 'seasonal_halloween',
    nameKey: 'board_frame_seasonal_halloween',
    color: NeonTheme.orange,
    unlockKind: BoardFrameUnlockKind.seasonal,
    seasonStartMonth: 10,
    seasonStartDay: 25,
    seasonEndMonth: 11,
    seasonEndDay: 2,
  ),
  BoardFrame(
    id: 'seasonal_christmas',
    nameKey: 'board_frame_seasonal_christmas',
    color: NeonTheme.lime,
    unlockKind: BoardFrameUnlockKind.seasonal,
    seasonStartMonth: 12,
    seasonStartDay: 15,
    seasonEndMonth: 1,
    seasonEndDay: 2,
  ),
];

/// Khoảng ngày-tháng (giờ máy), xử lý wrap-around qua năm (vd Tết 20/1-10/2,
/// Giáng sinh 15/12-2/1). Cosmetic thuần hiển thị theo lịch, không có gì để
/// exploit qua chỉnh giờ máy nên dùng [DateTime.now()] trực tiếp thay vì cơ
/// chế `_todayEpochDay()` chống-cheat (dành cho streak/quota có giá trị).
bool isWithinSeasonalWindow(
  DateTime now,
  int startMonth,
  int startDay,
  int endMonth,
  int endDay,
) {
  final nowKey = now.month * 100 + now.day;
  final startKey = startMonth * 100 + startDay;
  final endKey = endMonth * 100 + endDay;
  if (startKey <= endKey) {
    return nowKey >= startKey && nowKey <= endKey;
  }
  return nowKey >= startKey || nowKey <= endKey;
}

bool isBoardFrameUnlocked(
  BoardFrame frame,
  int prestigeTier,
  Set<String> unlockedAchievementIds, {
  bool treasureMapCompleted = false,
  DateTime? now,
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
    case BoardFrameUnlockKind.seasonal:
      return isWithinSeasonalWindow(
        now ?? DateTime.now(),
        frame.seasonStartMonth!,
        frame.seasonStartDay!,
        frame.seasonEndMonth!,
        frame.seasonEndDay!,
      );
  }
}
