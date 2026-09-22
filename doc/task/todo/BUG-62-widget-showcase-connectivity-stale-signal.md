---
id: BUG-62
title: "widget_showcase_screen.dart: ConnectivityCoordinator demo giữ tham chiếu cũ khi mở lại màn hình nhiều lần"
type: bug
priority: P1
effort: S
source: "agy (độc lập) — cần verify lại số dòng chính xác trước khi implement"
---

## Vị trí
`example/lib/screens/widget_showcase_screen.dart` — khu vực demo `ConnectivityCoordinator`.

## Hiện trạng
`ConnectivityCoordinator` được đăng ký `permanent: true` với 1 `probe` callback tham chiếu tới instance `_WidgetShowcaseScreenState` hiện tại. Khi màn hình bị đóng rồi mở lại (State instance MỚI được tạo), coordinator (permanent, không bị GetX huỷ) vẫn giữ callback trỏ tới State CŨ đã unmounted.

## Vì sao cần / Hậu quả
Sau khi mở lại màn hình nhiều lần, các probe callback cũ (trỏ instance State đã dispose) có thể vẫn được gọi ngầm bởi coordinator permanent — không crash ngay (do closures Dart không tự động throw khi state đã dispose trừ khi truy cập `setState`), nhưng là leak tham chiếu State cũ, và nếu closure có gọi `setState`, sẽ gây lỗi "setState() called after dispose()" tương tự các bug mounted-guard khác trong cùng file.

## Đề xuất
Không đăng ký `permanent: true` cho coordinator demo giả lập chỉ dùng trong 1 màn hình showcase (dùng `Get.put(..., permanent: false)` hoặc tự quản lý instance cục bộ trong State, dispose đúng trong `dispose()`), hoặc cập nhật lại callback mỗi lần `initState()` chạy để luôn trỏ đúng instance State hiện tại.

## Acceptance criteria
- [ ] Mở/đóng `WidgetShowcaseScreen` nhiều lần — probe callback của `ConnectivityCoordinator` demo luôn trỏ đúng instance State hiện tại, không giữ tham chiếu State cũ đã dispose.
- [ ] Demo `ConnectivityCoordinator` vẫn hoạt động đúng (hiển thị đúng trạng thái mạng) sau khi sửa.
- [ ] Test hiện có của `widget_showcase_screen_test.dart` vẫn pass.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-62-widget-showcase-connectivity-stale-signal.md` này trước khi làm. Đọc toàn bộ khu vực demo `ConnectivityCoordinator` trong `example/lib/screens/widget_showcase_screen.dart` — TỰ XÁC NHẬN lại đúng số dòng/cơ chế trước khi sửa (nguồn phát hiện chưa tự verify số dòng chính xác). Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở `example/`.
4. Không cần smoke test device bắt buộc (leak tham chiếu nội bộ, khó quan sát trực tiếp qua device trừ khi dùng DevTools memory profiler).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — dựa trên mô tả agy, CHƯA tự Read lại đúng số dòng/đoạn code trong `widget_showcase_screen.dart` (file rất lớn, hơn 2500 dòng) do khối lượng batch verify lớn của đợt audit này. Người thực hiện BẮT BUỘC tự đọc lại chính xác trước khi sửa (đã ghi rõ trong Prompt) — nếu không xác nhận được vấn đề như mô tả, ghi rõ lý do và có thể đóng task này là "không tái hiện được" thay vì cố sửa 1 vấn đề không tồn tại. Không trùng task nào trong `doc/task/done/`.
