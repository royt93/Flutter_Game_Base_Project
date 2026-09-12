---
id: IDEA-28
title: "CandyTextField — ô nhập text theo style candy của kit, hiện chưa tồn tại"
type: idea
priority: exclusive
effort: S
source: Claude (claude --dangerously-skip-permissions, agent độc lập, brainstorm new/killer feature)
---

## Vị trí
Mới — sẽ nằm cạnh `lib/presentation/widgets/common/common_button.dart`, `toggle_switch.dart` (category "Buttons & Interactive").

## Hiện trạng
Category "Buttons & Interactive" (`CommonButton`, `CandyToggleSwitch`, `SegmentedTabBar`, `IconBadgeButton`, `SoundToggleFab`) hoàn toàn không có widget nhập text nào. Bất kỳ game nào cần ô nhập tên người chơi, mã redeem, hoặc form feedback đều phải rơi về `TextField` Material trần — lệch hẳn phong cách bo tròn/glow/drop-shadow của toàn bộ phần còn lại trong kit.

## Vì sao cần / Hậu quả
1 ô nhập liệu trông lạc lõng giữa 1 UI candy-style nhất quán làm giảm giá trị "xịn sò đồng bộ" mà cả kit đang xây dựng.

## Đề xuất
`CandyTextField` — `StatelessWidget` bọc `TextField`/`TextFormField`, style theo `NeonTheme.card` nền, `NeonTheme.drop`/`glow` khi focus, viền bo tròn. Caller tự sở hữu `TextEditingController` (đúng convention "caller owns state" đã dùng cho `WheelSpinnerController`/`ScreenShakeController"). Nhận optional `prefixIcon`/`validator`/`obscureText`/`keyboardType`.

## Acceptance criteria
- [ ] CandyTextField render đúng style kit (nền/viền/glow khi focus) qua NeonTheme tokens, không hardcode màu.
- [ ] Hỗ trợ prefixIcon, validator, obscureText, keyboardType như TextFormField chuẩn.
- [ ] Có demo trong widget_showcase_screen.dart (category Buttons & Interactive).
- [ ] Test: nhập text cập nhật đúng controller, validator hiện đúng lỗi, obscureText ẩn ký tự đúng, focus/blur đổi border/glow đúng.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-28-candy-text-field.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — gap rõ ràng, dễ verify (không có widget nhập liệu nào trong kit), effort thấp vì chỉ là 1 lớp style mỏng trên TextField chuẩn, không cần logic mới.
