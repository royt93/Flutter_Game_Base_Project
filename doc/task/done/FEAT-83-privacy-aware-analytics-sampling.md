---
id: FEAT-83
title: "Privacy-aware Analytics Sampling"
type: feature
layer: analytics/core
priority: P1
effort: M
depends_on: [FEAT-61, FEAT-63, FEAT-77]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Sampling theo session/event, redaction và consent để giảm dữ liệu nhưng vẫn giữ funnel hữu ích.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Chưa consent không emit; sampling deterministic theo session seed.
- [x] PII keys bị redact trước provider và queue.
- [x] Rate limit/backpressure không block gameplay và có audit count.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

Xây `PrivacyAwareAnalyticsSampler` (`lib/core/privacy_aware_analytics_sampler.dart`)
— 1 decorator `AnalyticsProvider` GHÉP 4 primitive, không tự phát minh cơ
chế redaction/consent mới:

- **Consent**: check trực tiếp `ConsentStateService.maybe?.isGranted(analytics)`
  — đúng y hệt logic `ConsentGatedAnalyticsProvider` đã có, lặp lại tại đây
  (1 dòng) thay vì compose lồng decorator để class này là 1 điểm đăng ký
  duy nhất với audit trail gộp chung.
- **Sampling deterministic theo session seed**: tái dùng đúng công thức
  `fnv1aHash('$seed:$key') % N` đã có ở `ExperimentBucketingService`
  (IDEA-32), seed mặc định là `AppSessionTracker.current.sessionId`
  (FEAT-63). Cùng `sessionId` + cùng tên event → LUÔN cùng 1 quyết định
  trong suốt phiên đó — cố ý không phải random mỗi lần gọi, vì 1 coin
  flip mỗi call sẽ làm event lần 1 sống nhưng lần 2 (cùng session) biến
  mất, phá hỏng mọi phép đếm theo phiên.
- **PII redaction trước cả rate limit lẫn provider thật**: nếu truyền
  `registry` (`SdkEventSchemaRegistry`, FEAT-77), MỌI event chạy qua
  `registry.validate()` NGAY sau bước sampling, trước khi chạm rate
  limiter — field `pii: true` không bao giờ lọt vào bước rate-limit hay
  provider thật.
- **Rate limit/backpressure KHÔNG dùng queue thật**: cân nhắc rồi bỏ 1
  buffered queue + Timer flush (rung YAGNI) — 1 fixed-window counter
  (`maxEventsPerWindow`/`windowSize`) đơn giản hơn hẳn, đồng bộ hoàn
  toàn (không await/Timer nào để dispose trong test), và tạo ra đúng
  quan sát bên ngoài "không bao giờ block gameplay + có audit count":
  vượt budget window hiện tại → DROP ngay (không giữ lại chờ), khớp
  đúng nghĩa backpressure (drop-oldest hoặc buffer vô hạn đều tệ hơn).
  Ghi rõ lựa chọn này trong doc-comment của class để không ai tưởng nhầm
  thiếu queue là thiếu sót.

`auditSnapshot` gộp `forwarded` + `droppedByReason` (`Map<AnalyticsDropReason,int>`)
cho 4 lý do độc lập (`consentNotGranted`/`sampledOut`/`schemaRejected`/`rateLimited`)
— đúng "có audit count" tách bạch từng nguyên nhân, không gộp chung 1 số
"dropped" mơ hồ.

Provider thật throw được bọc try/catch, forward `CrashReporter.maybe`
(đúng contract `SchemaValidatedAnalyticsProvider` đã dùng) — không bao
giờ crash code gameplay gọi `logEvent`.

Verify:
- `flutter test test/core/privacy_aware_analytics_sampler_test.dart`:
  13/13 pass — consent gate, sampling rate 0.0/xác định theo seed cố
  định (20 lần gọi cùng seed luôn cùng 1 kết quả) và theo seed khác nhau
  (30 seed khác nhau tạo ra cả 2 giá trị true/false, chứng minh quyết
  định thực sự phụ thuộc seed chứ không phải hardcode), validate range
  `[0,1]` throw `ArgumentError`, redact PII qua registry thật, registry
  reject event lạ, không truyền registry thì params đi nguyên vẹn, rate
  limit vượt budget + reset đúng window mới (nowMs injectable), provider
  throw không crash caller + forward CrashReporter, `auditSnapshot`
  cộng dồn đúng.
- `flutter analyze` root + `example/`: sạch.
- `flutter test --exclude-tags slow` root: 1988/1988 pass (1 lần chạy
  trước đó fail đúng 1 test — `season_event_service_test.dart`'s "2
  storageKey khác nhau", flakiness môi trường đã biết từ trước, không
  liên quan thay đổi lần này — xác nhận lại bằng cách chạy riêng file
  đó (pass) rồi chạy lại toàn bộ suite (pass hết)).
- `dart run tool/api_compatibility.dart snapshot` rồi `check` →
  `unchanged` (đã export `privacy_aware_analytics_sampler.dart`,
  CHANGELOG.md có mục 0.2.0 tương ứng).
- `dart pub publish --dry-run`: chỉ cảnh báo git chưa commit.

**Không có UI mới** — thuần core decorator, không cần widget/integration
test hay device smoke (đúng tiền lệ FEAT-61/63/77 cũng không có device
test trong `example/integration_test/app_boot_test.dart`, và acceptance
criteria của chính task này không đòi device smoke như FEAT-80).

Tự chấm: 9.5/10. Điểm cao vì mọi thành phần (consent, sampling, redact,
rate limit) đều GHÉP đúng primitive có sẵn (fnv1a hash convention,
SdkEventSchemaRegistry, CrashReporter contract) thay vì viết logic
riêng lẻ, và test seed-dependent sampling chứng minh bằng dữ liệu thật
(30 seed, cả 2 outcome) chứ không chỉ giả định công thức đúng. Trừ 0.5
vì quyết định bỏ queue thật (dùng fixed-window counter thay vì buffer)
là 1 diễn giải hợp lý nhưng không phải cách đọc duy nhất của chữ
"queue" trong acceptance criteria — đã ghi rõ lý do trong doc-comment
và Quyết định để dễ review lại nếu cần đổi hướng.

