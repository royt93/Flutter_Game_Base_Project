---
id: FEAT-47
title: "AssetPreloadCoordinator — bundle ảnh/audio/shader theo scene"
type: feature
layer: game/data
priority: P1
effort: M
depends_on: [FEAT-35, FEAT-38, FEAT-41]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là game developer, tôi muốn preload asset theo manifest với progress/retry để scene không giật hoặc vào trạng thái nửa tải.

## Sprint slices
- Typed manifest bundle và loader adapter cho Flame images/audio/Flutter assets/shaders.
- Dependency graph, bounded concurrency, weighted progress và cancellation.
- Cache/reference policy, unload scene và retry failed item.
- Loading state nối GameSessionController và example.

## Acceptance criteria
- [ ] Duplicate asset chỉ load một lần; dependency/cycle/missing asset báo typed error.
- [ ] Progress monotonic 0→1 và không báo complete khi item bắt buộc fail.
- [ ] Cancel/retry/unload không leak resource hay callback.
- [ ] Optional asset fail không chặn scene theo policy.

## Prompt loop feature
Đọc task và Flame/audio/shader code; TDD fake loaders trước platform wiring. End loop: audit code, chấm /10; unit test + widget test + integration test manifest/progress/error/cancel/cache; analyze/test root + example; smoke Android device thật đo load/progress và log asset. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

