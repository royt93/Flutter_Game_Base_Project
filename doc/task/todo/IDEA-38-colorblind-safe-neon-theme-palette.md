---
id: IDEA-38
title: "[Killer] Color-blind-safe palette variant cho NeonTheme.gemColors"
type: idea
priority: exclusive
effort: S
source: Claude (claude --dangerously-skip-permissions, agent độc lập, brainstorm new/killer feature)
---

## Vị trí
Mở rộng — `lib/core/neon_theme.dart` (`gemColors`, cờ `dark`, `exportPalette`/`importPalette`).

## Hiện trạng
`NeonTheme.gemColors` là 7 màu bão hoà cao (cyan/magenta/lime/vàng/cam/tím/đỏ) — đúng hình dạng "7 màu kẹo phân biệt" mà 1 game match-3 xây trên lịch sử của kit này ("Pop Star Blast", theo CLAUDE.md) sẽ dùng để tô màu gem/tile. Đỏ/xanh lá/cam rất dễ trùng màu với người mù màu đỏ-xanh (protanopia/deuteranopia, ~8% nam giới) — 1 lỗi accessibility cụ thể và nổi tiếng của chính thể loại game này. `NeonTheme` đã có sẵn đúng cơ chế để sửa rẻ tiền: `dark` là 1 cờ mutable với getter đổi giá trị theo, và `exportPalette`/`importPalette` đã hỗ trợ đổi cả bộ màu ("studio reskin" JSON).

## Vì sao cần / Hậu quả
1 casual game match-3 dùng gemColors mặc định có thể VÔ TÌNH loại bỏ hoàn toàn ~8% người chơi nam khỏi việc phân biệt được các loại gem — 1 vấn đề accessibility thật, không phải lý thuyết, đặc biệt nghiêm trọng cho đúng thể loại game này.

## Đề xuất
`NeonTheme.colorBlindSafe` — 1 cờ mutable thứ 2 (giống hệt cơ chế `dark`), lưu qua 1 `StorageKeys` mới, khi bật đổi `gemColors` sang 1 bộ 7 màu an toàn cho CVD (ví dụ dựa trên bảng màu Okabe-Ito) — cùng cơ chế "lật cờ, mọi call site tự cập nhật" mà `dark` đã chứng minh hoạt động tốt. Cân nhắc thêm `gemShapeForIndex(int)` để hình dạng, không chỉ màu, phân biệt gem — giải pháp game-agnostic thật sự.

## Acceptance criteria
- [ ] colorBlindSafe là 1 cờ mutable lưu qua StorageKeys mới, mặc định false (giữ nguyên hành vi hiện tại).
- [ ] Bật cờ đổi gemColors sang bộ màu CVD-safe, mọi widget đọc NeonTheme.gemColors tự động nhận màu mới không cần đổi code.
- [ ] Test: bật/tắt cờ đổi đúng gemColors; cờ persist đúng qua StorageService giống cách dark đã làm; test màu mới thực sự phân biệt được cho ít nhất 1 mô hình CVD phổ biến (deuteranopia) qua kiểm tra khoảng cách màu.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-38-colorblind-safe-neon-theme-palette.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — vấn đề thật, cơ chế sửa đã có sẵn 90% (chỉ cần lặp lại pattern của `dark`), effort thấp, giá trị accessibility rõ ràng và cụ thể cho đúng thể loại game này.
