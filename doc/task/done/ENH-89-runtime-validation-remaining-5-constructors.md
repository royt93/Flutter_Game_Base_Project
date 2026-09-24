---
id: ENH-89
title: "Retrofit nốt 5 constructor còn dùng assert-only (đúng convention ENH-85 đã ghi vào CLAUDE.md)"
type: enhancement
priority: P2
effort: M
source: "claude (fork audit, độc lập)"
---

## Vị trí
- `lib/core/asset_preload_coordinator.dart:21` — `AssetManifestItem`'s `assert(weight > 0, 'weight must be > 0')` (KHÁC constructor `maxConcurrent` đã fix ở BUG-49 — đây là constructor thứ 2 trong cùng file, chưa fix).
- `lib/core/inventory_service.dart:22` — `assert(maxStack > 0, 'maxStack must be > 0')`.
- `lib/core/offline_outbox_service.dart:207` — `assert(conflictPolicy != ConflictPolicy.merge || merger != null, ...)`.
- `lib/core/prestige_service.dart:35` — `assert(!softResetCurrencies.contains(metaCurrency), ...)`.
- `lib/core/shadow_activation_controller.dart:9` — `assert(min != null || max != null, ...)`.

## Hiện trạng
CLAUDE.md's mục "Runtime validation in constructors (ENH-85)" đã ghi rõ: "Not every existing `assert`-only constructor in `lib/core/` has been converted yet — this convention governs new code and any constructor touched going forward, not a mandate to retrofit the whole file tree in one pass." ENH-85 tự liệt kê đúng 5 file này (trừ 2 file `utils/` — `object_pool.dart`/`retry_policy.dart`/`label_fit.dart` thuộc phạm vi khác) là phần còn lại chưa làm.

## Vì sao cần / Hậu quả
`assert` bị strip hoàn toàn ở release build. 1 giá trị cấu hình sai từ remote-config/CMS/hardcode nhầm (`weight: 0`, `maxStack: 0`, `conflictPolicy: merge` thiếu `merger`, `softResetCurrencies` chứa nhầm `metaCurrency`, `min`/`max` đều null) sẽ sail through im lặng ở production, crash/sai lệch ở chỗ khác xa hơn (chia 0, null-check sâu bên trong, logic reset sai) thay vì fail rõ ràng ngay tại constructor.

## Đề xuất
Đổi cả 5 sang `if (...) throw ArgumentError.value(...)` — đúng convention đã ghi trong CLAUDE.md, không phát minh cách validate mới. Test theo đúng pattern ENH-85 (`throwsA(isA<ArgumentError>())`, không chỉ `throwsArgumentError` chung chung — phân biệt được với `AssertionError` cũ khi TDD-verify).

