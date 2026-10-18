---
id: FEAT-169
title: BadgeShowcaseStrip — Dải huy hiệu trưng bày trên hồ sơ với ô trống có thể chạm
type: feature
priority: P1
effort: S
source: Scrum Master Epic: Player Profile & Cosmetics (Wave 17)
---

## Vì sao cần
Hồ sơ người chơi cần một dải nhỏ trưng bày vài huy hiệu tự chọn (ví dụ tối đa 5 ô) để khoe thành tích. `AchievementRoadmapCard` là lộ trình dài và `CollectionAlbumPanel` là kho đầy đủ; chưa có phần trưng bày cố định số ô.

## Đề xuất phạm vi
Widget `BadgeShowcaseStrip` hiển thị:
- `slotCount` ô (1–8) theo thứ tự; mỗi ô là `BadgeShowcaseItem(id, label, icon?, child?)` hoặc trống.
- Ô trống hiện dấu cộng và `emptyLabel`; chạm gọi `onSlotTap(index)` để caller mở bộ chọn huy hiệu.
- Ô có huy hiệu chạm cũng gọi `onSlotTap(index)` (đổi/xoá do caller xử lý).
- `readOnly: true` (xem hồ sơ người khác): ô trống ẩn hoặc mờ, không có chạm.
- Số ô không đổi vị trí khi nội dung thay đổi; không bị cắt khi textScale 2.0.
- Presentation-only: caller sở hữu danh sách huy hiệu, quyền sở hữu và lưu lựa chọn.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: `slotCount` trong 1..8, số huy hiệu không vượt `slotCount`, id không rỗng và duy nhất, label không rỗng; `ArgumentError` runtime.
- [ ] **Widget test**: 0/một phần/đủ ô, ô trống chạm, ô có huy hiệu chạm trả đúng index, `readOnly` không có chạm, semantics từng ô (vị trí, tên hoặc "ô trống"), target >= 48dp, 320dp + textScale 2.0 gutter 16dp, RTL thật (thứ tự ô đảo đúng).
- [ ] **Integration test (Device)**: chạm ô trống và ô có huy hiệu qua caller seam trên thiết bị thật; kiểm tra lại serial và foreground trước khi chạy, hỏi nếu đang là app khác; không dùng simulator.
- [ ] **Golden test**: `runGoldenMatrix` rỗng/một phần/đủ/readOnly × 7 biến thể, viewport 390×844, baseline từ Linux + Flutter 3.35.1 theo CLAUDE.md.
- [ ] **Interruption test**: đổi `slotCount` hoặc nội dung ô nhiều lần liên tiếp rồi unmount không crash, giá trị cuối đúng, không phát callback thừa.
- [ ] **Network conditioning test**: N/A.
- [ ] **Memory leak & profiling test**: không còn ticker/controller sau unmount và khi reduced motion.
- [ ] **Frame rate / Jank test**: FrameTiming khi thay đổi nội dung ô liên tục (profile thiết bị thật), ghi rõ giới hạn engine timing.
- [ ] **IAP & Ad mediation test**: N/A.

## Hiệu năng & Animation
- [ ] Huy hiệu vừa được gắn vào ô có hiệu ứng pop một lần (không khi mount); `reducedMotion` tắt hiệu ứng; tái dùng `PressableScale`.
