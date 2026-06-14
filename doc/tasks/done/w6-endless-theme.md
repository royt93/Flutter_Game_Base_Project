---
id: w6-endless-theme
title: Endless mode + Theme đổi màu theo thế giới
wave: 6
status: done
owner: claude
---

# Endless mode (thử thách tăng dần) + Theme-per-world

## Endless mode
- `ObjectiveType.endless` + `buildEndlessLevel()` (8×8, 6 màu, 20 lượt khởi đầu).
  KHÔNG nằm trong `kRotatingObjectives` (100 màn thường không dính endless).
- **Cơ chế tăng dần**: ghép lớn hoàn lượt (match-5 +2, match-4 +1) nhưng lượt
  hoàn GIẢM khi stage cao → chơi lâu sẽ cạn lượt → thua (có kết thúc tự nhiên).
  Stage tăng mỗi `kEndlessStageScore` (1500đ). High score riêng
  `StorageKeys.endlessHigh`.
- **Không tốn mạng** (chế độ phụ): `_onGameEnd` bỏ qua `consumeLife` khi endless;
  `again()` chơi lại bằng `startEndless`.
- HUD: badge "ENDLESS", ô giữa hiện STAGE, panel kết thúc hiện điểm + kỷ lục.
- Vào từ nút **ENDLESS** ở Home (dưới CHƠI NGAY).

## Theme đổi màu theo thế giới
- `NeonTheme.accentForWorld(worldIndex)` — nguồn DUY NHẤT (gom trùng lặp ở
  `WorldMapScreen.worldColor` + `level_select`).
- `NeonBg` nhận tham số `accent` optional → tia sweep + nebula nghiêng về tông
  màu thế giới (null = palette đa sắc mặc định, không vỡ màn khác).
- GameScreen bọc `NeonBg(accent: ...)`: màu theo thế giới của màn đang chơi;
  Endless đổi màu theo stage (cảm giác tiến sâu).

## Kết quả
0 analyzer issue · test ở `test/w6_test.dart` (endless factory/ramp/lose +
accentForWorld + worldOfLevel) · build APK debug OK.
