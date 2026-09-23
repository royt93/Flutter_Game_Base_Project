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
- [x] Ít nhất 1 service thật (ví dụ `OfflineProgressionService`) có tham số optional dùng `TrustedClockService` khi được cung cấp.
- [x] Không dùng `TrustedClockService` (mặc định) giữ nguyên hành vi hiện tại — không breaking.
- [x] Test verify khi có `TrustedClockService` và judgement báo nghi ngờ rewind, hành vi tương ứng (log/reject theo thiết kế) được kích hoạt đúng.
- [x] Doc comment/CLAUDE.md cập nhật giải thích rõ khi nào nên dùng `TrustedClockService` thay vì chỉ `ClampedClock`.

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

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Implement**: `OfflineProgressionService` nhận thêm param optional
`trustedClock` (`TrustedClockService?`, mặc định `null`). Thêm helper
`_now() => trustedClock?.nowMsTrusted() ?? nowMsClamped();`, dùng thay cho
`nowMsClamped()` trực tiếp tại cả `pendingEarnings`/`claim`. KHÔNG thêm
logic reject/log riêng trong `OfflineProgressionService` — hành vi "từ
chối" tự nhiên phát sinh từ chính cơ chế sẵn có của
`TrustedClockService.nowMsTrusted()`: khi judgement là `rewind`/
`suspiciousForwardJump`, nó trả về baseline CŨ (không advance) thay vì mốc
bị thao túng — khiến elapsed tính ra = 0, earned = 0, không cần thêm
`if (judgement == suspicious) reject` trùng lặp. Đây là điểm áp dụng
ponytail rõ nhất: tái dùng cơ chế đã có thay vì viết logic reject song
song.

**Vì sao chọn `OfflineProgressionService` (không phải `EnergyService`)**:
đúng như đề xuất gợi ý, và đây là service có payout MỘT LẦN lớn nhất
(gom dồn nhiều giờ/ngày) — đúng lớp lỗ hổng `TrustedClockService`
(IDEA-40) sinh ra để chặn (vặn đồng hồ tới tương lai, claim 1 lần, vặn lại)
— khác `EnergyService`/`DailyLoginService` vốn payout nhỏ, lặp lại đều,
lợi ích khai thác thấp hơn nhiều so với rủi ro đổi API.

**Consumer tự log/alert**: không thêm callback/log hook mới —
`TrustedClockService.lastJudgement` (getter public đã có sẵn) đủ để
consumer app tự đọc ngay sau khi gọi `claim()` và quyết định chính sách
riêng (log/toast/chặn thêm) — tránh phát minh 1 tầng "policy" abstraction
không ai yêu cầu.

**TDD**: `git stash push -- lib/core/offline_progression_service.dart`,
chạy 5 test mới (nhóm "ENH-86") — FAIL đúng ở bước biên dịch (`No named
parameter 'trustedClock'`, `getter 'trustedClock' isn't defined`) trên
code cũ. `git stash pop`, chạy lại toàn file — 19/19 pass, gồm: mặc định
không đổi hành vi cũ; đồng hồ trôi bình thường qua `trustedClock` cho kết
quả claim khớp `nowMsClamped`; `suspiciousForwardJump` (vặn tới +1 năm) bị
từ chối earned=0 (nếu dùng `nowMsClamped` sẽ trả gần 1 năm tiền, đã ghi rõ
trong assertion/comment); `rewind` cũng bị từ chối earned=0; và test quan
trọng nhất — phục hồi sau `suspiciousForwardJump`: sample bình thường tiếp
theo tính đúng tiếp, KHÔNG bị khoá vĩnh viễn như `nowMsClamped` sẽ bị.

**CLAUDE.md**: cập nhật mục `utils/trusted_clock.dart` giải thích rõ khi
nào dùng `TrustedClockService` thay `ClampedClock` (payout một lần giá trị
cao, không phải hệ thống lặp lại đều đặn), trỏ tới
`OfflineProgressionService.trustedClock` làm integration tham khảo.

**Kết quả**: `flutter analyze` root sạch. `flutter test --exclude-tags
slow` root: 2240 test (+6 so với trước, đúng 5 test mới +1 test default
mới), 19 fail — đúng golden-image baseline, không có fail mới (lần chạy
này không dính flaky ENH-71). `dart run tool/api_compatibility.dart check`
→ `unchanged` (không thêm export public mới, chỉ thêm field/param trên
class đã export sẵn). Không cần smoke test device (task tự ghi rõ, logic
thuần chống gian lận).

Tự chấm: **9.5/10** — tích hợp đúng 1 service giá trị cao nhất, tái dùng
cơ chế reject sẵn có thay vì viết trùng lặp, TDD chứng minh cả reject lẫn
recovery (điểm khác biệt cốt lõi so với `ClampedClock`), backward-compat
100% (test default riêng + toàn bộ test cũ pass nguyên), convention ghi
rõ trong CLAUDE.md. Trừ 0.5 vì chỉ tích hợp 1/4 service time-gated được
liệt kê trong "Vị trí" — hợp lý theo đúng "ít nhất 1 service" của
acceptance criteria, nhưng chưa phải phủ hết mọi service liệt kê.
