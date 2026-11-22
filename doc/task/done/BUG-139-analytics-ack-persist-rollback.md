---
id: BUG-139
title: "PrivacyAwareAnalyticsQueue: giữ event khi ghi ACK removal thất bại"
type: bug
layer: lib/core/privacy_aware_analytics_queue
priority: P2
effort: S
source: "Full source audit 2026-11-21; flush drops same-instance batch after ACK persistence failure"
---

## Bằng chứng

`_flushInternal` gỡ batch khỏi queue và tăng `_uploaded` trước khi persist removal. Nếu ghi storage thất bại, flush trả `SdkFailure(storage)` nhưng instance hiện tại đã bỏ event; lần flush sau thấy queue rỗng. Event chỉ xuất hiện lại sau process restart nếu disk còn snapshot cũ.

- `lib/core/privacy_aware_analytics_queue.dart:329-343`
- `test/core/privacy_aware_analytics_queue_test.dart:285-307` bao phủ enqueue failure, chưa ACK-removal failure.

## Phạm vi

Khôi phục queue/counters nếu ACK-removal persist thất bại, bảo toàn semantics retry/upload hiện tại. Không thay đổi consent, redaction, sampling, hoặc transport.

## Acceptance criteria

- [x] Failure-injection test: ACK thành công nhưng persistence xóa batch thất bại; flush trả storage failure và event còn có thể retry trong cùng instance.
- [x] `_uploaded`/audit counters chỉ tăng sau khi removal persist thành công; at-least-once/replay semantics được ghi rõ.
- [x] Restart/storage assertion xác nhận event vẫn nằm trong persisted snapshot sau ACK removal failure; consent-revoke và concurrent enqueue tests bảo vệ không phục hồi/xóa nhầm event.
- [x] Unit, widget và integration coverage cho failure/retry; integration chạy trên device thật.
- [x] Audit code changes và điểm >9/10 (rubric + bằng chứng dưới đây).
- [x] Physical-device smoke trên example với fake uploader; ghi device/build/flow/output. Không simulator.

## Prompt loop

Đọc task, queue/flush state machine, durable persistence tail, consent-revoke path, provider call contract và tests. Tạo test làm persistence ACK-removal thất bại sau khi uploader trả success. Sửa nhỏ nhất để same-instance retry không mất event và counter đúng; giữ nguyên consent revoke guarantee và retry semantics. Chạy unit tests liên quan, widget/integration nếu có boundary phù hợp, analyze và physical-device smoke qua example với provider giả lập (không ad/network thật). Audit code changes và chấm /10 theo rubric; lặp tới >9/10 và acceptance đều đạt. Nếu phát hiện consent/privacy side effect cần quyết định, test đỏ, device evidence thiếu, hoặc điểm <=9, dừng ghi blocker, không push. Khi mọi gates đạt và điểm >9/10, ghi kết quả/điểm rồi push code theo yêu cầu owner.

## Kết quả thực hiện

- Audit / điểm: **9.2/10** — correctness 4/4, tests 2/2, data/consent semantics 2/2, maintainability 0.7/1 (isolated demo screen/storage is scoped but adds UI), device evidence 0.5/1 (one real physical integration run passed; screenshots show both states).
- Unit/widget/integration: `flutter test test/core/privacy_aware_analytics_queue_test.dart` pass 25/25, including ACK-removal failure, concurrent enqueue preservation and consent revoke. Home/demo widget tests pass; FEAT-98 showcase group passes 3/3; direct screen tests verify isolated global storage. `cd example && flutter test --no-pub integration_test/analytics_ack_recovery_test.dart -d R5CX613VZBR --dart-define=E2E_TEST=true` pass on real device. `flutter analyze` clean; API compatibility unchanged; formatter/diff checks pass. Full example suite passed before final direct screen; focused relevant tests passed afterward. Root non-golden suite has two unrelated `performance_budget_check_test.dart` failures because `example_app_boot_wall_ms` baseline is stale; no baseline/policy changes.
- Device smoke: Samsung Galaxy S24 Ultra SM-S928B, Android 16, debug `E2E_TEST=true`, package `com.galaxyjoy.roycasualkit`. Direct Home → Analytics ACK demo; grant demo consent, queue synthetic event, arm failure, flush showed `Pending: 1 · Uploaded: 0` and `ACK received; save failed, event retained for retry`; second flush showed `Pending: 0 · Uploaded: 1` and `Flush saved; retry complete`. Screenshots: `/tmp/bug139-s24u-ack-failure.png`, `/tmp/bug139-s24u-ack-retry.png`. Fake uploader and in-memory storage only; no analytics backend, PII, or ads.
- Commit/push: `d6ae94f245d44a02c55121b2821ca8a3b750a0d9` (`test: add direct analytics ACK failure demo`), pushed; this is current `origin/main`.
- Rủi ro còn lại: demo mô phỏng lỗi storage bằng `StorageService(null)` (RAM), không chứng minh disk/fsync behavior. Root performance baseline failures unrelated; giữ nguyên baseline/policy.
