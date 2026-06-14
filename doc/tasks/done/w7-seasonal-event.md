---
id: w7-seasonal-event
title: Sự kiện theo mùa (offline)
wave: 7
status: done
owner: claude
---

# Sự kiện thời gian giới hạn (offline, không cần backend)

> Lý do chọn: tạo cảm giác "mới mỗi tuần" mà không cần server. Dựa hoàn toàn vào
> đồng hồ thiết bị (`clock()` đã có sẵn, inject test được).

## Cơ chế
- **Mùa = 1 tuần** (mốc theo `_todayEpochDay ~/ 7`). Đổi tuần → mùa mới, reset tiến trình.
- Mỗi mùa có **theme riêng** (đổi accent + tên + icon) — tái dùng `accentForWorld`.
- **Chuỗi 5 level sự kiện đặc biệt** (sinh từ generator có sẵn, seed theo số mùa
  để xác định + lặp lại được khi test).
- **Thanh tiến trình mùa**: hoàn thành level event → +điểm mùa → mở mốc thưởng
  (xu / booster / shard / cosmetic).

## Dữ liệu
- `lib/data/season.dart`: `seasonIndex(clock)`, `seasonTheme(idx)`, `seasonLevels(idx)`,
  `seasonMilestones`.
- Persist: `season_progress`, `season_claimed_<idx>_<milestone>`, `season_last_idx`
  (đổi mùa → reset progress, KHÔNG xoá claimed cũ để tránh nhận lại).

## UI
- Banner "SỰ KIỆN" ở Home (chỉ hiện khi đang trong mùa) + đếm ngược hết mùa.
- `season_screen.dart`: thanh tiến trình + mốc thưởng + nút chơi level event.

## Lưu ý chống lỗi
- Đổi đồng hồ lùi (user chỉnh giờ) → KHÔNG được nhận lại thưởng đã claim
  (key claimed gắn theo seasonIndex tuyệt đối, không theo progress).

## Test
- seasonIndex tăng đúng theo tuần; đổi mùa reset progress; claim 1 lần/mốc;
  chỉnh giờ lùi không exploit.

## Trạng thái — ✅ DONE
`data/season.dart` (mùa = 7 ngày, 5 theme, 6 mốc thưởng, điểm thắng = 10+8×sao),
`season_controller.dart` (reset điểm khi đổi mùa, cờ nhận keyed tuyệt đối chống chỉnh giờ lùi,
đếm ngược hết mùa), hook `addWin` ở `_onGameEnd`, `season_screen.dart` (banner theme + countdown
+ mốc), entry hàng meta Home, i18n en+vi, reset trong `resetProgress`.
Kết quả: 0 analyzer · test `test/w7_season_test.dart` (7) pass.
