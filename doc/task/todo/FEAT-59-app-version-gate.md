---
id: FEAT-59
title: "AppVersionGate — minimum/recommended version và maintenance mode"
type: feature
layer: app/helper
priority: P1
effort: M
depends_on: [ENH-58, FEAT-35, FEAT-38]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là app operator, tôi muốn soft/force update và maintenance mode từ remote config với fallback an toàn.

## Sprint slices
- Semantic version/build evaluator pure Dart và typed gate decision.
- Config asset + remote: minimum, recommended, maintenance window/message/link.
- Controller cache last-known-good; force/soft update overlay builder.
- Store launcher injected, cooldown soft prompt và offline policy.

## Acceptance criteria
- [ ] Version prerelease/build/invalid config được so sánh theo policy đã document.
- [ ] Remote fail/corrupt không force-block user ngoài fallback đã đóng gói.
- [ ] Force gate không dismiss bằng back; soft gate tôn trọng cooldown.
- [ ] URL/platform launch lỗi hiển thị recovery thay vì loop.

## Prompt loop feature
Đọc task/remote config/error model; TDD decision matrix trước UI. End loop: audit, chấm /10; unit test + widget test + integration test mọi version/mode/offline/corrupt/launch error; analyze/test root + example; smoke Android device thật với config fixtures và screenshot. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

