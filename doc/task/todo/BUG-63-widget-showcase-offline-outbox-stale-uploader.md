---
id: BUG-63
title: "widget_showcase_screen.dart: OfflineOutboxService demo giữ tham chiếu uploader trỏ về State cũ (permanent + method reference)"
type: bug
priority: P1
effort: S
source: "agy (độc lập) — cần verify lại chính xác trước khi implement"
---

## Vị trí
`example/lib/screens/widget_showcase_screen.dart` — khu vực demo `OfflineOutboxService` (`uploader: _outboxUploader`).

## Hiện trạng
`OfflineOutboxService` đăng ký `permanent: true` với `uploader: _outboxUploader` — `_outboxUploader` là 1 instance method của `_WidgetShowcaseScreenState`. Vì service permanent (không bị GetX huỷ khi màn hình đóng) còn method reference lại đóng kín (closure) tham chiếu instance State ban đầu, service giữ instance State của LẦN MỞ ĐẦU TIÊN mãi mãi.

## Vì sao cần / Hậu quả
Mỗi lần đóng/mở lại `WidgetShowcaseScreen` tạo 1 State instance mới, nhưng service vẫn gọi `uploader` trỏ tới State CŨ (lần mở đầu tiên) — leak bộ nhớ (State cũ không bao giờ được GC vì còn 1 tham chiếu sống từ service permanent), và nếu `_outboxUploader` có truy cập field/`setState` của State, hành vi demo cũng sai (thao tác nhầm lên State đã unmounted).

## Đề xuất
Tách `uploader` thành 1 hàm độc lập không giữ tham chiếu State (top-level function hoặc static method), hoặc không đăng ký `OfflineOutboxService` `permanent: true` cho mục đích demo (dùng instance cục bộ, tự dispose đúng lifecycle của State).

## Acceptance criteria
- [ ] Mở/đóng `WidgetShowcaseScreen` nhiều lần — `OfflineOutboxService` demo không giữ tham chiếu instance State cũ nào (verify qua code review/test cấu trúc, không phụ thuộc vào State cụ thể trong uploader).
- [ ] Demo outbox vẫn hoạt động đúng (enqueue/drain minh hoạ) sau khi sửa.
- [ ] Test hiện có của `widget_showcase_screen_test.dart` vẫn pass.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-63-widget-showcase-offline-outbox-stale-uploader.md` này trước khi làm. Đọc toàn bộ khu vực demo `OfflineOutboxService` trong `example/lib/screens/widget_showcase_screen.dart` — TỰ XÁC NHẬN lại đúng cơ chế trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ widget test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở `example/`.
4. Không cần smoke test device bắt buộc (leak tham chiếu nội bộ, khó quan sát trực tiếp qua device).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — dựa trên mô tả agy, chưa tự Read lại đúng dòng trong file lớn (2500+ dòng). Người thực hiện bắt buộc tự xác nhận lại trước khi sửa; nếu không tái hiện được, đóng task với ghi chú rõ ràng thay vì sửa nhầm chỗ. Không trùng task nào trong `doc/task/done/`.
