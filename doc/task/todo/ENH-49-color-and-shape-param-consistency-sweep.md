---
id: ENH-49
title: "Thêm tham số màu/hình dạng còn thiếu cho nhất quán với các widget cùng nhóm đã có"
type: enhancement
priority: P3
effort: M
source: Gemini (agy CLI, audit enhancement lib/presentation/widgets/)
---

## Vị trí
`segmented_tab_bar.dart` (thiếu `activeColor`, khác `CandyToggleSwitch`/`CommonButton`/`IconBadgeButton` đã có màu tuỳ biến), `shimmer_placeholder.dart` (thiếu `shape: BoxShape`, `baseColor`, `highlightColor`), `loading_overlay.dart` (spinner hardcode `NeonTheme.magenta`/`NeonTheme.purple`, thiếu `color`/`backgroundColor`), `network_status_banner.dart` (hardcode `NeonTheme.red`, thiếu `color`).

## Hiện trạng
4 widget trên thiếu tham số màu/hình dạng tuỳ biến mà các widget TƯƠNG TỰ khác trong cùng category của kit ĐÃ có — 1 điểm thiếu nhất quán API dễ nhận ra khi so sánh các widget cùng nhóm cạnh nhau.

## Vì sao cần / Hậu quả
Nhất quán API giúp người dùng package đoán đúng constructor mà không cần tra doc mỗi lần — thiếu nhất quán hiện tại buộc họ phải nhớ 'widget nào có màu tuỳ biến, widget nào không' thay vì áp dụng 1 quy tắc chung.

## Đề xuất
Thêm từng tham số optional tương ứng cho mỗi widget (`Color? activeColor` cho `SegmentedTabBar`; `BoxShape shape = BoxShape.rectangle, Color? baseColor, Color? highlightColor` cho `ShimmerPlaceholder`; `Color? color, Color? backgroundColor` cho `LoadingOverlay`; `Color? color` cho `NetworkStatusBanner`), giữ nguyên default hiện tại khi không truyền.

## Acceptance criteria
- [ ] Mỗi tham số mới khi truyền áp dụng đúng vào widget tương ứng, mặc định giữ nguyên màu/hình dạng hiện tại.
- [ ] Test: mỗi widget với tham số custom xác nhận màu/shape render đúng giá trị truyền vào (không phải default).
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-49-color-and-shape-param-consistency-sweep.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Thấp — API consistency, effort trung bình vì chạm 4 file khác nhau nhưng mỗi thay đổi rất nhỏ và độc lập.
