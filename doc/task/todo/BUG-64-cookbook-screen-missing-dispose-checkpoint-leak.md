---
id: BUG-64
title: "CookbookScreen thiếu dispose() làm rò rỉ closure/participant đăng ký trong CheckpointCoordinator"
type: bug
priority: P1
effort: S
source: "agy (độc lập) — cần verify lại chính xác trước khi implement"
---

## Vị trí
`example/lib/screens/cookbook_screen.dart` — `_CookbookScreenState` (~dòng 95-99, nơi đăng ký participant/closure vào `CheckpointCoordinator`).

## Hiện trạng
`_CookbookScreenState` đăng ký 1 participant/closure vào `CheckpointCoordinator` (demo cho tính năng checkpoint) trong `initState()` nhưng không có `dispose()` tương ứng gỡ đăng ký.

## Vì sao cần / Hậu quả
Mỗi lần mở/đóng `CookbookScreen`, `CheckpointCoordinator` tích luỹ thêm 1 participant/closure trỏ tới State cũ đã unmounted — leak bộ nhớ, và mỗi lần checkpoint chạy thật (`requestCheckpoint`), coordinator gọi cả các closure mồ côi này (lãng phí, tiềm ẩn lỗi nếu closure truy cập State đã dispose).

## Đề xuất
Thêm `dispose()` gỡ đăng ký participant/closure đã thêm trong `initState()` (cần `CheckpointCoordinator` có API unregister nếu chưa có — kiểm tra trước khi implement).

## Acceptance criteria
- [ ] `_CookbookScreenState.dispose()` gỡ đúng participant đã đăng ký trong `initState()`.
- [ ] Mở/đóng `CookbookScreen` nhiều lần không tích luỹ participant mồ côi trong `CheckpointCoordinator` (verify qua test đếm số participant đăng ký).
- [ ] Demo checkpoint trong `CookbookScreen` vẫn hoạt động đúng khi màn hình đang mở.
- [ ] Test hiện có của `cookbook_screen_test.dart` (và các file test liên quan) vẫn pass.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-64-cookbook-screen-missing-dispose-checkpoint-leak.md` này trước khi làm. Đọc toàn bộ `example/lib/screens/cookbook_screen.dart` và `lib/core/checkpoint_coordinator.dart` (API đăng ký/gỡ participant hiện có) trước khi sửa — nếu `CheckpointCoordinator` chưa có API unregister phù hợp, cân nhắc thêm API đó như 1 phần của task này (hoặc phối hợp với BUG-42 nếu làm cùng đợt). Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test + unit test (nếu thêm API vào `CheckpointCoordinator`) cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Không cần smoke test device bắt buộc (leak tham chiếu nội bộ, khó quan sát trực tiếp qua device).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — dựa trên mô tả agy, chưa tự Read lại đúng dòng để xác nhận `CheckpointCoordinator` có/không có API unregister phù hợp. Người thực hiện bắt buộc tự xác nhận trước khi sửa. Không trùng task nào trong `doc/task/done/`.