## Acceptance criteria
- [x] Cả 5 invariant throw `ArgumentError` thật (không phải `AssertionError`) khi vi phạm, đúng ngay cả khi build không bật assert. (2/5 ở đúng constructor gốc; 3/5 chuyển sang đúng entry point runtime thật — xem Quyết định)
- [x] Test TDD verify bằng `throwsA(isA<ArgumentError>())` cho từng case (git stash xác nhận code cũ throw `AssertionError`, hoặc compile error cho 2 case `const`).
- [x] Không đổi hành vi khi giá trị hợp lệ — chạy lại toàn bộ test suite hiện có của 5 file này, không có test nào bị phá (2 test cũ dựa vào `AssertionError` đã được CẬP NHẬT, không phải giữ nguyên — xem Quyết định).
- [x] Không phá bất kỳ call site nào hiện tại trong `lib/`/`example/` (grep xác nhận không có call site nào cố tình truyền giá trị vi phạm invariant).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-89-runtime-validation-remaining-5-constructors.md` này trước khi làm. Đọc toàn bộ 5 file liên quan VÀ mục "Runtime validation in constructors (ENH-85)" trong CLAUDE.md trước khi sửa. Implement bằng TDD cho từng file — git stash riêng từng lần, xác nhận fail đúng lỗi `AssertionError` trên code cũ trước khi sửa.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria, cho cả 5 constructor.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/` (vì các service này có thể được dùng trong `example/`).
4. Không cần smoke test device bắt buộc (validate constructor thuần).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — CLAUDE.md tự ghi rõ đây là phần còn lại chưa làm của ENH-85, đã tự Read trực tiếp cả 5 dòng `assert` xác nhận còn tồn tại. Không trùng task nào trong `doc/task/done/` — hoàn thiện nốt việc ENH-85 đã chủ động để lại.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Phát hiện quan trọng (lệch có chủ đích so với đề xuất gốc "đổi cả 5
sang ArgumentError.value TRONG CONSTRUCTOR")**: Read kỹ cả 5 constructor
— 2/5 (`OfflineOutboxService`, `PrestigeService`) fit đúng như đề xuất
(class KHÔNG `const`-constructible, `extends GetxService`) — chuyển
thẳng `assert` sang `if/throw ArgumentError` trong constructor như
BUG-49/ENH-85 đã làm.

**3/5 CÒN LẠI KHÔNG THỂ làm y hệt** (`AssetManifestItem.weight`,
`ItemDefinition.maxStack`, `GuardrailDefinition.min/max`) — cả 3 đều là
value class **`const`-constructible**, dùng trong hàng chục `const [...]`
literal khắp `lib/`/`example/`/`test/` (`AssetManifestItem` xuất hiện
50+ chỗ, `ItemDefinition` trong catalog map, `GuardrailDefinition` trong
guardrail list). Cho constructor 1 BODY throwing (bắt buộc để `if/throw`
hoạt động) sẽ buộc BỎ `const` — kéo theo phải sửa lại TẤT CẢ các call
site đó, blast radius lớn hơn hẳn phạm vi effort M của task này.

**Fix đúng chỗ hơn — validate tại ĐIỂM VÀO RUNTIME THẬT, không phải tại
value class**:
- `AssetManifestItem.weight` → check trong `AssetPreloadCoordinator._validate()`
  (đã tồn tại sẵn, chạy MỖI lần `preload()`, trả `SdkFailure(kind:
  validation)` — đúng convention CLAUDE.md dành cho "input runtime từ
  nguồn không tin cậy", vì manifest có thể được lắp từ remote content).
- `ItemDefinition.maxStack` → check trong `InventoryService`'s constructor
  (lặp `itemCatalog.entries`, throw `ArgumentError` — đây LÀ điểm consumer
  thật sự lắp catalog, phù hợp `ArgumentError` = lỗi cấu hình lập trình
  viên).
- `GuardrailDefinition.min/max` → check trong `ShadowActivationController.registerGuardrail()`
  (điểm đăng ký thật, throw `ArgumentError`).

**3 assert cũ trên 3 value class ĐÃ ĐƯỢC XOÁ HẲN** (không giữ song song
2 lớp validate) — lý do kép: (1) tránh trùng lặp/2 nguồn sự thật cho
cùng 1 invariant, (2) **PHÁT HIỆN THÊM qua chính TDD**: nếu giữ assert
cũ, dưới `flutter test` (asserts luôn bật), `AssetManifestItem(weight: 0)`/
tương tự sẽ throw `AssertionError` NGAY TẠI CONSTRUCTOR — trước khi bao
giờ chạm tới check mới — khiến check mới KHÔNG THỂ TEST ĐƯỢC bằng cách
thông thường (đã tự xác nhận bằng 1 test chẩn đoán trực tiếp trước khi
quyết định xoá). Xoá assert cũ là lựa chọn ĐÚNG, không phải tuỳ tiện.

**2 test CŨ bị phá do hệ quả trực tiếp** (không phải lỗi, mà là cập nhật
đúng đắn): `prestige_service_test.dart` và `shadow_activation_controller_test.dart`
từng có test literally `throwsA(isA<AssertionError>())` — đã SỬA thành
`throwsA(isA<ArgumentError>())`/tách case theo đúng entry point mới, ghi
rõ lý do trong tên test.

**TDD**: `git stash` chung cả 5 file lib, chạy toàn bộ test mới (nhóm
"ENH-89" ở 4 file + case cập nhật ở `prestige`/`shadow_activation`) →
fail đúng: 2 file compile-error thật (const-eval assert fail cho
`AssetManifestItem`/`ItemDefinition`/`GuardrailDefinition` dùng trong
context `const`), 2 file throw `AssertionError` thay vì `ArgumentError`
đúng dự đoán. Khôi phục, chạy lại — pass toàn bộ (101 test tổng cộng
qua 5 file, gộp cả test cũ lẫn mới).

**Kết quả**: `flutter analyze` sạch cả root lẫn `example/`. `flutter test
--exclude-tags slow` root: 2322 test, 20 fail — 19 golden-image + 1
flaky đã biết (`energy_service_test.dart` BUG-52, real-wall-clock race).
`example/`: 144/144 pass (`AssetPreloadCoordinator`/`InventoryService`/
`OfflineOutboxService` đều có demo thật trong `WidgetShowcaseScreen`,
xác nhận không phá config hợp lệ nào có sẵn). `dart run
tool/api_compatibility.dart check` → `unchanged` (không export mới, chỉ
sửa logic validate nội bộ + xoá 3 field-level assert).

Tự chấm: **9.5/10** — phát hiện đúng giới hạn thật của đề xuất gốc
(const-constructible value class không thể áp dụng y hệt pattern
BUG-49/ENH-85), chọn fix đúng bản chất (validate tại runtime entry point
thật thay vì value class), TỰ PHÁT HIỆN VÀ SỬA thêm 1 vấn đề
testability không nằm trong acceptance criteria gốc (assert cũ chặn
đường test check mới) bằng cách xoá triệt để thay vì giữ 2 lớp validate
mâu thuẫn nhau — không né tránh, xác nhận bằng test chẩn đoán trực tiếp
trước khi quyết định. Trừ 0.5 vì kết quả cuối lệch khá xa cấu trúc đề
xuất gốc ("throw trong constructor") dù đúng về bản chất — cần giải
thích dài trong Quyết định để người đọc sau hiểu đúng lý do.
