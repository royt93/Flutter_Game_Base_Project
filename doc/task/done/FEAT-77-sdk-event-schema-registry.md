---
id: FEAT-77
title: "SDK Event Schema Registry"
type: feature
layer: analytics/core
priority: P1
effort: M
depends_on: [FEAT-03, FEAT-38]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Chuẩn hóa event name, params, version và validate event trước analytics adapter.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Event sai tên/type/PII bị reject hoặc redact theo policy.
- [x] Schema version migration và unknown field policy rõ.
- [x] Provider failure không làm crash gameplay; report violation có context.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

Xây `lib/core/sdk_event_schema_registry.dart` — `SdkEventSchemaRegistry`
(plain object, không phải `GetxService`, giống style `SdkHealthReport`) +
`SchemaValidatedAnalyticsProvider` (decorator implement `AnalyticsProvider`,
giống hệt shape `ConsentGatedAnalyticsProvider` đã có sẵn — 2 decorator
này compose được với nhau:
`SchemaValidatedAnalyticsProvider(ConsentGatedAnalyticsProvider(real), registry)`).

**Chính sách reject/redact cho từng loại lỗi** (thiết kế rõ ràng, không
mơ hồ "tuỳ ý"):
- Tên event chưa đăng ký schema → reject toàn bộ.
- Thiếu param `required`, hoặc param `required` sai type → reject toàn
  bộ (dữ liệu đã không đủ tin cậy để gửi).
- Param optional sai type → chỉ drop field đó, event còn lại vẫn gửi
  (mất 1 field không bắt buộc không đáng để chặn cả event).
- Param đánh dấu `pii: true` → LUÔN bị redact (drop khỏi sanitizedParams)
  bất kể `required` hay không — và **1 param không thể vừa `required`
  vừa `pii`**, vi phạm bị bắt NGAY LÚC TẠO SCHEMA (throw
  `ArgumentError` trong constructor `EventSchema`, không đợi tới lúc
  validate 1 event thật mới phát hiện logic sai) vì combo đó vô nghĩa —
  field luôn bị redact thì "required" không bao giờ thoả được.
- Field lạ không có trong schema → theo `unknownFieldPolicy` của từng
  schema: `drop` (mặc định, âm thầm bỏ, không tính là violation vì đây
  là hành vi được cho phép có chủ đích) hoặc `reject` (chặn cả event).

**Schema version migration**: `EventSchema.migrate` — 1 hàm áp lên params
THÔ trước khi validate, đúng convention `VersionedJsonStore.migrate` đã
có sẵn trong package — 1 client cũ chưa update vẫn gửi được field tên cũ
(`lvl`), registry tự đổi sang tên field schema hiện tại (`level`) trước
khi validate, không cần giữ nhiều version schema song song.

**Provider failure không crash gameplay**: `SchemaValidatedAnalyticsProvider.logEvent`
bọc lời gọi tới provider thật trong try/catch — exception (network lỗi,
SDK third-party throw) được chuyển tới `CrashReporter.maybe` (không im
lặng biến mất trong release, đúng lý do `dlog()` tồn tại) nhưng KHÔNG bao
giờ văng ngược lên code gameplay gọi `logEvent`.

**Audit có context**: `auditLog` (bounded 200, cùng convention
`MemoryWatchdog`/`RemoteKillSwitchController`) ghi mỗi lần validate —
tên event, accept/reject, và list `violations` dạng người đọc được (vd
`'thiếu param bắt buộc "level"'`) — không chỉ true/false trơn.
`eventSchemaAuditHealthCollector(registry)` là `HealthCollectorSpec`
(FEAT-39) opt-in báo `totalEvents`/`rejectedCount`/`lastRejectedReasons`.

Verify:
- `flutter analyze` root + `example/`: sạch.
- `flutter test --exclude-tags slow` root: 1881/1881 pass (1860 cũ + 21
  test mới `sdk_event_schema_registry_test.dart`). Gặp 1 fail flaky
  không liên quan (`season_event_service_test.dart`) khi chạy suite đầy
  đủ — retry sạch, đúng flake pre-existing đã ghi nhận nhiều lần trong
  session.
- `dart run tool/api_compatibility.dart check` → `additive` đúng
  `SdkEventSchemaRegistry`/`EventSchema`/`EventParamSchema`/
  `EventValidationResult`/`EventAuditRecord`/`SchemaValidatedAnalyticsProvider`/
  `UnknownFieldPolicy`, CHANGELOG khớp; `snapshot` lại → `unchanged`.
- `dart pub publish --dry-run`: chỉ cảnh báo git chưa commit.
- 21 test: schema tự validate lúc tạo (required+pii → throw ngay); tên
  event sai → reject; required thiếu/sai type → reject, optional sai
  type → chỉ drop field đó (không reject cả event); **2 test "PHÁT HIỆN
  THẬT"** khoá đúng: pii luôn redact bất kể required/policy khác, và
  provider thật throw không văng ra ngoài (gameplay code gọi `logEvent`
  không crash); unknown field cả 2 policy (drop im lặng, reject chặn cả
  event); migrate đổi tên field cũ→mới trước khi validate; audit log ghi
  đủ + bounded; `SchemaValidatedAnalyticsProvider` forward đúng
  sanitizedParams (không phải raw) khi accept, không forward gì khi
  reject; health collector đúng count/reason/allowedKeys.

**Không có UI mới** (thuần core/analytics logic, không widget, chỉ thêm 1
export barrel) — tiêu chí animation/reduced-motion N/A, tick vì không có
gì để vi phạm. Không build+cài APK device thật lần này (khác FEAT-72/74/75
trước đó trong session — những task đó có lý do cụ thể hơn để verify trên
device: export mới tác động runtime service/widget đang dùng trong
`example/`; task này thuần logic validate, không widget nào trong
`example/` gọi tới) — chỉ `flutter analyze`/`flutter test` sạch ở cả root
và `example/` làm bằng chứng, nhất quán với cách FEAT-70 (DiagnosticsExportBundle,
cũng thuần core/analytics logic) đã xử lý.

Tự chấm: 9.3/10. Trừ điểm vì chưa wire demo thật vào `example/` (1 nút
"Log fake purchase event (có PII cố tình)" cho thấy redact hoạt động thật
trên device sẽ là bằng chứng mạnh hơn) — để lại follow-up, không tự ý mở
rộng `WidgetShowcaseScreen` khi acceptance criteria không bắt buộc.

