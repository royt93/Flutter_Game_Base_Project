---
id: ENH-53
title: "SettingsScreen dùng Material SwitchListTile thay vì dogfood CandyToggleSwitch/CommonListTile"
type: enhancement
priority: P3
effort: S
source: Gemini (agy CLI, audit enhancement lib/presentation/widgets/)
---

## Vị trí
`example/lib/screens/settings_screen.dart`.

## Hiện trạng
Toggle Sound và Dark Mode dùng `SwitchListTile` (Material chuẩn) thay vì kết hợp `CommonListTile` + `CandyToggleSwitch` (đã có sẵn trong package) — ví dụ demo app không tự "ăn thức ăn của chính mình" (dogfooding) ở đúng màn hình mà người dùng package sẽ nhìn vào để học cách style toggle switch trông thế nào trong 1 màn hình cài đặt thật.

## Vì sao cần / Hậu quả
Người mới dùng package xem `SettingsScreen` làm ví dụ tham khảo sẽ thấy giao diện lai (nửa Material chuẩn, nửa candy-style) thay vì 1 ví dụ nhất quán hoàn toàn theo style kit.

## Đề xuất
Thay `SwitchListTile` bằng `CommonListTile(title: ..., trailing: CandyToggleSwitch(value: ..., onChanged: ...))` cho cả 2 toggle.

## Acceptance criteria
- [ ] SettingsScreen không còn dùng SwitchListTile, thay bằng CommonListTile + CandyToggleSwitch.
- [ ] example/test/settings_screen_test.dart hiện có (toggle mute, toggle dark mode) vẫn pass nguyên vẹn sau khi đổi widget (chỉ đổi presentation, không đổi hành vi/callback).
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-53-example-settings-screen-dogfood-kit-widgets.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Thấp — chỉ là ví dụ demo, không ảnh hưởng package thật, effort rất thấp, priority thấp nhất trong toàn bộ backlog này (P4 — làm khi rảnh).
