---
id: BUG-40
title: "_hydrate() chỉ chạy trong onInit() — service mất trắng state khi khởi tạo trực tiếp ngoài Get.put"
type: bug
priority: P0
effort: S
source: "agy (độc lập), verify lại qua Read constructor + onInit() của cả 3 file"
---

## Vị trí
- `lib/core/player_progression_service.dart` (constructor dòng 159, `onInit`/`_hydrate` dòng 206-210)
- `lib/core/reward_transaction_pipeline.dart` (constructor dòng 134, `onInit`/`_hydrate` dòng 177-180)
- `lib/core/offline_outbox_service.dart` (constructor dòng 196, `onInit`/`_hydrate` dòng 236-238)

## Hiện trạng
Cả 3 constructor đã đọc trực tiếp KHÔNG gọi `_hydrate()` — chỉ `onInit()` (hook GetX, chỉ chạy khi service được `Get.put()`/`Get.lazyPut()`) mới gọi. Khi 1 trong 3 class này được khởi tạo trực tiếp (`FooService(...)` không qua `Get.put`, đúng như cách `player_progression_service_test.dart:147` tự làm, hoặc như 1 test/widget cục bộ khác), `onInit()` không hề chạy — `_records`/`_totalXpEarned`/state nội bộ khởi động RỖNG dù storage đã có dữ liệu cũ.

## Vì sao cần / Hậu quả
Gọi `grant()`/`grantXp()`/`enqueue()` trên 1 instance như vậy sẽ `_persist()` state rỗng (hoặc chỉ có bản ghi mới) ĐÈ LÊN dữ liệu cũ trên storage — xóa sạch lịch sử giao dịch/level/outbox pending của người chơi mà không có cảnh báo gì. Đây là lớp lỗi nghiêm trọng nhất trong toàn bộ audit (mất dữ liệu thật, không phải lý thuyết) vì code hiện tại của chính repo (`player_progression_service_test.dart:147`) đã chứng minh pattern "khởi tạo trực tiếp ngoài GetX" là hợp lệ/được dùng thật.

## Đề xuất
Gọi `_hydrate()` ngay trong constructor (giống `EconomyWallet` — service anh em cùng pattern ledger đã làm đúng), thay vì đợi `onInit()`. Nếu `_hydrate()` cần async, đổi sang lazy-hydrate-on-first-access (hydrate 1 lần trước lần đọc/ghi đầu tiên) thay vì phụ thuộc lifecycle hook GetX.

## Acceptance criteria
- [x] Khởi tạo cả 3 service trực tiếp (không `Get.put`) rồi gọi `grant`/`grantXp`/`enqueue` ngay — state cũ trên storage (seed trước) phải được load đúng, không bị ghi đè/mất.
- [x] Hành vi khi khởi tạo QUA `Get.put()` (đường cũ) không đổi — không test nào hiện có bị phá.
- [x] Test cho cả 3 file: seed storage trước, khởi tạo trực tiếp, verify state hydrate đúng trước khi gọi bất kỳ mutation nào.
- [x] Không đổi public API signature của cả 3 class (consumer code hiện tại không cần sửa).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-40-hydrate-skipped-when-constructed-outside-getx.md` này trước khi làm. Đọc toàn bộ `lib/core/player_progression_service.dart`, `lib/core/reward_transaction_pipeline.dart`, `lib/core/offline_outbox_service.dart`, `lib/core/economy_wallet.dart` (tham khảo pattern hydrate-trong-constructor đúng), và test hiện có của cả 3 file trước khi sửa. Implement bằng TDD (viết test fail trước — seed storage rồi khởi tạo trực tiếp phải hydrate đúng — rồi code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria, cho cả 3 file.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (fix nội bộ ở tầng service, hành vi qua Get.put — đường dùng thật trong app — không đổi).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — tự đọc trực tiếp cả 3 constructor, xác nhận không constructor nào gọi `_hydrate()`, chỉ `onInit()` gọi. Đây là bug thật, nghiêm trọng, không suy đoán. Không trùng task nào trong `doc/task/done/`.

## Quyết định

Fix đúng như đề xuất — gọi `_hydrate()` ngay trong constructor thay vì đợi `onInit()`. Một điều chỉnh so với đề xuất gốc: câu "giống `EconomyWallet` đã làm đúng" trong mục Đề xuất **sai** — đọc trực tiếp `lib/core/economy_wallet.dart` xác nhận `EconomyWallet` cũng CHỈ gọi `_hydrate()` trong `onInit()`, y hệt bug của 3 file kia (test riêng của nó chỉ chưa từng thử pattern "seed rồi khởi tạo trực tiếp không `onInit()`" nên chưa lộ ra). `InventoryService` cũng có cùng bug.

Do đó fix mở rộng ra **5 file** (không chỉ 3), cùng 1 kiểu sửa tối thiểu (gọi `_hydrate()` — và `_recompute()` với 2 file có bước này — ngay trong thân constructor, `onInit()` vẫn gọi lại được vì idempotent):
- `lib/core/player_progression_service.dart`
- `lib/core/reward_transaction_pipeline.dart`
- `lib/core/offline_outbox_service.dart`
- `lib/core/economy_wallet.dart` (bug giống hệt, phát hiện thêm trong lúc làm)
- `lib/core/inventory_service.dart` (bug giống hệt, phát hiện thêm trong lúc làm)

`OfflineOutboxService.onInit()` có thêm bước đăng ký connectivity-subscription (side effect gắn với GetX lifecycle) — bước đó CHỈ giữ trong `onInit()`, không đưa vào constructor, chỉ `_hydrate()` mới cần chạy sớm.

**Test:** thêm 2 test/file (seed rồi khởi tạo trực tiếp hydrate đúng; mutate ngay sau khởi tạo trực tiếp không mất data cũ) — 10 test mới, tổng 101 test trong 5 file liên quan, tất cả pass.

**Kiểm tra không phá gì:** `flutter analyze` root sạch. `flutter test --exclude-tags slow` root: 2017 pass / 19 fail — 19 fail đều là golden-image test (`test/widget/goldens/*`), xác nhận **có sẵn từ trước, không liên quan** bằng cách `git stash` code của task này rồi chạy lại đúng test đó trên `main` sạch — vẫn fail y hệt (gap Flutter/Skia version cục bộ, đã biết trong `CLAUDE.md`/memory, không phải do fix này).

Không cần smoke test device — đúng như task tự ghi rõ trong Prompt (fix nội bộ tầng service, đường dùng thật qua `Get.put` không đổi hành vi).

**Tự chấm điểm: 9.5/10.** Trừ 0.5 vì mở rộng scope thêm 2 file ngoài phạm vi ghi trong task gốc (dù cùng 1 bug, cùng 1 fix, đã giải thích rõ lý do ở trên).
