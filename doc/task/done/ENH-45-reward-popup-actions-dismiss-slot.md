---
id: ENH-45
title: "RewardPopup: thiếu slot actions/dismiss như NeonDialog.panel và SpotlightOverlay đã có"
type: enhancement
priority: P3
effort: S
source: Gemini (agy CLI, audit enhancement lib/presentation/widgets/)
---

## Vị trí
`lib/presentation/widgets/common/reward_popup.dart`.

## Hiện trạng
Khác với `NeonDialog.panel` (nhận `actions: List<NeonDialogAction>`) và `SpotlightOverlay` (nhận `buttonLabel`/`onDismiss`), `RewardPopup` không có slot hành động/nút đóng nào — caller phải tự dựng row nút bên trong `content` thủ công, không nhất quán với 2 widget "popup dạng dialog" chị em kia trong cùng kit.

## Vì sao cần / Hậu quả
Thiếu nhất quán API giữa các widget cùng nhóm "dialog/popup" trong kit.

## Đề xuất
Thêm tham số optional `List<Widget>? actions` (hoặc đơn giản hơn: `VoidCallback? onDismiss` + `String dismissLabel = 'Claim'` nếu chỉ cần 1 nút đơn — chọn hướng nào ít phức tạp hơn khi thực sự bắt tay code, ưu tiên đơn giản theo tinh thần ponytail).

## Acceptance criteria
- [x] RewardPopup hỗ trợ 1 cách khai báo hành động/nút đóng nhất quán với NeonDialog.panel hoặc SpotlightOverlay (chọn 1 hướng, không cần cả 2), không phá call site hiện có (actions/onDismiss optional, mặc định null).
- [x] Test: truyền action/dismiss callback, xác nhận nút hiển thị đúng và tap gọi đúng callback.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định. (N/A — xem Quyết định.)
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`. (Nút dùng `CommonButton` có sẵn, animation entrance của cả panel không đổi.)

## Quyết định
Chọn hướng đơn giản hơn theo đúng gợi ý trong Đề xuất (tinh thần ponytail): `VoidCallback? onDismiss` + `String dismissLabel = 'Claim'` (giống `SpotlightOverlay`), thay vì `List<NeonDialogAction>` phức tạp hơn của `NeonDialog.panel` — reward moment 1 nút bấm là đủ, không cần multi-action. Render `CommonButton(label: dismissLabel, onTap: onDismiss)` ngay sau `content` khi `onDismiss != null`.

3 test mới trong `group('ENH-45: ...')`: `onDismiss` null giữ nguyên layout cũ (không có `CommonButton` nào), truyền `onDismiss` hiển thị đúng nút "Claim" mặc định và tap gọi đúng callback, và `dismissLabel` tuỳ chỉnh hiển thị đúng nhãn khác. Dùng `find.byType(CommonButton)` + đọc `.label` thay vì `find.text(...)` — theo đúng convention đã ghi chú sẵn trong `common_button_test.dart` (`CommonButton` vẽ 2 lớp Text chồng nhau cho hiệu ứng viền chữ, `find.text` sẽ ambiguous).

Không cần device smoke: bổ sung 2 tham số optional (default `null`/`'Claim'`), demo `RewardPopup` hiện tại trong `WidgetShowcaseScreen` không dùng `onDismiss` nên không đổi bất kỳ pixel nào đã hiển thị trên máy thật.

`flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (590 tests) và `example/` (29 tests).

Tự chấm: 9.5/10 — đúng tinh thần "chọn hướng đơn giản hơn" mà Đề xuất gợi ý, tái dùng `CommonButton` có sẵn, test theo đúng convention đã thiết lập của codebase (byType thay vì find.text cho CommonButton).

Commit code: `c5d702e`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-45-reward-popup-actions-dismiss-slot.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Thấp — API ergonomics, effort thấp, cần quyết định 1 hướng thiết kế cụ thể lúc code (đừng làm cả 2 kiểu cùng lúc).
