---
id: FEAT-38
title: "SdkResult và lỗi typed thống nhất cho public API"
type: feature
layer: core
priority: P1
effort: M
depends_on: [ENH-56]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là consumer, tôi muốn xử lý lỗi SDK theo code/retryability thay vì đoán exception hoặc gặp silent failure.

## Sprint slices
- Sealed result success/failure và taxonomy validation/storage/platform/network/conflict.
- Giữ cause + stack trace nội bộ; public message không chứa secret/PII.
- Mapping convention cho API mới; migration có chọn lọc cho service cũ.
- Analytics/crash hooks nhận structured failure.

## Acceptance criteria
- [ ] Pattern match exhaustive, typed payload và equality/toString an toàn.
- [ ] Stack trace/cause không mất; retryable được xác định rõ.
- [ ] Ít nhất hai service khác loại dùng model nhất quán.
- [ ] Migration không phá API public ngoài phần đã document.

## Prompt loop feature
Đọc task và error paths; implement tối thiểu bằng TDD. End loop: audit changes, chấm /10; unit test + widget test + integration test mọi success/error/mapping/redaction; analyze/test root + example; smoke device thật chứng minh UI xử lý lỗi typed. Lặp đến work và điểm >9/10 mới commit + push; cập nhật Quyết định, chuyển done, push lần hai.

