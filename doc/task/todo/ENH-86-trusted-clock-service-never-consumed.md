---
id: ENH-86
title: "TrustedClockService xây dựng đầy đủ nhưng không service anti-cheat nào thật sự tiêu thụ kết quả của nó"
type: enhancement
priority: P2
effort: M
source: "claude (độc lập)"
---

## Vị trí
`lib/core/utils/trusted_clock.dart` (`TrustedClockService`/`ClockSample`/`ClockJudgement`), các service time-gated (`EnergyService`, `DailyLoginService`, `OfflineProgressionService`, `SeasonEventService`).

## Hiện trạng
`TrustedClockService` cung cấp phân tích lệch wall-clock-vs-monotonic chặt hơn `ClampedClock`, nhưng không service time-gated nào trong kit thực sự đọc `ClockJudgement` của nó để quyết định hành vi (ví dụ từ chối regen/reward khi judgement báo nghi ngờ rewind nghiêm trọng). Class tồn tại, có test riêng, nhưng "cô lập" — không nằm trong luồng quyết định thật nào.

## Vì sao cần / Hậu quả
1 service được xây với mục đích chống gian lận nghiêm túc nhưng không được bất kỳ đường dẫn nghiệp vụ nào tiêu thụ gần như vô dụng trong thực tế — game vẫn chỉ dựa vào `ClampedClock` (bảo vệ yếu hơn) cho các quyết định thật.

## Đề xuất
Chọn ít nhất 1 service time-gated có giá trị cao (ví dụ `OfflineProgressionService.claim()` hoặc `EnergyService`) tích hợp `TrustedClockService.judge(...)` như 1 lớp kiểm tra bổ sung (optional, không bắt buộc để tránh breaking change) — khi judgement báo nghi ngờ rewind nghiêm trọng, có thể log/cảnh báo hoặc từ chối claim tuỳ policy consumer chọn.

## Acceptance criteria
- [ ] Ít nhất 1 service thật (ví dụ `OfflineProgressionService`) có tham số optional dùng `TrustedClockService` khi được cung cấp.
- [ ] Không dùng `TrustedClockService` (mặc định) giữ nguyên hành vi hiện tại — không breaking.
- [ ] Test verify khi có `TrustedClockService` và judgement báo nghi ngờ rewind, hành vi tương ứng (log/reject theo thiết kế) được kích hoạt đúng.
- [ ] Doc comment/CLAUDE.md cập nhật giải thích rõ khi nào nên dùng `TrustedClockService` thay vì chỉ `ClampedClock`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-86-trusted-clock-service-never-consumed.md` này trước khi làm. Đọc toàn bộ `lib/core/utils/trusted_clock.dart`, `lib/core/utils/clamped_clock.dart`, và service time-gated ứng viên (`OfflineProgressionService` hoặc `EnergyService`) trước khi tích hợp. Implement bằng TDD, cân nhắc kỹ (ponytail) không over-engineer — chỉ tích hợp optional, không bắt buộc mọi service dùng.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (logic thuần chống gian lận, không có UI mới bắt buộc).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — claude tự nhận có sửa lại giả định ban đầu (từng nghĩ `TrustedClockService` zero-usage tuyệt đối, sau verify lại thấy nó CÓ xuất hiện trong `DebugQaOverlay` — chỉ không được tiêu thụ bởi service nghiệp vụ thật). Đã điều chỉnh mô tả task này cho khớp phát hiện đã verify lại (chỉ nói "không service anti-cheat nào tiêu thụ", không nói "zero usage"). Không trùng task nào trong `doc/task/done/`.
