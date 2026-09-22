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
- [x] Mở/đóng `WidgetShowcaseScreen` nhiều lần — `OfflineOutboxService` demo không giữ tham chiếu instance State cũ nào (verify qua code review/test cấu trúc, không phụ thuộc vào State cụ thể trong uploader).
- [x] Demo outbox vẫn hoạt động đúng (enqueue/drain minh hoạ) sau khi sửa.
- [x] Test hiện có của `widget_showcase_screen_test.dart` vẫn pass.

## Quyết định
Chọn nhánh 2 của đề xuất (không phải nhánh 1 "tách uploader thành top-level function"): không đăng ký `permanent` theo kiểu tái sử dụng qua `.maybe`, luôn tạo instance MỚI mỗi `initState()`, dispose đúng trong `dispose()` — CÙNG pattern vừa áp dụng cho `ConnectivityCoordinator` ở BUG-62 (2 bug này nằm sát nhau trong cùng khối `initState()`, cùng root cause).

Phát hiện thêm khi verify: hậu quả thực tế NGHIÊM TRỌNG HƠN mô tả gốc — không chỉ leak tham chiếu lý thuyết. `OfflineOutboxService.onInit()` subscribe `connectivity.stateStream` để auto-drain khi online. Sau khi BUG-62 fix áp dụng (coordinator cũ bị dispose thật khi đóng screen), 1 `OfflineOutboxService` bị tái sử dụng qua `.maybe` ở BUG-63 sẽ giữ subscription tới coordinator ĐÃ ĐÓNG STREAM — nghĩa là sau đúng 1 lần mở lại screen, outbox demo VĨNH VIỄN không còn tự động drain khi bật lại kết nối mạng nữa (bug hành vi quan sát được thật, không chỉ leak bộ nhớ). Thứ tự dispose quan trọng: xoá `OfflineOutboxService` TRƯỚC `ConnectivityCoordinator` (outbox là consumer, coordinator là producer nó lắng nghe).

**TDD verify**: test "mở lại screen" dùng lại đúng kỹ thuật tree-swap của BUG-62 (`pumpWidget(SizedBox())` ở giữa để buộc dispose thật). Kịch bản: mở lại, enqueue 1 item (offline mặc định), KHÔNG bấm "Drain now" thủ công, chỉ bật "Interface up" (demo Connectivity của LẦN MỞ MỚI) — chỉ auto-drain đúng nếu outbox mới thật sự lắng nghe coordinator mới. `git stash` riêng `example/lib/screens/widget_showcase_screen.dart`, chạy test — FAIL đúng trên code cũ (`Pending: 1` mãi không về 0 — outbox cũ lắng nghe coordinator cũ đã đóng, không nhận được sự kiện online). `git stash pop`, chạy lại toàn group `FEAT-67` — 4/4 pass.

Kết quả cuối: `example/` `flutter analyze` sạch + `flutter test --exclude-tags slow` 131/131 pass. Root `flutter analyze` sạch, `dart run tool/api_compatibility.dart check` unchanged (không đổi `lib/`). Không smoke test device thật (task ghi không bắt buộc).

Tự chấm: **9.5/10** — root cause đúng, phát hiện + fix thêm hậu quả nghiêm trọng hơn mô tả gốc (auto-drain vĩnh viễn ngừng hoạt động, không chỉ leak), TDD chứng minh đúng bằng kịch bản auto-drain (mạnh hơn manual-drain vì phân biệt rõ code cũ/mới), không phá test cũ.

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
