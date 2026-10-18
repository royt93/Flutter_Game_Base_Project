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
- [x] **Unit test**: Validate recipe/material IDs duy nhất, labels không rỗng, quantity không âm và requirement dương (`crafting_recipe_card_test.dart`, 6 tests pass).
- [x] **Widget test**: Craftable/missing/locked/crafting states; callback; ingredient tap; semantics; textScale 2.0.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) craft callback cập nhật caller-owned demo state; ingredient thiếu khóa nút sau craft; pass, không dùng simulator.
- [x] **Golden test**: Ready/missing/locked recipes trên baseline/dark/vi/RTL/textScale/reducedMotion.
- [x] **Interruption test**: Không có internal timer/controller; craft callback do caller điều khiển.
- [x] **Network conditioning test**: N/A — widget presentation-only; server crafting thuộc consumer.
- [ ] **Memory leak & profiling test**: CHƯA CHẠY MemoryWatchdog cho FEAT-156.
- [ ] **Frame rate / Jank test**: CHƯA ĐO recipe list 30+ trên device.
- [x] **IAP & Ad mediation test**: N/A — không gọi purchase/ad SDK.

## Hiệu năng & Animation
- [x] Recipe card không subscribe inventory service hoặc tạo controller.
- [ ] Sustained 60 FPS benchmark: chưa đo, không tuyên bố đạt 60 FPS.
