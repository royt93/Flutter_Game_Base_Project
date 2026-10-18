---
id: FEAT-156
title: CraftingRecipeCard — Công thức chế tạo, nguyên liệu và trạng thái khả dụng
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Progression, Crafting & Collection Meta UI (Wave 14)
---

## Vì sao cần
Người chơi cần biết công thức cần nguyên liệu nào, còn thiếu bao nhiêu và khi nào có thể chế tạo. UI phải mô tả chính xác inventory state do caller cung cấp, không tự tiêu hao vật phẩm.

## Đề xuất phạm vi
Widget `CraftingRecipeCard` hiển thị:
- Tên/cấp rarity recipe, phần thưởng tạo ra và danh sách nguyên liệu (`ownedCount`, `requiredCount`).
- Trạng thái `Craft` enabled khi caller nói khả dụng; nút gọi `onCraft(recipeId)` và không tự consume/grant.
- Trạng thái thiếu nguyên liệu, đang chế tạo hoặc bị khóa theo props caller.
- Danh sách recipe lớn dùng lazy rendering; hỗ trợ item tap mở chi tiết qua callback tùy chọn.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: Validate recipe/material IDs duy nhất, labels không rỗng, quantity không âm và requirement dương.
- [ ] **Widget test**: Craftable/missing/locked/crafting states; callback đúng recipe ID; semantics; textScale/Reduced Motion.
- [ ] **Integration test (Device)**: Pixel 7 Pro craft callback cập nhật caller-owned demo state; ghi test name và kết quả thiết bị thật. Không dùng simulator.
- [ ] **Golden test**: Ít/nhiều nguyên liệu, craftable/thiếu/locked trên light/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: Tap craft lặp hoặc unmount khi callback pending không phát sinh callback kép từ widget.
- [ ] **Network conditioning test**: N/A — widget presentation-only; server crafting thuộc consumer.
- [ ] **Memory leak & profiling test**: MemoryWatchdog sau scroll/mount/unmount recipe list.
- [ ] **Frame rate / Jank test**: Scroll 30+ recipes, báo FrameTiming p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A — không gọi purchase/ad SDK.

## Hiệu năng & Animation
- [ ] Dùng lazy list cho nhiều recipe; UI không giữ inventory subscription/controller.
- [ ] Sustained 60 FPS benchmark: chỉ tuyên bố khi có telemetry vật lý đo thật.
