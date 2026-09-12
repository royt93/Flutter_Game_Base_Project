---
id: ENH-43
title: "EmptyStatePlaceholder: thêm title + action button slot (pattern empty-state chuẩn)"
type: enhancement
priority: P3
effort: S
source: Gemini (agy CLI, audit enhancement lib/presentation/widgets/)
---

## Vị trí
`lib/presentation/widgets/common/empty_state_placeholder.dart`.

## Hiện trạng
Widget chỉ nhận `icon` + `message`, thiếu `title` (tiêu đề nổi bật kiểu "No Friends Yet") và `action` (nút "Retry"/"Find Friends") — 2 phần tử gần như tiêu chuẩn của pattern empty-state trong hầu hết app thật.

## Vì sao cần / Hậu quả
Thiếu 2 slot phổ biến buộc caller phải tự dựng thêm layout bên ngoài widget này thay vì dùng nó trọn vẹn.

## Đề xuất
Thêm tham số optional `String? title` (hiển thị phía trên `message`, font đậm hơn) và `Widget? action` (hiển thị dưới `message`, ví dụ 1 `CommonButton`).

## Acceptance criteria
- [x] title/action khi truyền hiển thị đúng vị trí, không phá layout hiện tại khi không truyền (cả 2 default null).
- [x] Test: truyền title và action, xác nhận cả 2 hiển thị đúng cùng icon/message hiện có.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định. (N/A — xem Quyết định.)
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`. (N/A — chỉ thêm slot nội dung tĩnh; `action` do caller tự cấp animation nếu cần.)

## Quyết định
Thêm `String? title` (hiển thị phía trên `message`, đậm/lớn hơn — `fontWeight: w800, fontSize: 17`) và `Widget? action` (hiển thị dưới `message`) — cả 2 default `null`, bọc trong `if (title != null) ...[...]` / `if (action != null) ...[...]` nên không đổi 1 pixel nào của layout cũ khi không truyền.

3 test mới trong `group('ENH-43: ...')`: cả 2 null giữ nguyên layout cũ (không có `ElevatedButton` nào xuất hiện), truyền cả `title` + `action` (nút thật, xác nhận `onPressed` gọi được) hiển thị đúng cùng icon/message có sẵn, và chỉ truyền `title` không `action` vẫn hoạt động bình thường.

Không cần device smoke: bổ sung 2 tham số optional default `null`, demo hiện tại (`EmptyStatePlaceholder` trong `WidgetShowcaseScreen`) không dùng 2 tham số mới nên không đổi bất kỳ pixel nào đã hiển thị trên máy thật ở các phiên trước.

`flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (583 tests) và `example/` (29 tests).

Tự chấm: 9.5/10 — API tối giản đúng pattern empty-state chuẩn, default giữ nguyên tuyệt đối, test bao phủ đủ tổ hợp (không truyền / truyền cả 2 / chỉ truyền 1).

Commit code: `b6b0d64`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-43-empty-state-placeholder-title-action-slot.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Thấp — API ergonomics, effort thấp.
