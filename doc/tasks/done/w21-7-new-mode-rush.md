---
id: w21-7-new-mode-rush
title: Mode mới "Rush" (Tốc chiến) — 2 phút, không giới hạn lượt
wave: 21
phase: 7
status: done
owner: claude
---

# Phase 7 — Mode mới: Rush (Tốc chiến)

## Concept

**Khác biệt hoàn toàn với mọi mode hiện có**:

| | Time Attack | Endless | Rush |
|---|---|---|---|
| Lượt | Có giới hạn | Vô hạn | **Vô hạn** |
| Thời gian | Có giới hạn | Không | **2 phút** |
| Match → thêm giờ | Không | Không | **Có** |
| Kết thúc | Hết lượt/giờ | Mãi mãi | Hết giờ |

**Cơ chế cốt lõi**:
- 2 phút ban đầu, không giới hạn lượt.
- Mỗi match → thêm thời gian: `+1s × độ dài match` (match-3=+1s, match-4=+2s, match-5=+3s).
- Combo cascade → thưởng giây nhân đôi ở cascade thứ 2 trở đi.
- Mục tiêu: ghi điểm cao nhất khi hết giờ.
- HUD: đồng hồ đếm ngược lớn (trung tâm trên) + điểm + combo.

**Vì sao thú vị**: người chơi chủ động "mua" thêm thời gian bằng cách match dài + cascade,
tạo vòng lặp tích cực khác hẳn Time Attack (lượt hữu hạn) và Endless (không áp lực).

## Triển khai

### Logic (game_controller_modes.dart)

```dart
bool get isRush => _isRush.value;
final _isRush = false.obs;

void startRush() {
  _enterMode();
  _isRush.value = true;
  timeLeft.value = kRushInitialSeconds; // 120
  moves.value = 999; // vô hạn hiển thị "∞"
  objective.value = ObjectiveType.score;
  scoreTarget.value = 1 << 28; // không kết thúc theo score
  isSideMode; // getter đã cover isRush
}

void addRushTime(int matchLength) {
  if (!isRush) return;
  final bonus = matchLength - 2; // match-3=+1, match-4=+2, etc.
  timeLeft.value = min(timeLeft.value + bonus, kRushMaxSeconds); // cap 5 phút
}
```

Khi cascade: `addRushTime(matchLength * cascadeMultiplier)` trong `_trySwap`.

Kết thúc: `checkEnd()` nhánh `isRush` — lose khi `timeLeft <= 0`.

### HUD (game_screen.dart)

- Ô moves hiện "∞" (như Zen).
- Ô TIME: đồng hồ lớn hơn, đỏ khi ≤15s, animation giật khi ≤10s.
- Khi match → "+2s" fly-up animation (tái dùng pattern `addTime` của Time Attack).

### Kết thúc

- Thắng/thua: cùng dialog "kết thúc side mode" (không tốn mạng, luôn chơi lại).
- Thưởng: `(score / 1000) xu`, cap 80 xu.
- `SideModeRecord`: lưu `bestScore` (high score mode Rush) → hiện badge ở Home.
- i18n: `rush_title`, `rush_desc`, `rush_time_bonus` (en + vi + `_w21ByLang`).

### Home

- Thêm "TỐC CHIẾN" vào lưới thử thách (6 ô → có thể cần điều chỉnh layout nếu đã đầy).
- Nếu lưới đã 6 ô: thay thế ô ít chơi nhất hoặc nâng lên 3×3.

## Test
- `startRush` isolation: không trừ mạng, không đụng campaign (isSideMode = true).
- `addRushTime`: cộng đúng giây, không vượt cap.
- `checkEnd` timeout đúng.
- SideModeRecord lưu bestScore Rush.
- Widget test: HUD hiển thị "∞" moves + timer.

## Lưu ý
- Timer chạy trong `update(dt)` (tái dùng pattern Time Attack / Survival).
- Cap thời gian tối đa (`kRushMaxSeconds = 300`) chống vô hạn.
- Không dùng `DateTime.now()` — accumulate dt như mọi mode timer.
- Liên quan: [[side-mode-isolation]], [[side-mode-records-w19]].
