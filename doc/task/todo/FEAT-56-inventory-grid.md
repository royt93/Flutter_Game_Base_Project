---
id: FEAT-56
title: "InventoryGrid — rarity, stack, locked và equipped state"
type: feature
layer: presentation/widget
priority: P1
effort: L
depends_on: [FEAT-44, FEAT-52]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là game developer, tôi muốn widget inventory data-driven đọc state từ service và tùy biến item renderer.

## Sprint slices
- Item tile + grid/list responsive, rarity/frame/stack/equipped/locked presentation.
- Selection controller optional, pagination/virtualization và empty/loading/error slots.
- Tap/long-press/drag hooks; business mutation vẫn do service command.

## Acceptance criteria
- [ ] Danh sách lớn dùng lazy builder và giữ selection đúng theo stable item id.
- [ ] Update/reorder/remove item không gán state sang tile khác.
- [ ] Locked/equipped/stack semantics rõ; empty/error/loading render đúng.
- [ ] Narrow screen/text scale/RTL/reduced motion không overflow.

## Prompt loop feature
Đọc task/inventory/layout conventions; rã item tile trước grid và TDD. End loop: audit, chấm /10; unit test + widget test + integration test mọi state/reorder/large list/gesture; analyze/test root + example; smoke Android device thật cuộn/chọn/equip có profile. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

