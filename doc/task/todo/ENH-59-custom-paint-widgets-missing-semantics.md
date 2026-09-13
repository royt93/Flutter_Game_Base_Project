---
id: ENH-59
title: "CircularProgressRing/WheelSpinner: CustomPaint không có Semantics — screen reader không đọc được gì"
type: enhancement
priority: P2
effort: S
source: Claude (self-generated backlog brainstorm sau khi IDEA backlog cạn — xác nhận qua grep trực tiếp, không chỉ dựa vào agent)
---

## User story
Là người chơi dùng screen reader (TalkBack), tôi muốn nghe được giá trị tiến độ của `CircularProgressRing` và mục đang được chọn/dừng của `WheelSpinner`, thay vì im lặng hoàn toàn.

## Hiện trạng và bằng chứng
Grep toàn bộ `lib/presentation/widgets/common/*.dart` cho `Semantics(` cho thấy 2 widget vẽ nội dung Ý NGHĨA hoàn toàn bằng `CustomPainter` (không có `Text` con nào để Flutter tự tạo semantics như `TooltipBubble` đang làm) và KHÔNG có bất kỳ `Semantics`/`semanticLabel` nào:
- `lib/presentation/widgets/common/circular_progress_ring.dart` — `_RingPainter` vẽ % tiến độ chỉ bằng hình vẽ, không có node semantics nào mang giá trị số.
- `lib/presentation/widgets/common/wheel_spinner.dart` — `WheelSpinner`/`_WheelSpinnerState` vẽ danh sách lựa chọn + trạng thái đang quay/đã dừng ở ô nào chỉ bằng `CustomPaint`, không expose được ô nào đang chọn qua accessibility tree.

So sánh: các widget khác (`StarRating`, ...) đã có `Semantics` (ví dụ ENH-37 đã làm cho `StarRating`) — 2 widget này bị bỏ sót trong các đợt sweep semantics trước (ENH-46/ENH-49).

## Scope
- Thêm `Semantics` (label + value phù hợp, ví dụ `value: '${(progress * 100).round()}%'` cho `CircularProgressRing`; label mô tả lựa chọn hiện tại/đang quay cho `WheelSpinner`) bọc quanh phần `CustomPaint` của cả 2 widget.
- KHÔNG đổi API public hiện có (không thêm tham số bắt buộc mới) — nếu cần 1 label caller-cung-cấp thì để optional với default hợp lý tự suy ra từ giá trị đã có sẵn (progress/selected index), tránh breaking change.
- Không sweep toàn bộ các widget "không có `Semantics(`" khác trong thư mục (phần lớn là hiệu ứng thuần hình ảnh — `ConfettiOverlay`, `ScreenShake`, `SquashStretch`, `ComboHeatBackground`... — hoặc widget bọc `Text` con đã tự có semantics sẵn như `TooltipBubble`) — ngoài phạm vi, tránh over-engineer 1 sweep lớn khi chỉ có 2 gap thật đã xác nhận.

## Acceptance criteria
- [ ] `CircularProgressRing` có `Semantics` với `value` phản ánh đúng % tiến độ hiện tại, cập nhật đúng khi progress đổi.
- [ ] `WheelSpinner` có `Semantics` phản ánh đúng trạng thái hiện tại (đang quay / đã dừng ở lựa chọn nào).
- [ ] Không phá bất kỳ test/API hiện có nào của 2 widget này.
- [ ] Test bao phủ: giá trị semantics đúng ở nhiều mốc progress/lựa chọn khác nhau, đúng khi widget rebuild với giá trị mới — widget test dùng `tester.getSemantics`/`find.bySemanticsLabel` tương đương, không chỉ "không throw".
- [ ] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [ ] Device smoke test thật trên Pixel 7 Pro (không simulator) — bật TalkBack thật, xác nhận đọc đúng giá trị, bằng chứng cụ thể (log/mô tả) trong Quyết định.

## Prompt loop implementation
Đọc kỹ file `doc/task/todo/ENH-59-custom-paint-widgets-missing-semantics.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Scope bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không mở rộng sang các widget khác ngoài 2 widget đã nêu).
2. Bổ sung ĐỦ test cho MỌI case liên quan — widget test dựng widget thật, assert đúng giá trị semantics ở nhiều trạng thái khác nhau.
3. Không có animation mới cần thêm (chỉ thêm semantics, không đổi behavior hình ảnh) — nếu vô tình cần đổi animation thì vẫn phải tôn trọng `NeonTheme.reducedMotion` như hiện có.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator), bật TalkBack, xác nhận đọc đúng giá trị — ghi lại cụ thể trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 4-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.
