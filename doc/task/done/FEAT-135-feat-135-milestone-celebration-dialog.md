---
id: FEAT-135
title: MilestoneCelebrationDialog — Modal chúc mừng chạm mốc level quan trọng kèm pháo hoa
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Casual Game & Retention Expansion (Wave 8)
---

## Vì sao cần
Khi người chơi vượt qua các cột mốc lớn (Level 25, 50, 100, 500), một thông báo chúc mừng trang trọng với huy hiệu vàng, cờ hoa và danh sách quà tặng kỷ niệm tạo cảm giác gắn bó lâu dài và ghi nhận nỗ lực của người chơi.

## Đề xuất phạm vi
Widget `MilestoneCelebrationDialog` hiển thị:
- Modal in-tree dạng overlay (tuân thủ quy chuẩn `NeonDialog.overlay` / `NeonDialog.show` không phụ thuộc route để an toàn với Flame `GameWidget`).
- Huy hiệu mốc cấp độ với số level to bản và vệt sáng xoay nhẹ.
- Danh sách phần thưởng cột mốc (coins, boosters, special avatar frame).
- Nút bấm nhận thưởng gọi callback `onClaimTap`.
- Phương thức tiện ích static `MilestoneCelebrationDialog.show(context, ...)`.
- Hỗ trợ Reduced Motion: huy hiệu đứng yên, không xoay vệt sáng.

## Yêu cầu kiểm thử
- [x] **Unit test**: Validate level cột mốc dương, danh sách phần thưởng không rỗng, label reward không rỗng.
- [x] **Widget test**: Nút Claim gọi `onClaimTap`; Reduced Motion giữ vệt sáng tĩnh; semantics đọc rõ level và tất cả rewards; overlay `NeonDialog.show` mở/đóng đúng.
- [x] **Showcase test**: Nút mở dialog level 50, Claim cập nhật trạng thái caller-owned.
- [x] **Physical integration**: Smoke pass trên Google Pixel 7 Pro (`2B051FDH3006MU`), không dùng simulator.

## Hiệu năng & Animation
- [x] Huy hiệu và `SunburstGodRays` nằm trong `RepaintBoundary`; animation controller dispose khi unmount.
- [x] **Pixel 7 Pro benchmark telemetry (81 frames, 4 chu kỳ workload Wave 8)**: p50=17.69ms (~56.5 FPS median), p95=73.22ms, p99=169.51ms, slow=56.8% (46), jank=11. Tia sáng quay nhẹ và nảy dialog mượt ở median ~56.5 FPS; jank tập trung lúc mở modal; không tuyên bố sustained 60 FPS.
