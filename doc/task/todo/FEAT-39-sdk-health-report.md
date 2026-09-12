---
id: FEAT-39
title: "SdkHealthReport — snapshot chẩn đoán có redaction cho QA/support"
type: feature
layer: core/debug
priority: P2
effort: S
depends_on: [FEAT-32, FEAT-38]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là QA/support, tôi muốn xuất trạng thái SDK đủ tái hiện lỗi mà không lộ dữ liệu người chơi.

## Sprint slices
- Collector registry cho module/version/schema/buffer/FPS/audio/config source.
- Snapshot immutable, JSON export deterministic và redaction allowlist.
- Timeout/isolation collector lỗi; tích hợp DebugQaOverlay và share/copy.

## Acceptance criteria
- [ ] Module thiếu/lỗi vẫn tạo report phần còn lại.
- [ ] Không export secret, raw save, token hay PII mặc định.
- [ ] JSON có schema version, size cap và deterministic test.
- [ ] Debug UI bị gate đúng build mode và không ảnh hưởng release.

## Prompt loop feature
Đọc task và debug/privacy paths; TDD collector/redaction trước UI. End loop: audit code, chấm /10; unit test + widget test + integration test mọi collector/error/redaction; analyze/test root + example; smoke Android device thật với report thực. Lặp tới work và điểm >9/10 mới push; cập nhật Quyết định, chuyển done, push lần hai.

