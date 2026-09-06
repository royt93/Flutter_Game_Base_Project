---
id: ENH-02
title: fmtDur cần biến thể hỗ trợ hh:mm:ss cho timer dài hơn 1 giờ
type: enhance
priority: P2
effort: M
source: agy, đã verify + điều chỉnh mức độ nghiêm trọng
---

## Hiện trạng
`lib/core/utils/format.dart:8` — `fmtDur` dùng `d.inMinutes.remainder(60)`,
với input > 60 phút sẽ hiện sai (75 phút → "15:00"). **Đây KHÔNG phải bug**:
doc comment ghi rõ mục đích "reconnect countdown" (ngắn), và
`test/core/utils/format_test.dart:9` chủ động assert hành vi này
(`Duration(minutes: 65)` → `"05:00"`) — tức đã được thiết kế + test đúng ý cho
phạm vi hiện tại. Không có call site nào hiện dùng > 60 phút.

## Vì sao vẫn cần enhance
Nếu về sau thêm Energy/Lives system (FEAT-08) hay boss timer nhiều giờ,
`fmtDur` hiện tại sẽ silently sai nếu bị tái sử dụng nhầm. Cần 1 hàm riêng
(không sửa `fmtDur` hiện có, tránh phá vỡ contract/test đang có).

## Đề xuất
Thêm `fmtDurLong(Duration d)` → `hh:mm:ss` khi `d.inHours > 0`, fallback
`mm:ss` khi dưới 1 giờ. Ghi rõ trong doc comment của cả 2 hàm khi nào dùng cái
nào.

## Acceptance criteria
- [ ] `fmtDur` giữ nguyên hành vi/test hiện tại.
- [ ] `fmtDurLong` mới có test cho case > 1 giờ, > 24 giờ.
