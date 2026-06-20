---
id: w18-1-merge-tournament-season
title: Gộp Giải đấu + Sự kiện mùa → "Mùa giải"
wave: 18
phase: 1
status: todo
owner: claude
---

# Phase 1 — Gộp Giải đấu + Sự kiện mùa thành 1 hệ "Mùa giải"

## Vấn đề hiện tại (audit)
`SeasonController` và `TournamentController` trùng ~70%:
- Cùng earn: điểm khi THẮNG màn thường (`addWin`), reset mỗi 7 ngày.
- Cùng khuôn "tích điểm → claim mốc" (dùng chung switch `RewardKind`).
- Khác THẬT chỉ: Season thưởng xu+booster theo MỐC; Tournament thưởng xu theo HẠNG
  (so 7 bot tất định). Bỏ lớp bot → Tournament = Season-chỉ-xu.
1 lần thắng đẩy 2 thanh điểm song song → người chơi không phân biệt được.

## Thiết kế mới — "Mùa giải" (Season League) hợp nhất
1 hệ duy nhất, 1 đường điểm/tuần, 2 trục thưởng KHÔNG trùng:
- **Trục MỐC (track)**: đạt ngưỡng điểm → mở phần thưởng theo bậc (xu + booster) — vai
  trò cũ của Season.
- **Trục HẠNG (leaderboard)**: cuối tuần xếp hạng so 7 bot → thưởng hạng (xu lớn + danh
  hiệu/khung) — vai trò cũ của Tournament.
→ Cùng 1 điểm số nuôi CẢ 2 trục → không còn 2 hệ riêng, không đẩy 2 thanh.

## Triển khai
- Gộp `tournament_controller.dart` vào `season_controller.dart` (hoặc tạo
  `season_league_controller.dart` thay cả 2). 1 `addWin` → 1 điểm.
- Home: 1 ô "Mùa giải" thay 2 ô (giải phóng 1 slot lưới → dùng cho coin-sink 18.3 hoặc
  để trống cân đối).
- **Migration**: đọc key cũ (`season_*`, `tour_*`) 1 lần → gộp vào key mới; `resetProgress`
  xoá cả cũ + mới (theo [[reset-permanent-controllers]]).
- Data: gộp `season.dart` + `tournament.dart` (mốc + bảng hạng).

## Test
- 1 thắng → +1 điểm (KHÔNG double-count 2 hệ).
- Trục mốc claim đúng; trục hạng tính đúng vs bot; reset tuần keyed tuyệt đối.
- Migration: dữ liệu cũ không mất/không nhận lại thưởng (anti-exploit).
- `resetProgress` sạch (đĩa + RAM).

## Lưu ý
- ⚠️ Cẩn thận anti-exploit khi migrate (đã từng có bug nhận-lại-thưởng — xem
  [[reset-permanent-controllers]]).
- Giữ leaderboard bot TẤT ĐỊNH (offline, không cần mạng).
