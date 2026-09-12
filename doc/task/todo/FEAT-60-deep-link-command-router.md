---
id: FEAT-60
title: "DeepLinkCommandRouter — URI thành command typed cho level/shop/event/invite"
type: feature
layer: app/logic
priority: P1
effort: M
depends_on: [FEAT-32, FEAT-38]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là app/game developer, tôi muốn parse và dispatch deep link qua command typed, có auth/readiness gate và chống xử lý trùng.

## Sprint slices
- Route definition/parser pure Dart với allowlist scheme/host/path/query.
- Typed command + validation; queue tới khi bootstrap/auth/game ready.
- Deduplicate/cooldown link; handler registry theo priority.
- Adapter URI stream do consumer cung cấp, không ép plugin vendor.

## Acceptance criteria
- [ ] Link hợp lệ map đúng command; malformed/unknown/oversized input bị reject an toàn.
- [ ] Link trước app-ready được xử lý đúng một lần khi ready.
- [ ] Duplicate concurrent/relaunch policy deterministic.
- [ ] Handler throw không làm mất link khác và có diagnostic result.

## Prompt loop feature
Đọc task/bootstrap/security paths; dùng parser fixtures TDD. End loop: audit, chấm /10; unit test + widget test + integration test mọi URI/queue/dedupe/error; analyze/test root + example; smoke Android device thật bằng adb deep link và log destination. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

