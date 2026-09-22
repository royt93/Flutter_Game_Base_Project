---
id: IDEA-64
title: "Hiển thị RoyCasualKitResult (module nào lỗi/degraded) trong 1 tab DebugQaOverlay thay vì chỉ đọc log"
type: idea
priority: low
effort: S
source: "claude (độc lập)"
---

## Vị trí
Mở rộng `lib/presentation/widgets/debug_qa_overlay.dart`, dựa trên `lib/core/kit_bootstrap.dart` (`RoyCasualKitResult.errors`/`status`).

## Hiện trạng
`RoyCasualKitResult.errors`/`status` là API công khai nhưng không đâu trong kit hiển thị nó ra UI (kể cả debug tool) — chỉ có thể đọc qua log/debugger thủ công.

## Vì sao cần / Hậu quả
1 tab liệt kê module nào đăng ký thành công/lỗi giúp cả SDK dev lẫn consumer debug boot nhanh hơn nhiều so với đọc log — đặc biệt hữu ích khi kết hợp với BUG-47 (kit_bootstrap giờ trả `degraded` thay vì throw cho 1 số lỗi cấu hình).

## Đề xuất
Thêm 1 tab "Boot" trong `DebugQaOverlay` hiển thị `status` (`healthy`/`degraded`) và danh sách `errors` (module + message) từ lần `initialize()` gần nhất — cần lưu lại `RoyCasualKitResult` ở đâu đó truy cập được (ví dụ static field hoặc GetX service nhỏ) vì `initialize()` chỉ trả về 1 lần tại thời điểm gọi.

## Acceptance criteria
- [ ] Tab "Boot" hiển thị đúng `status`/`errors` của lần `initialize()` gần nhất.
- [ ] Không có lỗi nào (status healthy) hiển thị rõ ràng "OK, mọi module đăng ký thành công".
- [ ] Test widget verify tab hiển thị đúng khi có/không có lỗi.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-64-surface-boot-result-in-debug-qa-overlay.md` này trước khi làm. Đọc toàn bộ `lib/core/kit_bootstrap.dart` (`RoyCasualKitResult`) và `lib/presentation/widgets/debug_qa_overlay.dart` trước khi thêm tab. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Không cần smoke test device bắt buộc (widget test đủ chứng minh).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình-cao — API `RoyCasualKitResult` xác nhận tồn tại thật (dùng trong BUG-47), gap UI hợp lý. Không trùng task nào trong `doc/task/done/`.
