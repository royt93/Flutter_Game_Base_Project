---
id: w21-6-offline-leaderboard
title: Offline Leaderboard — Bot score tất định cho Campaign + Daily
wave: 21
phase: 6
status: todo
owner: claude
---

# Phase 6 — Offline Leaderboard (Bot tất định)

## Thiết kế

Leaderboard hoàn toàn offline: **bot score tất định** (seed = `level + epochWeek`) →
mỗi tuần top 10 thay đổi, không cần backend, không cần tài khoản.

### Campaign Leaderboard

- Top 10 "người chơi" (tên bot ngẫu nhiên từ danh sách 50 tên neon-theme).
- Bot score = `_botScore(level, rank, epochWeek)` — hàm pure (seed tất định theo tuần).
- Người chơi real hiện trong danh sách với tên "Bạn" (score từ `highScore(level)`).
- Hiển thị: ô tên + điểm + hạng. Hạng người chơi = bao nhiêu bot mình vượt được.
- Refresh mỗi tuần (seed đổi → top 10 mới mỗi tuần, tạo cảm giác "đua").

### Daily Leaderboard

- Mỗi ngày có top 10 bot score cho Daily Challenge (seed = `epochDay`).
- Người chơi real sau khi hoàn thành daily mới thấy ranking mình.
- Score hiển thị ngay khi finish daily (không cần submit).

### UI

- `LeaderboardScreen`: tab "Chiến dịch" | "Hằng ngày".
- Campaign tab: chọn level (spinner) → hiện top 10.
- Daily tab: hiện top 10 ngày hôm nay.
- Nút "Leaderboard" trong Home (row icon nhỏ, thay thế 1 icon ít dùng) hoặc trong
  Level Select (icon cạnh mỗi tile level).

## Triển khai

```dart
// lib/core/leaderboard_engine.dart (pure Dart)
int botScore(int level, int rank, int epochWeek) {
  final seed = level * 1000 + rank * 7 + epochWeek;
  final rng = Random(seed);
  final base = _targetScore(level); // từ kLevels
  return (base * (0.7 + rng.nextDouble() * 0.6)).round();
}

const kBotNames = ['Nova', 'Lyra', 'Pixel', 'Zen', 'Flux', ...]; // 50 tên
String botName(int rank, int epochWeek) {
  final seed = rank * 31 + epochWeek;
  return kBotNames[Random(seed).nextInt(kBotNames.length)];
}
```

- `LeaderboardController` (GetX, permanent: false — chỉ load khi màn mở).
- Không cần persist gì thêm — score bot compute on-the-fly.

## Test
- `botScore` deterministic: cùng input → cùng output.
- `botScore` range hợp lý: ±30% quanh target score của level.
- `botName` deterministic.
- Widget test: `LeaderboardScreen` mount với tab Campaign + Daily.
- Anti-exploit: score bot không ảnh hưởng `highScore` thật của người chơi.

## Lưu ý
- Dùng `epochWeek = epochDay ~/ 7` (consistent với `_effectiveDay` anti-cheat).
- Bot score KHÔNG persist, KHÔNG ghi disk — pure compute.
- Liên quan: [[balance-economy-principles]], [[daily-challenge-subsystem]].
