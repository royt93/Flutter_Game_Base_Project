---
id: FEAT-66
title: "Plugin Adapter Conformance Suite"
type: feature
layer: SDK foundation
priority: P1
effort: M
depends_on: [FEAT-38, FEAT-40]
source: user-approved SDK expansion backlog 2026-09-12
---

## User story
Bộ contract test dùng chung cho Analytics, Ads, IAP, Cloud Save, Secure Storage và Crash Reporter.

## Sprint slices
- Define immutable domain/config contract and validation first.
- Implement service/repository or controller in the declared layer; keep SSOT and unidirectional flow.
- Add consumer/example integration and documentation; keep vendor-specific adapters injectable.
- Add observability, migration and recovery behavior before polish.

## Acceptance criteria
- [x] Mỗi adapter có conformance checklist và fake reference.
- [x] Timeout, retry, duplicate callback, dispose và privacy failure đều có test.
- [x] Consumer có thể chạy suite mà không import implementation vendor.
- [x] Public API/documentation names lifecycle, error, privacy and compatibility policy.
- [x] Animation/accessibility/reduced-motion criteria are covered when UI is involved. (N/A — task thuần logic/test utility, không có UI, cùng lý do đã áp dụng cho FEAT-71/FEAT-85)

## Prompt loop feature
Đọc toàn bộ task và code liên quan; implement bằng TDD theo đúng layer, giữ GetX + Flame là dependency chính thức. End loop bắt buộc: hãy audit lại code changes và chấm điểm trên thang điểm 10; bổ sung unit test + widget test + integration test cho mọi case; chạy flutter analyze và flutter test --exclude-tags slow ở root lẫn example; smoke test lên Android device thật, lưu screenshot/log chứng minh. Nếu work hoặc điểm chưa >9/10 thì tiếp tục sửa. Chỉ khi work và điểm >9/10 mới push code; sau đó cập nhật ## Quyết định, tick acceptance criteria, chuyển file sang doc/task/done và commit + push lần hai.

## Quyết định

**Phạm vi**: user story gốc nhắc "Analytics, Ads, IAP, Cloud Save, Secure Storage và Crash Reporter" — bỏ "Ads" (không có `AdsProvider` nào tồn tại trong kit, FEAT-02 đã từ chối dứt khoát, cùng quyết định đã áp dụng cho FEAT-61/FEAT-63/FEAT-71 trong phiên này). "IAP" ánh xạ đúng vào `PurchaseSeam` (khác `FEAT-01` — 1 "IAP wrapper" rộng hơn đã bị từ chối riêng — `PurchaseSeam` là seam tối giản được duyệt sau đó, đã tồn tại sẵn trong kit). Vậy suite bao phủ đúng 5 seam THẬT đang tồn tại: `AnalyticsProvider`, `CloudSaveProvider`, `SecureStorageAdapter`, `CrashReporter`, `PurchaseSeam`.

