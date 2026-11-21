---
id: BUG-138
title: "OfflineOutboxService: không báo enqueue/resolve thành công trước persist"
type: bug
layer: lib/core/offline_outbox_service
priority: P1
effort: M
source: "Full source audit 2026-11-21; persistence failures are hidden by fire-and-forget writes"
---

## Bằng chứng

`enqueue()` và `resolveManual()` đổi state trong memory, gọi `unawaited(_persist())`, rồi trả `SdkSuccess`; lỗi storage không đến được caller. Caller có thể tin item đã bền vững trong khi restart làm mất thay đổi. Chưa có test cho persist failure ở các thao tác này.

- `lib/core/offline_outbox_service.dart:351-416,558-579`
- `test/core/offline_outbox_service_test.dart:389-510` kiểm tra persistence thành công/restart.

## Phạm vi

Giữ contract “Crash safety” đã tài liệu hóa và làm cho caller biết kết quả durable. Xác định tương thích API trước khi code: có thể đổi API sang async typed result, hoặc thêm operation/flush barrier rõ ràng; không chọn âm thầm. Bao gồm rollback state trong memory khi ghi thất bại nếu contract yêu cầu thao tác không thành công là no-op. Không làm persistence queue generic.

## Acceptance criteria

- [x] Lỗi persist từ durable enqueue/resolve không bị nuốt; caller không nhận durable success khi storage write fail. Sync methods được ghi rõ là best-effort.
- [x] Durable failure rollback khôi phục replaced/evicted/manual state khi revision không đổi; interleaving mutation được giữ nguyên.
- [x] Kiểm thử success, storage failure, restart, durable queue ordering, auto-drain gate và call sites trong example.
- [x] Các example handlers await durable methods; caller sync API hiện hữu không bị silently đổi signature.
- [x] Unit tests pass; widget tests pass qua example suite; device integration recovery test dùng enqueueDurably; không thêm test platform riêng vì persistence semantics được kiểm qua real SharedPreferences API.
- [x] API compatibility + CHANGELOG + snapshot cập nhật; analyzer sạch.
- [x] Audit diff, chấm >9/10 theo rubric correctness 4, tests 2, contract/API 2, maintainability 1, device evidence 1; ghi tradeoff.
- [x] Physical-device smoke luồng durable enqueue/restore trong example, ghi model/OS/build/commit/log. Không simulator.

## Prompt loop

Đọc task, API docs, toàn bộ `OfflineOutboxService`, `StorageService` serialization semantics, call sites và tests trước. So sánh cách các service lân cận báo persistence failure. Nếu còn nhiều lựa chọn API có ảnh hưởng consumer, dừng và hỏi owner. Viết failure-injection tests trước, rồi sửa tối thiểu để durable result/error và state rollback đúng. Cập nhật docs/callers/tests cần thiết; chạy unit, widget/integration phù hợp, analyze và smoke trên thiết bị thật. Audit code changes và chấm /10 với rubric trong acceptance; lặp cho tới >9/10 và mọi gate đạt. Dừng nếu chưa rõ API decision, test đỏ, thiết bị không sẵn, hoặc điểm <=9; ghi blocker, không push. Khi mọi gates đạt và điểm >9/10, ghi kết quả/điểm rồi push code theo yêu cầu owner.

## Kết quả thực hiện

- API decision: thêm `enqueueDurably`/`resolveManualDurably`; giữ hai API sync là best-effort. Durable write failure trả `SdkFailure(storage)`; rollback snapshot chỉ khi không có mutation xen vào. Sync mutation xen giữa được giữ nguyên; durable result failure không khẳng định item đó vắng khỏi memory/storage nếu mutation mới đã bao gồm nó.
- Audit / điểm: **9.2/10** — correctness 4/4, tests 2/2, contract/API 2/2, maintainability 0.7/1 (write-tail/revision coordination thêm trạng thái nhưng giữ phạm vi service-local), device evidence 0.5/1 (test thật trên device kiểm đường persist/reconnect/ack; failure injection và interleave được kiểm bằng unit tests). API additive.
- Unit/widget/integration: `flutter test test/core/offline_outbox_service_test.dart` pass (48/48); root non-golden `flutter test --exclude-tags slow test/core test/widget/common test/presentation test/tool` pass (4,083/4,083); example suite `flutter test --exclude-tags slow` pass (451/451); `flutter analyze` sạch; API compatibility unchanged sau snapshot; `git diff --check` pass.
- Device smoke: TECNO KJ7, Android 14, package `com.galaxyjoy.roycasualkit`; `cd example && flutter test integration_test/offline_outbox_recovery_test.dart -d 115333744A005844 --dart-define=E2E_TEST=true` pass. Durable enqueue lưu trước reconnect; online transition upload đúng một lần; ack ghi `[]`; recreate service không còn item. Không có ad SDK/request.
- Commit/push: chưa commit/push; chờ xác nhận riêng.
- Rủi ro còn lại: nếu durable write báo lỗi nhưng có mutation sync xen vào, giữ state hiện thời để tránh mất dữ liệu; do đó item của durable call thất bại có thể vẫn nằm trong snapshot được mutation mới lưu. Sync APIs vẫn best-effort và không báo lỗi storage xảy ra sau khi trả về. `StorageService(null)` chỉ lưu RAM, không phải disk durability.
