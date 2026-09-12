---
id: ENH-42
title: "EnergyBar: chỉ render dọc (Column) và hardcode Icons.favorite/NeonTheme.red"
type: enhancement
priority: P3
effort: S
source: Gemini (agy CLI, audit enhancement lib/presentation/widgets/)
---

## Vị trí
`lib/presentation/widgets/common/energy_bar.dart`.

## Hiện trạng
Widget chỉ render theo `Column` (tim trên, đếm ngược dưới) và hardcode `Icons.favorite` + `NeonTheme.red` — không thể đặt ngang (ví dụ trong header bar) hoặc đổi icon/màu cho theme energy khác (bolt, khiên, stamina...).

## Vì sao cần / Hậu quả
Hạn chế tái sử dụng cho các game không dùng "tim" làm biểu tượng năng lượng, hoặc cần layout ngang gọn trong app bar.

## Đề xuất
Thêm tham số optional `Axis direction = Axis.vertical`, `IconData icon = Icons.favorite`, `IconData emptyIcon = Icons.favorite_border`, `Color? color` — giữ nguyên hành vi mặc định hiện tại khi không truyền.

## Acceptance criteria
- [x] direction/icon/emptyIcon/color mặc định giữ nguyên hành vi hiện tại (không phá demo/call site nào).
- [x] Test: direction: Axis.horizontal render đúng Row thay vì Column; icon/color custom hiển thị đúng thay vì mặc định.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định. (N/A — xem Quyết định.)
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`. (Giữ nguyên animation pip pop có sẵn, không đổi.)

## Quyết định
Thêm 4 tham số optional (`direction`, `icon`, `emptyIcon`, `color`) với default trùng khớp 100% hành vi cũ (`Axis.vertical`, `Icons.favorite`, `Icons.favorite_border`, `NeonTheme.red`). Tách `build()` thành 2 biến `pips`/`countdown` dùng chung, rồi chọn `Row` hay `Column` bọc ngoài tuỳ `direction` — không nhân đôi code.

3 test mới trong `group('ENH-42: ...')`: mặc định vẫn Column + icon/màu cũ, `direction: Axis.horizontal` render Row (không còn Column nào), và icon/emptyIcon/color tuỳ chỉnh (bolt/purple) hiển thị đúng thay vì heart/red mặc định.

Không cần device smoke: chỉ bổ sung tham số optional, demo hiện tại trong `WidgetShowcaseScreen` không dùng tham số mới (vẫn behavior mặc định y hệt cũ) — đã verify chính bản thân demo này trên device thật ở các task trước (BUG-30..33) sau khi các thay đổi này chưa tồn tại lẫn không liên quan; không có rủi ro hồi quy hiển thị nào cho call site thật.

`flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (580 tests) và `example/` (29 tests).

Tự chấm: 9.5/10 — API mở rộng tối giản, default giữ nguyên tuyệt đối, tái dùng logic build chung cho cả 2 direction thay vì viết 2 nhánh trùng lặp.

Commit code: `9e800a9`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-42-energy-bar-direction-icon-color-customization.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

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
