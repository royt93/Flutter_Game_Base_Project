---
id: IDEA-42
title: "[Killer] Deterministic gameplay replay capsule cho bug QA khó tái hiện"
type: idea
priority: exclusive-medium
effort: L
source: Codex product/architecture synthesis
depends_on: [ENH-56]
---

## Cơ hội
Kit đã có weighted RNG seam, analytics/crash seam, versioned JSON, integrity signing và DebugQaOverlay. Ghép chúng thành một replay capsule nhỏ giúp QA gửi seed + ordered input events + config/version thay vì video không tái hiện được bug gameplay.

## MVP slices
1. Pure event envelope versioned: session seed, monotonic offsets, app/config version, typed event payload.
2. Recorder có bounded ring buffer/redaction; export/import qua `VersionedJsonStore` và optional signature.
3. Replayer inject clock/RNG/event sink, detect divergence thay vì giả vờ replay thành công.
4. DebugQaOverlay có nút start/stop/export; sample Flame demo chứng minh cùng seed cho cùng outcome.

## Acceptance criteria
- [ ] Replay cùng capsule tạo cùng ordered outputs; schema mismatch/corrupt/tamper bị từ chối an toàn.
- [ ] Dữ liệu bounded, không thu PII mặc định, không gây jank hot path.
- [ ] Divergence báo event đầu tiên khác cùng context đủ debug.
- [ ] Unit, widget, integration và device smoke test bao phủ record/replay/export/import/restart/corrupt/performance.

## Prompt loop implementation
Đọc toàn bộ file task này và code liên quan. Viết RFC ngắn về determinism/privacy trước, sau đó implement vertical slice bằng TDD. Mỗi vòng phải audit code, chấm /10, unit + widget + integration test mọi case, analyze/test root + example, smoke Android device thật có replay proof. Lặp đến >9/10 rồi mới commit + push; sau push cập nhật Quyết định, chuyển done, commit + push lần hai.

