---
id: IDEA-40
title: "[Killer] Recoverable TrustedClock — chống tua giờ mà không khóa người chơi nhiều năm"
type: idea
priority: exclusive-high
effort: L
source: Codex synthesis + prior agy independent opinion
depends_on: [ENH-56]
---

## Vấn đề độc quyền
`ClampedClock` chống rewind tốt nhưng một lần đồng hồ nhảy xa vào tương lai sẽ nâng watermark vĩnh viễn; daily login, energy và offline earning có thể bị khóa cho tới khi thời gian thật bắt kịp. Đây là điểm yếu lớn nhất của chính lợi thế anti-cheat hiện tại.

## Discovery/MVP slices
1. `ClockSample` từ wall clock + monotonic uptime inject được; optional trusted network time adapter.
2. Phân loại normal drift, rewind, suspicious forward jump, reboot.
3. Recovery state machine không tự cấp reward: quarantine/cap elapsed và tái neo khi có trusted sample.
4. Debug QA evidence, telemetry seam và migration từ watermark cũ.

## Acceptance criteria
- [ ] Không regression chống rewind hiện tại.
- [ ] Forward jump lớn không khóa vĩnh viễn và không tạo payout lớn.
- [ ] Reboot/offline/network failure có deterministic policy; mọi time source inject được trong test.
- [ ] Unit, widget, integration và device smoke test bao phủ timeline matrix, process restart và device time change thực.

## Prompt loop implementation
Đọc toàn bộ file task này và code liên quan. Trước code phải viết threat model + decision table; prototype pure Dart bằng TDD rồi mới tích hợp service/UI. Mỗi vòng: audit code, chấm /10, unit + widget + integration test mọi case, analyze/test root + example, smoke Android device thật với log time-change làm bằng chứng. Lặp đến >9/10 rồi mới commit + push; sau push cập nhật Quyết định, chuyển done, commit + push lần hai.