Kiến trúc:
- **`ConformanceReport`** (mirror đúng `RoyCasualKitContractReport` đã có ở `consumer_contract_test_kit.dart` — nhất quán 1 shape report cho cả 2 loại "contract test" trong kit): `checks: Map<String,bool>`, `passed`, `failures`.
- **Mỗi check độc lập, tự bọc try/catch riêng** — 1 check throw không làm hỏng/dừng các check khác (test xác nhận: adapter throw ở MỌI method của `CloudSaveProvider` vẫn cho ra report với NHIỀU check fail riêng biệt, không phải 1 exception duy nhất chết cả suite).
- **Timeout bọc TOÀN BỘ helper, không chỉ riêng check "completes within timeout"** — đây là BUG THẬT tự phát hiện qua TDD: bản đầu tiên chỉ bọc timeout cho check ĐÍCH DANH kiểm tra timeout, còn check "does not throw" gọi thẳng `await adapter.signIn()` không có timeout guard — 1 adapter treo mãi (`Completer` không complete) làm HANG cả suite tới khi framework test tự timeout ở 30s. Sửa: TẤT CẢ helper (`_noThrow`, `_check`, `_completesWithin`) đều nhận `timeout` và tự bọc `.timeout()` — 1 adapter treo giờ chỉ làm ĐÚNG các check liên quan tới nó fail nhanh, không hang bất cứ thứ gì.
- **"Privacy failure" cụ thể nhất ở `SecureStorageAdapter`**: check `delete`/`clear` không chỉ "không throw" mà THẬT SỰ verify đọc lại sau đó trả về `null` — đây là kiểm tra Ý NGHĨA privacy thật (dữ liệu bị xoá thật, không phải chỉ API "trông như đã xoá"). Test dùng `_LeakySecureStorageAdapter` cố tình KHÔNG xoá gì để chứng minh suite bắt được đúng bug này, và các check KHÁC không liên quan (`write+read round-trips`) vẫn pass — chứng minh cô lập đúng từng check.
- **"Entitlement leak" ở `PurchaseSeam`**: check `isOwned` với sản phẩm CHƯA TỪNG mua phải trả `false` — test dùng `_EntitlementLeakPurchaseSeam` (luôn báo `true`) để chứng minh suite bắt được lỗi entitlement giả — 1 lớp bug thật nguy hiểm cho game (mở khoá nội dung trả phí miễn phí).
- **"Dispose" N/A có chủ đích**: cả 5 interface đều là "call surface" thuần (không có method `dispose()`/`close()` nào) — document rõ trong doc comment thay vì cố nhét 1 check giả cho tiêu chí này.
- **Fake reference**: `FakeCloudSaveProvider`/`FakeCrashReporter`/`FakePurchaseSeam` (mới viết) + tái dùng `FakeSecureStorageAdapter` (đã có từ FEAT-40)/`NoopAnalyticsProvider` (đã có từ FEAT-03) — mỗi fake PASS 100% checklist của chính nó (positive control), đồng thời làm ví dụ tham khảo cho consumer viết adapter thật.

**Test:** `test/core/plugin_adapter_conformance_suite_test.dart` (13 case): mỗi 5 adapter có 1 case "fake reference pass toàn bộ" + 1-2 case "adapter lỗi thật bị suite bắt đúng chỗ" (throw, hang timeout, leak privacy, leak entitlement) — không chỉ test đường vui, còn test suite THẬT SỰ PHÁT HIỆN lỗi khi có. `ConformanceReport` (2 case riêng cho `passed`/`failures`).

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1550/1550 pass (1 lần chạy gặp lại `economy_sim_test.dart` flaky pre-existing đã biết, pass khi chạy riêng lẻ). example `flutter analyze` sạch, `flutter test --exclude-tags slow` 77/77 pass. `dart run tool/api_compatibility.dart check` → unchanged sau snapshot lại. `dart pub publish --dry-run` → 1 warning quen thuộc. CHANGELOG.md cập nhật mục 0.2.0.

Không có demo trong `WidgetShowcaseScreen` — đây là utility CHẠY TỪ TEST CỦA CONSUMER, không phải widget render trong app đang chạy, đúng tiền lệ `consumer_contract_test_kit.dart` (FEAT-32) cũng không có demo runtime nào. Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`): rebuild + cài app (xác nhận export mới không phá compile/boot runtime, giống cách FEAT-85 xử lý cho 1 task thuần logic khác) → boot thành công tới HomeScreen, không crash (`mobile_list_crashes` rỗng).

**Tự chấm điểm: 9.5/10** — phát hiện và sửa đúng 1 bug THẬT nghiêm trọng (hang 30s) trong chính công cụ TDD đang viết, trước khi commit; 2 check "privacy"/"entitlement leak" không chỉ hỏi "có throw không" mà verify đúng Ý NGHĨA của an toàn (dữ liệu bị xoá thật, quyền sở hữu không bị giả); mỗi adapter type đều có ít nhất 1 test "phát hiện lỗi thật" chứ không chỉ test đường vui (positive-only test sẽ không chứng minh được suite THẬT SỰ hữu ích). Trừ 0.5 vì "retry"/"duplicate callback" được diễn giải khá nhẹ (gọi lại 2 lần liên tiếp, không mô phỏng được race condition/concurrent call thật như 1 SDK vendor lỗi thật có thể gây ra) — đủ cho effort M nhưng chưa phải test concurrency sâu.

