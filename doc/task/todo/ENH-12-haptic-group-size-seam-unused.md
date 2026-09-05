---
id: ENH-12
title: hapticLevelForGroupSize chưa có callsite production nào (seam chờ dùng)
type: enhance
priority: P2
effort: S
verified: true
source: Claude (fork nội bộ, phát hiện ở vòng audit đầu tiên, bị sót chưa ghi file — bổ sung ở vòng cuối)
---

## Vị trí
`lib/core/haptics.dart:10-16`

## Hiện trạng
`hapticLevelForGroupSize(int size)` có doc comment tự ghi rõ: "use this once
real group/pop matching rules exist" — đây là 1 seam được để lại có chủ đích
từ thời repo còn là match-3 game (Pop Star Blast, xem lịch sử trong
CLAUDE.md), không phải code chết ngẫu nhiên. Grep xác nhận: chỉ được gọi từ
`test/core/haptics_test.dart`, không có callsite nào trong `lib/`/`example/lib/`.
`fireHaptic()` (hàm thật sự dùng trong production) chỉ dùng `_softModeDowngrade`,
không dùng `hapticLevelForGroupSize`.

## Vì sao vẫn ghi nhận (không phải bug)
Không cần sửa gì ngay — không có cơ chế match/combo thật nào trong package
này để nối vào. Ghi nhận để không quên: khi 1 game thật (dùng kit này) có cơ
chế "nổ nhóm N item cùng lúc" (match-3, connect, v.v.), nối `fireHaptic` với
`hapticLevelForGroupSize(groupSize)` ngay tại đó thay vì tự viết lại mapping.

## Yêu cầu test
Hàm thuần `hapticLevelForGroupSize` đã có unit test đầy đủ ở
`test/core/haptics_test.dart` — không cần thêm gì cho tới khi có callsite
thật. Widget/integration test chỉ có ý nghĩa khi gắn với 1 tính năng gameplay
cụ thể gọi tới nó — không tạo demo giả cho 1 hàm thuần không có UI.

## Acceptance criteria
- [ ] (Chỉ khi có game mechanic thật cần) callsite mới gọi `hapticLevelForGroupSize` thay vì viết lại mapping riêng.
