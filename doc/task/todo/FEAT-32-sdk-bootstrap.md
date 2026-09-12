---
id: FEAT-32
title: "RoyCasualKit.initialize — bootstrap SDK idempotent theo module"
type: feature
layer: core
priority: P0
effort: M
depends_on: [ENH-56]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là consumer, tôi muốn khởi tạo SDK bằng một API để không phải nhớ thứ tự `Get.put` của từng service.

## Sprint slices
- Thiết kế `RoyCasualKitConfig` immutable và danh sách module bật/tắt.
- Khởi tạo Storage trước các service phụ thuộc, trả về trạng thái typed.
- Gọi lặp không tạo singleton mới; hỗ trợ reset/dispose dành cho test.
- Chuyển example sang dogfood bootstrap mới và viết migration guide.

## Acceptance criteria
- [ ] Minimal init và full init đăng ký đúng service, đúng thứ tự và không double-init.
- [ ] Module tắt không gọi platform channel hay để accessor trả instance giả.
- [ ] Lỗi module có policy fail-fast/degraded rõ ràng và không để registry nửa vời.
- [ ] API public được export qua entrypoint và có example tích hợp.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement từng slice bằng TDD, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: audit lại code changes và chấm điểm /10; bổ sung unit test + widget test + integration test cho mọi case happy/edge/error/lifecycle; chạy analyze/test root và example; smoke test trên Android device thật, lưu screenshot/log chứng minh. Nếu work chưa đúng hoặc điểm <=9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới commit + push code; sau đó cập nhật `## Quyết định`, chuyển task sang done, commit + push lần hai.

