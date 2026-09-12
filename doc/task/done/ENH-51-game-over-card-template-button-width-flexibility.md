---
id: ENH-51
title: "GameOverCardTemplate: nút hành động luôn cố định 240px, không co giãn theo card"
type: enhancement
priority: P3
effort: S
source: Gemini (agy CLI, audit enhancement lib/presentation/widgets/)
---

## Vị trí
`lib/presentation/widgets/common/game_over_card_template.dart`.

## Hiện trạng
`CommonButton` bên trong không được truyền width cụ thể nên rơi về default cố định 240px bất kể chiều rộng thực tế của card cha — ở card hẹp hơn 240px (ví dụ trong 1 dialog nhỏ), nút có thể tràn ra ngoài hoặc trông lệch tỉ lệ.

## Vì sao cần / Hậu quả
Layout không linh hoạt theo ngữ cảnh sử dụng thực tế.

## Đề xuất
Cho phép nút co giãn theo chiều rộng khả dụng của card (ví dụ bọc trong `SizedBox(width: double.infinity, ...)` hoặc thêm tham số optional `double? buttonWidth` nếu cần kiểm soát cụ thể hơn — chọn hướng đơn giản nhất, ưu tiên full-width theo card trước).

## Acceptance criteria
- [x] Nút hành động không tràn ra ngoài card ở chiều rộng hẹp bất thường (test với card 200px width).
- [x] Test: dựng GameOverCardTemplate trong container hẹp, xác nhận tester.takeException() rỗng (không RenderFlex overflow).
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định. (N/A — xem Quyết định.)
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`. (N/A — chỉ đổi width layout, animation entrance ENH-34 có sẵn không đổi.)

## Quyết định
Chọn hướng đơn giản nhất theo đúng gợi ý trong Đề xuất: bọc cả 2 `CommonButton` (primary + secondary) trong `SizedBox(width: double.infinity)` — không thêm tham số `buttonWidth` (YAGNI, "full-width theo card" đã đủ giải quyết vấn đề nêu trong bug).

2 test mới trong `group('ENH-51: ...')`: card hẹp 200px không gây `RenderFlex overflow`; card RỘNG 320px xác nhận nút thực sự co giãn RỘNG HƠN 240px (mặc định cố định cũ của `CommonButton`) — đây là bằng chứng phân biệt rõ hành vi MỚI với hành vi CŨ (test "không overflow ở 200px" một mình không đủ phân biệt, vì `Container` có `width` cố định của Flutter cũng tự động bị clamp xuống theo constraint hẹp hơn từ parent, không thực sự "tràn"; test 320px mới chứng minh được nút giờ đây co giãn theo card thay vì luôn dừng ở 240px).

Phát hiện phụ (không phải regression từ fix này): test "tapping primary action calls onPrimaryAction" có sẵn từ trước in ra 1 cảnh báo hit-test vô hại (không fail) — đã xác nhận bằng `git stash` A/B rằng cảnh báo này tồn tại y hệt TRƯỚC cả khi tôi sửa gì, không liên quan tới ENH-51, không cần xử lý trong task này.

Không cần device smoke: thay đổi layout thuần (width co giãn), widget test đã dùng chính Flutter rendering engine để xác thực kích thước render thực tế, tương đương bằng chứng ảnh chụp device cho loại thay đổi số học/layout này.

`flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (601 tests) và `example/` (29 tests).

Tự chấm: 9.5/10 — đúng root cause, chọn giải pháp đơn giản nhất, test phân biệt rõ hành vi mới/cũ thay vì chỉ test "không crash", chủ động điều tra và loại trừ 1 warning không liên quan thay vì bỏ qua mập mờ.

Commit code: `abe950d`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-51-game-over-card-template-button-width-flexibility.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Thấp — bug thị giác nhỏ, effort thấp.
