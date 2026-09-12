---
id: ENH-48
title: "TutorialSequence: thiếu chỉ số bước (1/3) và nút Skip trong UI overlay"
type: enhancement
priority: P3
effort: M
source: Gemini (agy CLI, audit enhancement lib/presentation/widgets/)
---

## Vị trí
`lib/presentation/widgets/common/tutorial_sequence.dart`.

## Hiện trạng
`TutorialSequenceController` đã có `skip()` và theo dõi step index, nhưng UI overlay của `TutorialSequence` không hiển thị tiến độ ("Bước 1/3") hay nút Skip nào — người chơi không biết còn bao nhiêu bước nữa và không có cách chủ động thoát tutorial giữa chừng qua UI (dù logic `skip()` đã tồn tại sẵn, chỉ thiếu nút gọi nó).

## Vì sao cần / Hậu quả
Trải nghiệm tutorial mù mờ (không biết còn dài bao lâu) và không thể bỏ qua chủ động — cả 2 đều là pattern UX tiêu chuẩn cho onboarding nhiều bước.

## Đề xuất
Thêm hiển thị "Bước {index+1}/{total}" trong callout overlay (dùng lại `SpotlightOverlay`'s cấu trúc `_Callout` nếu `TutorialSequence` build trên nó — kiểm tra code thật trước khi quyết định cách tích hợp), và optional `bool showSkip = true` forward `controller.skip` vào 1 nút nhỏ trong overlay.

## Acceptance criteria
- [ ] Overlay hiển thị đúng "Bước X/Y" theo step index/total hiện tại của controller.
- [ ] showSkip: true hiển thị nút Skip gọi đúng controller.skip(); showSkip: false ẩn nút này.
- [ ] Test: xác nhận text step indicator đúng ở từng bước, và tap Skip kết thúc đúng tutorial sequence (controller báo done/dismissed).
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-48-tutorial-sequence-step-indicator-skip-button.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — cải thiện UX onboarding thật, effort M vì cần đọc kỹ cấu trúc hiện tại của `TutorialSequence`/`SpotlightOverlay` trước khi thêm UI mới cho đúng chỗ.
