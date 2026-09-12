---
id: FEAT-61
title: "ConsentStateService — gate analytics/ads/personalization theo consent"
type: feature
layer: app/data-logic
priority: P1
effort: M
depends_on: [FEAT-03, FEAT-02, FEAT-32, FEAT-37]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là app developer, tôi muốn một SSOT consent có version để provider chỉ hoạt động khi được phép.

## Sprint slices
- Immutable consent categories/status/source/policyVersion/timestamp.
- Repository versioned persistence và controller commands grant/deny/reset.
- Provider gate cho analytics, ads và personalization; default deny nơi chưa quyết định.
- UI seam do consumer render, SDK chỉ cung cấp state/commands và example.

## Acceptance criteria
- [ ] Chưa consent/deny không gửi event hay khởi tạo provider bị gate.
- [ ] Policy version mới đưa category cần thiết về trạng thái review lại theo rule.
- [ ] Revoke có hiệu lực tức thì và persist qua restart.
- [ ] Corrupt save không biến thành granted; race update deterministic.

## Prompt loop feature
Đọc task/providers/storage; viết consent transition/privacy matrix và TDD. End loop: audit, chấm /10; unit test + widget test + integration test mọi grant/deny/revoke/version/corrupt/provider gate; analyze/test root + example; smoke Android device thật chứng minh network/provider bị chặn/mở. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

