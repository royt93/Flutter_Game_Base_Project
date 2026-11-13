---
id: BUG-114
title: "OfflineEarningsPopup, TieredLeaderboardRow, VipPerkProgressRow tràn ngang ở 320dp với chữ 2.0x"
type: bug
layer: lib/widgets/common
priority: P2
effort: S
source: "FEAT-200 pha 2c: viewport sweep 2026-11-13"
---

## Tái hiện (sweep, 320x480 và text scale 2.0)
- `OfflineEarningsPopup`: `offline_earnings_popup.dart` Row icon + số coin (cỡ 34) tràn 204px.
- `TieredLeaderboardRow`: `tiered_leaderboard_row.dart` Row chính, ô điểm không co giãn nên ép cột tên tràn 51px.
- `VipPerkProgressRow`: `vip_perk_progress_row.dart` Row trong chip perk (`mainAxisSize.min`) tràn 86px.
Vị trí được lấy chính xác bằng test tạm bắt `FlutterErrorDetails` (dòng "relevant error-causing widget"); ở các viewport khác và chữ 1.0x cả ba đạt.

## Đã sửa
- `OfflineEarningsPopup`: bọc cặp icon + số trong `FittedBox(scaleDown)`.
- `TieredLeaderboardRow`: ô điểm bọc `ConstrainedBox(maxWidth: 120)` + `FittedBox(scaleDown)`.
- `VipPerkProgressRow`: nhãn chip bọc `Flexible` + `TextOverflow.ellipsis`.
Cả ba chỉ co khi chật, nên ở kích thước chuẩn giao diện không đổi: golden của ba widget (`offline_earnings_popup`, `tiered_leaderboard_row`, `vip_perk_progress_row`) vẫn khớp pixel khi chạy với phần sửa, không cần regenerate. Sweep mở rộng (12 widget ở 5 viewport và ở chữ 2.0x), 46 test xanh; các test riêng của ba widget xanh.

## Ghi chú
`OfflineEarningsPopup` có `GestureDetector` chạm-để-bỏ-qua giữ nguyên theo quyết định ENH-108.
