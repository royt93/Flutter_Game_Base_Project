---
id: FEAT-98
title: "Privacy-aware analytics queue"
type: feature
priority: P1
effort: M
source: "differentiator độc quyền"
---

## Vị trí

Mới, ghép `lib/core/analytics_provider.dart`, `consent_gated_analytics_provider.dart`, `privacy_aware_analytics_sampler.dart:32-68`, `offline_outbox_service.dart`, `sdk_event_schema_registry.dart:112-147`, `utils/retry_policy.dart`.

## Hiện trạng

Consent gate + sampling/schema/rate-limit đã có, offline outbox đã có, nhưng analytics provider interface `void logEvent` forward trực tiếp — chưa có bounded persistent analytics queue/batch. Offline event hợp lệ bị drop hoặc phụ thuộc vendor adapter tự giải quyết.

## Vì sao cần / Hậu quả

Không có vendor-neutral, consent-safe offline analytics path; consumer dễ queue trước consent hoặc giữ PII chưa validate.

## Đề xuất

Decorator/service local: consent trước tiên, schema validate + redact, sampling, enqueue bounded FIFO vào outbox, flush batch bằng retry policy. Drop observable theo reason; clear-on-success crash-safe. Ceiling: không transport/network — consumer cung cấp uploader adapter.

## Acceptance criteria

- [x] Denied/unknown consent không queue bất kỳ event nào.
- [x] Validate/redact trước enqueue; schema reject không chạm outbox.
- [x] Queue bounded FIFO; overflow/drop reason observable.
- [x] Flush retry qua RetryPolicy/outbox; success clear crash-safe, failure giữ item.
- [x] Không thêm vendor SDK/transport/network.

## Quyết định

- **Implementation**: `lib/core/privacy_aware_analytics_queue.dart` — thứ tự cố định consent → schema validate/redact → sampling FNV-1a → enqueue bounded FIFO (reject-newest khi đầy, lý do quan sát được qua `AnalyticsQueueAudit`). Consent revoke purge ngay memory + storage, chặn ACK đang bay. Persist qua 1 tail tuần tự; `enqueueDurably` rollback memory nếu ghi đĩa lỗi. `flush()` single-flight, upload all-or-nothing qua `RetryExecutor`/`RetryPolicy` đã fix ở BUG-96. `logEvent` sync không bao giờ throw ra ngoài.
- **TDD & Test coverage**: 10 unit test core (consent gate, redact, FIFO reject-newest, sampling determinism, hydrate/corrupt storage, retry fail/success, single-flight concurrency, revoke purge, persistence-failure rollback, constructor validation); widget demo 2 test (queue/drop/upload, revoke) trong `widget_showcase_screen_test.dart`; device test thật trên SharedPreferences xác nhận redacted queue sống qua failed flush + restart process, rồi xoá sạch khi flush thành công.
- **Phân tích/test**: Root 2537/2537 pass, example 200/200 pass, `flutter analyze` sạch 2 nơi, API compatibility additive rồi regenerate snapshot unchanged, `dart pub publish --dry-run` không lỗi nội dung package, đủ 5 quality-gate script pass. Device test pass trên TECNO KJ7.
- **Audit**: Fork độc lập review toàn batch (bao gồm FEAT-98) đạt 9.8/10, 0 finding thật về consent/privacy/concurrency/persistence.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)

Đọc kỹ file task này trước khi làm. Đọc toàn bộ file source liên quan trước khi thiết kế. Implement bằng TDD.
Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test + widget test + integration test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ `example/`.
4. Smoke test trên device Android thật có bằng chứng (khi task đổi hành vi quan sát được).
Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.
Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, commit + push lần hai.

## Ghi chú độ tin cậy

Cao. Đã đọc analytics seam (sync `void logEvent`), consent decorator, sampler (consent/schema/sampling/rate-limit, drop not queue), schema registry, offline outbox/retry primitive. Không có analytics-specific persistent queue hiện tại.
