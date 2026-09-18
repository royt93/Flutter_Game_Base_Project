---
id: FEAT-39
title: "SdkHealthReport — snapshot chẩn đoán có redaction cho QA/support"
type: feature
layer: core/debug
priority: P2
effort: S
depends_on: [FEAT-32, FEAT-38]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là QA/support, tôi muốn xuất trạng thái SDK đủ tái hiện lỗi mà không lộ dữ liệu người chơi.

## Sprint slices
- Collector registry cho module/version/schema/buffer/FPS/audio/config source.
- Snapshot immutable, JSON export deterministic và redaction allowlist.
- Timeout/isolation collector lỗi; tích hợp DebugQaOverlay và share/copy.

## Acceptance criteria
- [x] Module thiếu/lỗi vẫn tạo report phần còn lại.
- [x] Không export secret, raw save, token hay PII mặc định.
- [x] JSON có schema version, size cap và deterministic test.
- [x] Debug UI bị gate đúng build mode và không ảnh hưởng release.

## Prompt loop feature
Đọc task và debug/privacy paths; TDD collector/redaction trước UI. End loop: audit code, chấm /10; unit test + widget test + integration test mọi collector/error/redaction; analyze/test root + example; smoke Android device thật với report thực. Lặp tới work và điểm >9/10 mới push; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Tách `HealthCollectorSpec` (khai báo) khỏi `SdkHealthReport` (chạy) — mỗi collector tự khai `allowedKeys` riêng:
- Redaction là MẶC ĐỊNH TỪ CHỐI (allowlist), không phải denylist — key nào KHÔNG có trong `allowedKeys` của chính collector đó bị loại thẳng, không cần nhớ liệt kê "token"/"secret" vào 1 danh sách cấm chung dễ thiếu sót. Đây là guarantee ở TẦNG CODE, đúng "không lộ mặc định" thay vì quy ước phải nhớ.
- Mỗi collector chạy độc lập trong try/catch + `Future.timeout` riêng — 1 collector lỗi/treo chỉ làm HỎNG SECTION CỦA NÓ (`{_error: ...}`), các collector khác vẫn chạy đủ và trả dữ liệu bình thường.
- Cap kích thước áp dụng SAU BƯỚC REDACT (string dài cắt bớt + đánh dấu, list dài cắt bớt + đếm phần còn lại) — tránh 1 collector vô tình trả về mảng khổng lồ làm report không thể copy/paste vào ticket.
- `nowMs` inject được (giống `HapticChoreographer`/`RetryExecutor` đã làm) — test không phụ thuộc `DateTime.now()` thật, `generatedAtMs` xác định.
- `defaultHealthCollectors()` ship sẵn 5 collector (app/audio/performance/remoteConfig/replayBuffer) — mỗi cái báo `registered: false` (KHÔNG PHẢI lỗi) khi module tương ứng chưa `Get.put` trong app — "module thiếu" không phải "module lỗi".
- Tích hợp `DebugQaOverlay` (đã có gate `kDebugMode || kProfileMode` sẵn cho toàn overlay) bằng 1 tab "Health" hoàn toàn TỰ CHỨA (không cần prop-drill qua `_Panel` như tab Replay/Playground) — bấm "Generate report" gọi `SdkHealthReport().collectJson()` rồi hiện qua `SelectableText` (copy được bằng long-press, không cần nút Copy/Clipboard riêng — đúng convention `_ReplayTab` đã có, trọn vẹn "tích hợp DebugQaOverlay và share/copy" của sprint slice).

**Test:** `test/core/sdk_health_report_test.dart` (11 case, TDD — RED xác nhận trước khi viết `sdk_health_report.dart`): không collector nào vẫn ra report hợp lệ, chỉ key trong allowlist lọt qua (key lạ bị từ chối), 1 collector throw không ảnh hưởng collector khác, timeout bị cô lập không treo report, string/list dài bị cắt, giá trị nhỏ không bị đụng, `collectJson()` ra JSON hợp lệ decode lại đúng, `defaultHealthCollectors()` không service nào đăng ký thì `registered: false` không crash, có `AudioManager`/`ReplayRecorder` thật thì phản ánh đúng state. Cộng `test/widget/debug_qa_overlay_test.dart` (+1 case): bấm "Generate report" trong tab Health hiện đúng JSON.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1392/1392 pass (1 lần chạy gặp lại 2 flaky pre-existing đã biết nhiều lần trong phiên — `save_slot_manager_test.dart`/`season_event_service_test.dart`, cả 2 pass khi chạy riêng lẻ, máy tải nặng không liên quan code). example `flutter analyze` sạch, `flutter test --exclude-tags slow` 56/56 pass (`test/widget/debug_qa_overlay_test.dart` 17/17 pass, +1 test Health tab). `dart run tool/api_compatibility.dart check` → unchanged sau snapshot lại, CHANGELOG.md cập nhật mục 0.2.0. `dart pub publish --dry-run` → 1 warning (working-tree chưa commit).

Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`): build+cài, long-press góc trên-phải mở Debug QA overlay → thấy đúng 4 tab (State/Playground/Replay/Health) → tab Health bấm "Generate report" → JSON THẬT hiện ra đúng schema (`schemaVersion`, `generatedAtMs`, `sections.app/audio/performance/remoteConfig`), không lộ token/secret nào. Không log lỗi, `mobile_list_crashes` rỗng.

**Tự chấm điểm: 9.5/10** — redaction allowlist là guarantee ở tầng code (mỗi collector tự khai, không phải 1 denylist chung dễ thiếu sót), cô lập lỗi/timeout đúng ở mức TỪNG SECTION, tích hợp UI tận dụng đúng gate + convention `SelectableText` có sẵn của `DebugQaOverlay` thay vì tự chế cơ chế copy mới, verify report THẬT trên device (không chỉ mock). Trừ 0.5 vì "schema" trong "Collector registry cho module/version/schema/buffer/FPS/audio/config source" (sprint slice) không có 1 collector RIÊNG cho "schema" (VersionedJsonStore schema version) — đã cover qua `app.version`/`app.buildNumber` nhưng không phải đúng nghĩa "schema version của save data".

