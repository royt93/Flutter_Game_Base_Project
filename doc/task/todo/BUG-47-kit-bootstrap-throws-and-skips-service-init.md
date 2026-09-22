---
id: BUG-47
title: "RoyCasualKit.initialize ném ArgumentError vi phạm cam kết never-throws; không gọi init() của AudioManager/WakeLockService"
type: bug
priority: P1
effort: S
source: "agy (độc lập), verify lại qua Read lib/core/kit_bootstrap.dart:80-95"
---

## Vị trí
`lib/core/kit_bootstrap.dart` — `_initialize()` (~dòng 80-95).

## Hiện trạng
```dart
if (requested.contains(RoyCasualKitModule.locale) &&
    !requested.contains(RoyCasualKitModule.storage) &&
    !Get.isRegistered<StorageService>()) {
  throw ArgumentError('locale module cần storage module');
}
```
CLAUDE.md và doc comment của `initialize` cam kết rõ ràng: "never throws: a module whose registration throws is recorded in ... errors ... rather than crashing boot". Nhưng validate ràng buộc giữa module `locale`/`storage` lại `throw` trực tiếp thay vì đi qua cùng cơ chế `errors`/`degraded` như mọi lỗi module khác. Ngoài ra, `AudioManager`/`WakeLockService` được `Get.put()` nhưng method `init()` (async, đọc lại state đã lưu) không được gọi tự động trong luồng bootstrap — phải trông chờ code khác gọi.

## Vì sao cần / Hậu quả
1 consumer app request `modules: {locale}` mà quên thêm `storage` (dễ xảy ra vì nhiều dev không đọc kỹ ràng buộc ngầm này) sẽ bị app CRASH ngay tại bootstrap thay vì nhận `RoyCasualKitResult.degraded` như tài liệu hứa hẹn — đúng loại lỗi mà cơ chế `errors`/`degraded` được thiết kế ra để tránh. Thiếu gọi `init()` khiến `AudioManager`/`WakeLockService` khởi động với state mặc định thay vì state đã lưu (mute/wake-lock setting bị reset về default mỗi lần app khởi động lại) cho tới khi có code khác gọi `init()` thủ công.

## Đề xuất
Thay `throw ArgumentError(...)` bằng cách thêm entry vào `errors` map và tiếp tục xử lý các module khác (đúng contract never-throws hiện có cho mọi lỗi module khác). Gọi `await AudioManager` instance`.init()`/`WakeLockService` instance`.init()` ngay sau `Get.put()` trong nhánh bootstrap tương ứng, bọc trong cùng try/catch ghi vào `errors` nếu thất bại (giống cách các module khác đã làm).

## Acceptance criteria
- [ ] Gọi `initialize(config: RoyCasualKitConfig(modules: {locale}))` (thiếu `storage`) không throw — trả về `RoyCasualKitResult` với `status == degraded` và `errors` chứa entry mô tả rõ thiếu `storage`.
- [ ] Sau `initialize` với module `audio`/`wakeLock`, `AudioManager.to.muted.value`/`WakeLockService.to.enabled.value` phản ánh đúng giá trị đã lưu trước đó trong storage (không phải default), không cần gọi thêm `init()` thủ công.
- [ ] Mọi test hiện có của `kit_bootstrap_test.dart` vẫn pass.
- [ ] `resetForTesting()` vẫn dọn dẹp đúng các service này.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-47-kit-bootstrap-throws-and-skips-service-init.md` này trước khi làm. Đọc toàn bộ `lib/core/kit_bootstrap.dart` (đặc biệt cơ chế `errors`/`degraded` cho các module khác) và `test/core/kit_bootstrap_test.dart` trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/` (bootstrap được `example/lib/main.dart` gọi trực tiếp).
4. Smoke test trên device Android thật khuyến khích (verify `example` app boot vẫn đúng mute/wake-lock state đã lưu từ lần trước) nếu tiện, không bắt buộc vì đây là fix tại tầng bootstrap logic, không đổi UI quan sát trực tiếp ngoài giá trị mute/wakelock ban đầu.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — tự Read trực tiếp `kit_bootstrap.dart`, xác nhận `throw ArgumentError` tồn tại đúng, mâu thuẫn trực tiếp với doc comment "never throws" của chính file. Chưa tự verify sâu phần "AudioManager/WakeLockService.init() không được gọi" bằng cách đọc toàn bộ nhánh bootstrap của 2 module đó (effort S, để lại xác nhận chi tiết cho vòng loop implement). Không trùng task nào trong `doc/task/done/`.
