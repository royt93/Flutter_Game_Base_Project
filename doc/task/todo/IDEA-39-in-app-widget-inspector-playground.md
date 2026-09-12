---
id: IDEA-39
title: "[Killer] In-app widget-kit inspector/playground — mở rộng DebugQaOverlay thành live gallery chỉnh tham số"
type: idea
priority: exclusive (độ tin cậy trung bình — xem ghi chú)
effort: L
source: Claude (claude --dangerously-skip-permissions, agent độc lập, brainstorm new/killer feature)
---

## Vị trí
Mở rộng — `lib/presentation/widgets/debug_qa_overlay.dart`, `example/lib/screens/widget_showcase_screen.dart`.

## Hiện trạng
`DebugQaOverlay` đã chứng minh đúng hạ tầng cần thiết — 1 panel gated bởi `kDebugMode||kProfileMode`, kích hoạt bằng long-press, tree-shake hoàn toàn khỏi release build — nhưng hiện chỉ dump state read-only của `StorageService`/`AudioManager`/`LocaleService`. Trong khi đó `widget_showcase_screen.dart` (hơn 1200 dòng) là 1 demo cố định, hardcode từng widget trong `common/`, không có cách nào chỉnh tham số constructor ngay trên máy. 1 designer/QA của studio hiện KHÔNG THỂ xem thử "RewardPopup với màu này, icon này trông ra sao" mà không nhờ engineer sửa code rồi build lại.

## Vì sao cần / Hậu quả
Vòng lặp thiết kế/thử nghiệm UI chậm không cần thiết — mọi thay đổi tham số nhỏ (màu, icon, text) để xem thử đều cần 1 vòng code-build-run đầy đủ.

## Đề xuất
Mở rộng panel của `DebugQaOverlay` thêm 1 tab thứ 2: 1 gallery sống render từng widget `common/` với tham số có thể chỉnh qua slider/color swatch/text field ngay trong overlay đã gated đó — tái dùng các block demo có sẵn trong `widget_showcase_screen.dart` làm dữ liệu mẫu thay vì phát minh lại từ đầu.

## Acceptance criteria
- [ ] Tab mới trong DebugQaOverlay hiển thị được ít nhất 1 nhóm widget (ví dụ Buttons & Interactive) với tham số chỉnh được trực tiếp trên UI.
- [ ] Toàn bộ tính năng vẫn bị strip hoàn toàn khỏi release build (giữ nguyên gate kDebugMode||kProfileMode hiện có của DebugQaOverlay).
- [ ] Test: mở tab mới, chỉnh 1 tham số (ví dụ màu), xác nhận widget preview cập nhật đúng ngay lập tức; xác nhận build release (kReleaseMode) không render tab này (giữ đúng tree-shake).
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-39-in-app-widget-inspector-playground.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — ý tưởng tham vọng, tận dụng đúng hạ tầng đã có (DebugQaOverlay's gate + widget_showcase's demo data), nhưng effort L lớn nhất trong toàn bộ backlog này — nên làm sau cùng, sau khi các ý tưởng effort nhỏ/trung bình khác đã hoàn thành, hoặc chỉ làm nếu có xác nhận rõ nhu cầu từ 1 studio thật đang dùng kit.
