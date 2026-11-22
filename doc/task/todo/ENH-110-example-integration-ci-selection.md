---
id: ENH-110
title: "Chọn integration tests example ổn định để tự động xác minh golden paths"
type: enhancement
layer: CI/example integration tests
priority: P2
effort: M
source: "Full source audit 2026-11-21; example integration suite rộng hơn CI runtime"
---

## Quan sát

Workflow hiện có Flutter analyze/host tests và consumer smoke, trong khi `example/integration_test/` có thêm các golden-path behavior/performance flows không chạy trong CI thường xuyên. Cần đo tính ổn định/runtime trước khi thêm job; đây là gap xác minh cần cân nhắc, không phải lỗi chức năng đã chứng minh.

- `.github/workflows/ci.yml`
- `example/integration_test/`
- `example/README.md`

## Phạm vi

Đề xuất một subset nhỏ, deterministic, phù hợp CI hoặc ghi rationale rõ vì sao giữ manual. Không dispatch CI trong lúc thực hiện task; không mở rộng sang device-cloud nếu chưa có owner approval/budget.

## Acceptance criteria

- [ ] Liệt kê integration cases theo coverage, runtime, flake risk và device/platform dependency.
- [ ] Chọn CI subset hoặc quyết định documented manual-only với rationale cụ thể.
- [ ] Nếu chọn CI: job chạy đúng test selectors, timeout hợp lý, artifacts/logs hữu ích, không làm chạy performance benchmark không ổn định như functional gate.
- [ ] Test config/selector locally; validate workflow syntax hoặc chạy workflow local equivalent. Widget tests không thay thế device integration; unit tests không áp dụng cho CI orchestration (ghi lý do).
- [ ] Audit diff và điểm >9/10 (coverage/value 3, stability/runtime 3, workflow safety 2, docs 1, evidence 1).
- [ ] Physical device smoke chỉ khi test selection/chạy thực app thay đổi; không simulator. Không dispatch CI theo scope này.

## Prompt loop

Đọc CI workflows, toàn bộ example integration test names/tags/duration notes, README/release constraints. Xếp hạng test theo stable user-visible golden path, runtime và dependencies; kiểm tra flake evidence. Nếu phù hợp, đề xuất scope trước khi sửa workflow có cost/provider impact; nếu chưa có intent/budget, ghi quyết định manual-only và rationale. Với thay đổi được phép, thêm subset nhỏ nhất hoặc docs rationale, validate command selectors/CI syntax, chạy relevant host tests và physical-device smoke nếu user-facing path đổi. Audit diff và chấm /10 theo rubric; lặp tới >9/10. Dừng trước dispatch CI hoặc device-cloud use; chỉ dispatch nếu owner cho phép riêng. Khi mọi gates đạt, ghi kết quả; push code chỉ khi điểm >9/10 và tất cả acceptance đạt.

## Kết quả thực hiện

- Test matrix/decision:
- Runtime/stability evidence:
- Audit / điểm:
- Tests/device smoke:
- Commit/push:
