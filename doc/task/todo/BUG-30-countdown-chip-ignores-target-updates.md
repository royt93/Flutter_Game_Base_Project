---
id: BUG-30
title: "CountdownChip: đổi target lúc runtime không được nhận, đồng hồ đếm tới đích cũ"
type: bug
priority: P2
effort: S
source: Gemini (agy CLI, audit widget enhancement — tái phân loại thành bug vì đây là lỗi chức năng thật)
---

## Vị trí
`lib/presentation/widgets/common/countdown_chip.dart` — `_CountdownChipState`.

## Hiện trạng
`_remaining` và timer định kỳ chỉ được khởi tạo/tính 1 LẦN trong `initState()`. Nếu widget cha đổi `widget.target` (ví dụ người chơi mua item rút ngắn cooldown, hoặc app gia hạn thời gian ưu đãi) trong khi `CountdownChip` VẪN LÀ CÙNG 1 instance (không bị rebuild lại từ đầu qua key mới), `didUpdateWidget` không được implement — countdown tiếp tục đếm tới target CŨ, bỏ qua giá trị mới hoàn toàn.

## Vì sao cần / Hậu quả
Đây là bug chức năng thật (không chỉ thẩm mỹ): người chơi mua "rút ngắn thời gian chờ" nhưng đồng hồ hiển thị không hề đổi cho tới khi họ rời màn hình và quay lại (force rebuild). Rất dễ gây khiếu nại nếu dùng cho cooldown có trả phí.

## Đề xuất
Implement `didUpdateWidget`: khi `oldWidget.target != widget.target`, tính lại `_remaining`, reset `_fired = false` (nếu cờ này tồn tại — kiểm tra code thật), và restart timer định kỳ nếu cần (huỷ timer cũ, tạo timer mới với `_remaining` mới).

## Acceptance criteria
- [ ] CountdownChip cập nhật đúng khi widget cha đổi target lúc runtime (không cần key mới/rebuild toàn bộ).
- [ ] onDone (nếu có callback tương tự) không bị gọi kép hoặc bị bỏ sót khi target đổi ngay trước/sau khi đếm về 0.
- [ ] Test dùng StatefulBuilder đổi target giữa chừng (theo đúng pattern StatefulBuilder + late StateSetter đã dùng nhiều lần trong session animation round), xác nhận _remaining/hiển thị cập nhật đúng ngay sau đổi.
- [ ] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định.
- [ ] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-30-countdown-chip-ignores-target-updates.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — đây là bug chức năng thật do Gemini phát hiện khi audit enhancement, không phải suy đoán; đã đọc code xác nhận `didUpdateWidget` thực sự không tồn tại trong class này.
