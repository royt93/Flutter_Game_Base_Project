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

- Test matrix/decision: chọn `analytics_ack_recovery` (46 dòng), `offline_outbox_recovery` (86), `experiment_build_mode` (57): user-visible golden path, ngắn, không phụ thuộc đo hardware. Giữ manual: 15 `*_perf_test.dart` + `d4_perf_memory_test.dart` (đo frame/memory, nhạy thiết bị), `app_boot_test.dart` (~6k dòng).
- Runtime/stability evidence: Pixel 7 Pro, 3 lần/test với `--dart-define=E2E_TEST=true`: 9/9 pass, ~26-37s/test. Không có `E2E_TEST`, `analytics_ack_recovery` fail 3/3 (audioplayers frame callback sau dispose), nên CI bắt buộc truyền cờ. Chưa có số liệu runtime trên emulator CI.
- Quyết định: **manual-only**. Đã thử job `example-integration` trên emulator CI, 3 lần đều đỏ vì hạ tầng chứ không phải test: (1) `45035954309` Gradle GC thrash với `-Xmx8G`; (2) `45037169741` thiếu `android.useAndroidX` vì `example/android/gradle.properties` bị gitignore; (3) `45038360508` `Java heap space` ở `JetifyTransform` dù đã hạ `-Xmx3G` (cùng triệu chứng `benchmark.yml` đã ghi). Runner chia RAM giữa Gradle và emulator quá chặt cho app example nặng. Job đã gỡ (không để job đỏ trên main).
- Chạy tay: 3 test `analytics_ack_recovery`, `offline_outbox_recovery`, `experiment_build_mode`, lệnh trong `example/README.md`, cờ `E2E_TEST=true` bắt buộc.
- Audit / điểm: ~8.5/10. Trừ điểm: mục tiêu CI tự động không đạt; đã ghi rationale + evidence thiết bị thật 9/9.
- Tests/device smoke: 3 test trên thiết bị thật (xem trên).
- Commit/push:
