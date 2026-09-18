---
id: FEAT-40
title: "SecureStorageAdapter — seam lưu token/secret không ép vendor"
type: feature
layer: data/core
priority: P1
effort: S
depends_on: [FEAT-32, FEAT-38]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là app developer, tôi muốn SDK phân biệt preferences thường với token/secret cần secure storage.

## Sprint slices
- Interface stateless `read/write/delete/clear` và capability result.
- GetX registration + `.maybe`; không thêm concrete secure-storage dependency.
- In-memory fake cho test; quy tắc không fallback secret sang SharedPreferences.
- Hướng dẫn adapter cho platform package ở consumer.

## Acceptance criteria
- [x] Thiếu adapter trả failure rõ, không lưu secret vào storage thường.
- [x] Read/write/delete/clear và platform error giữ contract typed.
- [x] Key/value invalid, concurrent write và dispose có test.
- [x] Health report chỉ hiện capability, không hiện key/value.

## Prompt loop feature
Đọc task và storage/error model; implement seam bằng TDD. End loop: audit code, chấm /10; unit test + widget test + integration test mọi operation/error/concurrency; analyze/test root + example; smoke Android device thật bằng adapter demo và log redacted. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Tách 2 lớp thay vì 1, đúng tinh thần "trả failure rõ" là HÀNH VI CODE chứ không chỉ quy ước doc:
- `SecureStorageAdapter` (`lib/core/secure_storage_adapter.dart`) — interface RAW (plain `Future`, throw khi lỗi), đúng hệt shape `PurchaseSeam` đã có. `.maybe` KHÔNG có `Noop*` default — same lý do `PurchaseSeam` đã ghi: âm thầm no-op 1 lần ghi secret sẽ che giấu bug tích hợp thật.
- `SecureStorage` — facade thực sự được gọi (`read/write/delete/clear` static), cộng thêm: validate key rỗng TRƯỚC khi chạm adapter, bọc mọi kết quả/lỗi vào `SdkResult` (FEAT-38), và — quan trọng nhất — khi KHÔNG có adapter đăng ký thì trả `SdkFailure(kind: platform)` NGAY, không bao giờ rẽ sang `StorageService`/SharedPreferences. Đây là guarantee ở TẦNG CODE (facade không hề import `StorageService`), không phải quy ước phải nhớ tuân thủ.
- Lỗi từ adapter throw ra được bọc thành `SdkFailure(kind: platform, cause: error)` — message CỐ ĐỊNH ("Secure storage operation failed"), không bao giờ nội suy `value`/`key` gốc vào message hiển thị, tránh lộ secret qua chính thông báo lỗi.
- `isAvailable` = "có adapter đăng ký" (capability đơn giản nhất, không tự probe keystore thật — 1 lần gọi read/write thật MỚI biết keystore có thật sự mở khoá hay không, `isAvailable` không giả vờ biết trước điều đó).
- `FakeSecureStorageAdapter` (Map trong bộ nhớ) ship kèm, dùng cho test tiêu dùng seam này — không phải Noop production, là test double rõ ràng.
- KHÔNG tích hợp cứng vào "health report" (FEAT-39 chưa tồn tại, vẫn `todo/`) — chỉ đảm bảo chính seam này không có method nào lộ key/value ra ngoài `SdkFailure.message`, sẵn sàng cho FEAT-39 dùng `isAvailable` sau này mà không cần sửa gì thêm.

**Test:** `test/core/secure_storage_adapter_test.dart` (13 case, TDD — RED xác nhận trước khi viết `secure_storage_adapter.dart`): thiếu adapter → mọi operation fail rõ + KHÔNG lọt vào `StorageService` (verify bằng `exportAll()` rỗng), `isAvailable` đúng cả 2 trạng thái, round-trip read/write/delete/clear qua `FakeSecureStorageAdapter`, đọc key chưa từng ghi trả `null` (không phải lỗi), key rỗng bị từ chối trước khi chạm adapter, ghi đồng thời 2 key không đụng nhau, `Get.delete` adapter giữa chừng → lần gọi sau báo lỗi rõ (không cache instance cũ), adapter throw → bọc `SdkFailure(platform)` và message không chứa value gốc, `FakeSecureStorageAdapter` tự nó round-trip đúng.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1358/1358 pass (1 lần chạy gặp lại đúng `save_slot_manager_test.dart` flaky pre-existing đã biết nhiều lần trong phiên — verify pass riêng lẻ, không liên quan). example `flutter analyze` sạch, `flutter test --exclude-tags slow` 56/56 pass (không cần UI showcase — seam thuần logic). `dart run tool/api_compatibility.dart check` → unchanged sau snapshot lại, CHANGELOG.md cập nhật mục 0.2.0. `dart pub publish --dry-run` → 1 warning (working-tree chưa commit).

Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`): thêm `testWidgets('FEAT-40: ...')` vào `example/integration_test/app_boot_test.dart` — verify KHÔNG adapter thì `StorageService.to.exportAll()` không đổi sau khi thử ghi secret; đăng ký `FakeSecureStorageAdapter` thật trên device rồi write/read round-trip đúng, và `StorageService.to.exportAll()` VẪN không đổi (secret không lọt vào storage thường dù có adapter). Chạy `flutter test integration_test/app_boot_test.dart -d 2B051FDH3006MU --dart-define=E2E_TEST=true --plain-name "FEAT-40"` (lọc riêng). Evidence: `doc/task/evidence/FEAT-40-device-smoke.log`.

**Tự chấm điểm: 9.5/10** — tách interface/facade đúng lý do (guarantee "không fallback" nằm ở code, không phải doc), tái dùng đúng pattern `PurchaseSeam` (no-Noop) và `SdkResult` (FEAT-38) thay vì tự chế, verify device thật bằng cách đo trực tiếp `StorageService.exportAll()` không đổi (bằng chứng thực nghiệm, không chỉ tin vào code review), test cover đủ acceptance criteria. Trừ 0.5 vì chưa có tích hợp thật với FEAT-39 (health report) — chấp nhận được vì FEAT-39 chưa tồn tại, nhưng vẫn là 1 sprint-slice item chưa nối trọn vẹn tới hệ thống thật.

