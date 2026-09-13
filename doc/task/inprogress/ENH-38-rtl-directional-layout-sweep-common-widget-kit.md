---
id: ENH-38
title: "Sweep đổi Alignment/Positioned vật lý (left/right) sang directional (start/end) cho RTL"
type: enhancement
priority: P3
effort: L
source: Gemini (agy CLI, audit enhancement lib/presentation/widgets/)
---

## Vị trí
`segmented_tab_bar.dart` (AnimatedAlign dùng -1.0/1.0 vật lý), `progress_bar_stars.dart` (alignment centerLeft/bottomLeft + Positioned left:), `spotlight_overlay.dart` (Align centerRight cho action button), `ribbon_badge.dart` (Positioned right:/top: + góc xoay cố định), `paginated_dots_indicator.dart` (Padding right:), `tooltip_bubble.dart` (nub tính từ physical left), `icon_badge_button.dart` (Positioned right:/top: cho badge), `wheel_spinner.dart` (painter hardcode `TextDirection.ltr`), `currency_counter.dart` (FittedBox alignment centerLeft).

## Hiện trạng
Toàn bộ danh sách trên dùng vị trí VẬT LÝ (left/right cố định) thay vì directional (`AlignmentDirectional`/`PositionedDirectional`/`EdgeInsetsDirectional`) — ở locale RTL (tiếng Ả Rập/Hebrew), các widget này sẽ lệch hướng đọc tự nhiên (ví dụ progress bar tô từ trái trong khi cả layout đã lật sang phải-sang-trái, badge/ribbon nằm nhầm góc, canvas vẽ text sai chiều).

## Vì sao cần / Hậu quả
1 casual game nhắm thị trường Trung Đông (rất phổ biến cho thể loại này) sẽ có UI lệch hướng ở nhiều widget cùng lúc — sửa từng widget riêng lẻ khi phát sinh sẽ chậm và dễ sót so với 1 lần sweep có chủ đích.

## Đề xuất
Đổi từng chỗ dùng `Alignment`/`Positioned`/`EdgeInsets` vật lý (left/right/centerLeft/...) sang bản directional tương ứng (`AlignmentDirectional`/`PositionedDirectional`/`EdgeInsetsDirectional`) trong danh sách file ở trên. Với `WheelSpinnerPainter` (vẽ trực tiếp lên `Canvas`, không có sẵn directional helper), đọc `Directionality.of(context)` ở widget cha và truyền `textDirection` xuống painter thay vì hardcode `TextDirection.ltr`.

## Acceptance criteria
- [ ] Mỗi widget trong danh sách render đúng hướng khi Directionality.of(context) == TextDirection.rtl.
- [ ] Test: bọc mỗi widget đã sửa trong Directionality(textDirection: TextDirection.rtl, child: ...), xác nhận vị trí render (left/right thực tế trên màn hình) đã đảo đúng chiều so với LTR.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-38-rtl-directional-layout-sweep-common-widget-kit.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình (P3) — dự án hiện chỉ có 2 locale seed (en/vi, cả 2 đều LTR, theo `AppTranslations.supported` trong CLAUDE.md), nên giá trị thực tế phụ thuộc việc dự án có kế hoạch hỗ trợ locale RTL (Ả Rập, Hebrew, ...) hay không — effort L vì chạm nhiều file, nên hỏi lại độ ưu tiên trước khi làm nếu chưa có kế hoạch RTL cụ thể.
