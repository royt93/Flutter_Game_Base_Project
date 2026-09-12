---
id: FEAT-48
title: "FlameObjectPool — tái sử dụng component/particle không leak state"
type: feature
layer: game/utils
priority: P2
effort: M
depends_on: [ENH-56]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là Flame developer, tôi muốn pool projectile/particle để giảm allocation và GC spike trong gameplay nóng.

## Sprint slices
- Generic pool với factory/reset/dispose callbacks và max capacity.
- Acquire/release state guard, double-release detection, prewarm và metrics.
- Flame component mixin/adapter bảo đảm detach/reset lifecycle.
- Benchmark/sample particle burst trước/sau.

## Acceptance criteria
- [ ] Object đang active không được acquire lại; double/foreign release bị phát hiện.
- [ ] Reset xóa toàn bộ mutable gameplay state theo contract.
- [ ] Capacity/dispose/prewarm không leak component/resource.
- [ ] Benchmark chứng minh allocation/GC cải thiện trong kịch bản đại diện.

## Prompt loop feature
Đọc task và Flame lifecycle; implement generic core bằng TDD rồi adapter. End loop: audit changes, chấm /10; unit test + widget test + integration test acquire/release/error/dispose; analyze/test root + example; smoke Android device thật với profile/metrics chứng minh. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

