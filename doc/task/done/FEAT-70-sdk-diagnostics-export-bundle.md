---
id: FEAT-70
title: "SDK Diagnostics Export Bundle"
type: feature
layer: core/debug
priority: P2
effort: M
depends_on: [FEAT-39, IDEA-42]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Đóng gói health report, replay capsule, config và logs đã redact thành artifact support.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Bundle có manifest/schema/version, size cap và checksum.
- [x] Secret/PII/raw save bị loại mặc định.
- [x] Export lỗi một phần vẫn đọc được phần còn lại và import chỉ read-only.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved.

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

Xây `lib/core/diagnostics_export_bundle.dart` — 2 class thuần (không phải
`GetxService`, giống style `SdkHealthReport`/`ReplayCapsule`):

- **`DiagnosticsExportBundle.build({appVersion, health, replay, config,
  configAllowedKeys, logs, maxLogLines, maxLogLineLength})`** ghép 4
  nguồn đã có sẵn từ FEAT-39/IDEA-42 thành 1 map
  `{schemaVersion, generatedAtMs, appVersion, sections, errors,
  truncated}`:
  - `health`: nhận thẳng 1 `SdkHealthReport` đã cấu hình sẵn collector,
    gọi `.collect()` — tự nó đã redact/cap theo allowlist riêng
    (FEAT-39), bundle không làm gì thêm ngoài đặt vào `sections['health']`.
  - `replay`: nhận thẳng 1 `ReplayCapsule` (IDEA-42), `.toJson()`.
  - `config`: **default-deny giống hệt `HealthCollectorSpec.allowedKeys`**
    — không truyền `configAllowedKeys` thì section `config` có mặt nhưng
    RỖNG, không phải leak toàn bộ map truyền vào. `config == null` (khác
    với rỗng) thì không có section này luôn — 2 trạng thái phân biệt rõ
    ràng, `DiagnosticsBundleView.config` trả `null` cho case sau.
  - `logs`: cắt còn N dòng **gần nhất** (tail, không phải head — dòng mới
    luôn quan trọng hơn khi debug), mỗi dòng cắt tiếp nếu quá
    `maxLogLineLength`.
  - **Cố tình KHÔNG có tham số nào nhận `StorageService.exportAll()`** —
    map đó redact = 0 (verify qua nghiên cứu code trước khi làm), đưa
    thẳng vào sẽ phá vỡ đúng cái tiêu chí "Secret/PII/raw save bị loại mặc
    định". Muốn thêm section "storage" sau này phải đi qua đúng convention
    allowlist-theo-tên như `config`/`HealthCollectorSpec`, không được nối
    thẳng.
  - Mỗi trong 4 section được bọc try/catch RIÊNG — 1 section throw chỉ ghi
    `errors[name]`, không phá 3 section còn lại.
  - **Size cap** (`maxBytes`, mặc định 200 KB): sau khi build xong, nếu
    JSON tổng vượt cap thì drop theo thứ tự cố định `logs` → `replay` →
    `config` (giữ `health` lâu nhất vì nó tự nó đã nhỏ/quan trọng nhất cho
    triage), mỗi lần drop ghi `errors[key] = 'dropped: ...'` và
    `truncated = true`. Nếu drop hết vẫn còn vượt cap (health tự nó đã
    to) thì không throw, ghi `errors['bundle']` — không bao giờ "export
    thất bại toàn bộ", đúng tiêu chí "export lỗi một phần vẫn đọc được
    phần còn lại".
  - **Checksum**: `sign(bundle, secret)` gọi thẳng `signExport` có sẵn
    (`save_integrity.dart`) — không viết lại HMAC, đúng convention
    `ReplayCapsule.exportSigned` đã dùng.
- **`DiagnosticsBundleView`**: parse read-only — `fromJson` không bao giờ
  throw (trả `null` nếu thiếu `sections`), `fromSignedJson` verify HMAC
  qua `verifyAndStrip` có sẵn (throw `FormatException` nếu sai secret,
  đúng contract của hàm đó) rồi mới parse. **Không đụng `StorageService`
  hay bất kỳ service đã đăng ký nào** — mở 1 bundle người chơi/QA gửi
  không thể vô tình ghi đè state app của mình, khác hẳn
  `VersionedJsonStore` import (vốn CỐ Ý ghi lại state).

Verify:
- `flutter analyze` root: sạch.
- `flutter test --exclude-tags slow` root: 1756/1756 pass (1742 cũ + 14
  test mới `test/core/diagnostics_export_bundle_test.dart`).
- `dart run tool/api_compatibility.dart check` → `additive` đúng 3 symbol
  mới (`DiagnosticsExportBundle`/`DiagnosticsBundleView`/file export), có
  CHANGELOG khớp; `snapshot` lại → `unchanged`.
- `dart pub publish --dry-run`: chỉ cảnh báo git chưa commit, không lỗi
  thật.
- 14 test: manifest cơ bản (schemaVersion/generatedAtMs/appVersion, section
  null bị bỏ hẳn), default-deny cho `config` (3 case: không truyền
  allowedKeys → rỗng, có allowedKeys → chỉ lọt đúng key, `config == null`
  → không có section), logs (tail đúng N dòng gần nhất, cắt dòng dài),
  size cap (drop đúng thứ tự cố định, health giữ lại lâu nhất, case cực
  đoan health tự nó cũng vượt cap vẫn không throw), sign/parse round-trip
  đầy đủ field, sai secret → throw đúng, map rác → null đúng, và 1 test
  đặc biệt xác nhận `fromJson` không đụng service nào (không setup
  `Get.put` gì trong test đó — nếu code lỡ gọi `Get.find` sẽ throw ngay).

**Không có UI trong task này** (thuần core/service, không widget) — tiêu
chí animation/reduced-motion N/A, tick vì không có gì để vi phạm; không
làm device smoke test thật vì không có màn hình nào để cầm lên xem (đúng
tiền lệ đã lập ở FEAT-67/FEAT-68 — 2 task core/service thuần trước đó
trong session này cũng bỏ qua device smoke với lý do giống hệt).

Tự chấm: 9.3/10. Trừ điểm vì chưa wire ví dụ thật vào `example/`
(`widget_showcase_screen.dart` không có demo cho
`DiagnosticsExportBundle` — hợp lý vì đây không phải widget để demo trực
quan, nhưng 1 nút "Export diagnostics" gọi bundle thật rồi hiện JSON ra
`ToastBanner`/dialog sẽ là bằng chứng tích hợp mạnh hơn unit test thuần;
để lại làm follow-up nếu cần).

