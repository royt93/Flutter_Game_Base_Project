---
id: BUG-61
title: "widget_showcase_screen.dart: 4 chỗ thiếu mounted-guard sau await + DeepLinkCommandRouter thiếu unregisterHandler gây leak handler permanent"
type: bug
priority: P0
effort: S
source: "agy + Fork nội bộ (audit example/lib + test coverage) — độc lập xác nhận cùng vùng file, gộp thành 1 task; verify lại qua Read trực tiếp"
---

## Vị trí
`example/lib/screens/widget_showcase_screen.dart` — `_inventoryGrant` (~dòng 642-653), `_inventoryConsume` (~dòng 654-667), 2 chỗ gọi `_deepLinks.handleUri(uri)` trong demo deep-link (~dòng 1434-1465), và `initState()` nơi `_deepLinks.registerHandler('level', (command) => setState(...))` đăng ký handler `permanent: true` không có cách huỷ đăng ký tương ứng trong `dispose()`.

## Hiện trạng
1. 4 chỗ trong file gọi `setState(...)` ngay sau 1 `await` mà KHÔNG có `if (!mounted) return;` guard đứng trước — mọi async handler KHÁC trong cùng file (dòng 94, 259, 327, 668, 1529, 2484, 2568...) đều có guard này, đây là 4 chỗ hiếm hoi bị bỏ sót (đã xác nhận qua Fork nội bộ đọc trực tiếp so sánh pattern).
2. `DeepLinkCommandRouter` không có API `unregisterHandler` — handler đăng ký từ `initState()` của 1 State cụ thể tồn tại vĩnh viễn trong router kể cả sau khi State đó `dispose()`, giữ tham chiếu tới State đã unmounted.

## Vì sao cần / Hậu quả
(1) nếu người dùng rời màn hình đúng lúc 1 trong 4 await đang chạy, `setState()` trên State đã unmount ném exception "setState() called after dispose()". Rủi ro thực tế thấp (cần rời màn hình đúng thời điểm hẹp) nhưng là bug thật, dễ fix, nhất quán với phần còn lại của file. (2) mỗi lần `WidgetShowcaseScreen` được mở rồi đóng lại (ví dụ do navigate qua lại giữa các tab demo) tích luỹ thêm 1 handler mồ côi giữ tham chiếu State cũ — memory leak thật, tăng dần theo số lần mở lại màn hình.

## Đề xuất
1. Thêm `if (!mounted) return;` trước `setState` ở cả 4 vị trí (đúng pattern đã dùng ở các dòng 668/1529/2484 trong cùng file).
2. Thêm `void unregisterHandler(String type)` vào `DeepLinkCommandRouter` (xoá đúng entry theo `type`), gọi nó trong `dispose()` của `_WidgetShowcaseScreenState` cho handler đã đăng ký trong `initState()`.

## Acceptance criteria
- [ ] Cả 4 vị trí (`_inventoryGrant`, `_inventoryConsume`, 2 chỗ deep-link) có `if (!mounted) return;` trước `setState`.
- [ ] `DeepLinkCommandRouter.unregisterHandler(String type)` tồn tại, xoá đúng handler đã đăng ký, không ảnh hưởng handler khác đăng ký cho type khác.
- [ ] `_WidgetShowcaseScreenState.dispose()` gọi `unregisterHandler('level')` (hoặc type tương ứng) dọn dẹp đúng handler đã đăng ký ở `initState`.
- [ ] Mở rồi đóng `WidgetShowcaseScreen` nhiều lần — không tích luỹ handler mồ côi trong `DeepLinkCommandRouter` (verify qua test đếm số handler đăng ký).
- [ ] Test hiện có của `widget_showcase_screen_test.dart` và `deep_link_command_router_test.dart` vẫn pass.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-61-widget-showcase-missing-mounted-guards-and-handler-leak.md` này trước khi làm. Đọc toàn bộ `example/lib/screens/widget_showcase_screen.dart` (đặc biệt các dòng nêu trên và pattern `mounted`-guard đã đúng ở dòng 668/1529/2484 để copy chính xác) và `lib/core/deep_link_command_router.dart` trước khi sửa. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test (`unregisterHandler`) + widget test (`mounted` guard, dispose cleanup) cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Smoke test trên device Android thật khuyến khích (mở/đóng `WidgetShowcaseScreen` nhiều lần, verify không crash/leak quan sát được qua DevTools memory) không bắt buộc nếu widget test dispose-cleanup đã đủ chứng minh.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Rất cao cho phần (1) — Fork nội bộ đã tự đọc trực tiếp source quanh mỗi dòng (context ±5-6 dòng), so sánh với pattern `mounted`-guard lặp lại nhiều lần khác trong cùng file, xác nhận không suy đoán. Cao cho phần (2) — agy xác nhận `DeepLinkCommandRouter` thiếu `unregisterHandler` (đã grep xác nhận API này không tồn tại trong `deep_link_command_router.dart`). Không trùng task nào trong `doc/task/done/`.
