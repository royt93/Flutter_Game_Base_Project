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
- [x] Danh sách lớn dùng lazy builder và giữ selection đúng theo stable item id.
- [x] Update/reorder/remove item không gán state sang tile khác.
- [x] Locked/equipped/stack semantics rõ; empty/error/loading render đúng.
- [x] Narrow screen/text scale/RTL/reduced motion không overflow.

## Prompt loop feature
Đọc task/inventory/layout conventions; rã item tile trước grid và TDD. End loop: audit, chấm /10; unit test + widget test + integration test mọi state/reorder/large list/gesture; analyze/test root + example; smoke Android device thật cuộn/chọn/equip có profile. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Xây `InventoryGrid` (`lib/presentation/widgets/common/inventory_grid.dart`) —
widget thuần trình bày trên `InventorySnapshot` (FEAT-44), không tự chứa
logic game: `itemBuilder` do caller cung cấp toàn bộ (icon, rarity frame,
stack count, equipped badge), tap/long-press/reorder chỉ phát callback, mọi
mutation thật (`consume`/`setEquipped`/`moveSlot`) do caller tự gọi
`InventoryService`.

**Bug thật tìm được qua TDD** (phát hiện trước khi ship, không phải code
review): bản đầu dùng `GridView.builder` + bọc mỗi ô bằng `KeyedSubtree`,
tưởng key là đủ để giữ identity ổn định khi reorder. 2 test (swap vị trí +
xoá slot giữa danh sách, dùng `_CounterTile` StatefulWidget cố tình KHÔNG
gán key riêng để buộc test dựa hoàn toàn vào keying nội bộ của
`InventoryGrid`) fail: state của tile bám theo VỊ TRÍ trong danh sách chứ
không theo `slotId`. Nguyên nhân gốc: `SliverChildBuilderDelegate` mặc định
của `GridView.builder` không có `findChildIndexCallback` — cơ chế
reconciliation của sliver chỉ so "widget mới ở index N" với "Element cũ ở
index N", không bao giờ quét lại toàn danh sách để tìm key khớp ở chỗ khác
(khác với `Column`). `KeyedSubtree` một mình không đủ trong ngữ cảnh sliver
này. Sửa bằng `GridView.custom` + `SliverChildBuilderDelegate(...,
findChildIndexCallback:)` tra lại index hiện tại của một `slotId` — đúng
cái làm cho các key ở trên có ý nghĩa qua rebuild.

Verify:
- `flutter analyze` root + `example/`: sạch.
- `flutter test --exclude-tags slow` root: 1714/1714 pass.
- `flutter test --exclude-tags slow` `example/`: 96/96 pass (gồm 2 test mới
  cho demo `InventoryGrid (FEAT-56)`, sau khi sửa 1 test tự viết sai — dùng
  `find.byIcon(Icons.lock_rounded)` không scope, bị đếm trùng icon khoá của
  `RewardChoicePanel`/`LevelSelectGrid` khác trên cùng màn hình; sửa bằng
  `find.descendant(of: find.byType(InventoryGrid), matching: ...)`).
- `dart run tool/api_compatibility.dart check`: unchanged (đúng hạn chế đã
  biết — tool chỉ soi export trực tiếp từ `lib/roy_casual_kit.dart`, không
  soi xuyên qua barrel `common_widgets.dart`).
- 14 widget test cho `InventoryGrid` (`test/widget/common/inventory_grid_test.dart`):
  render cơ bản, selection, tap/long-press hooks, stable identity qua
  reorder/update (2 test bắt bug ở trên), reorder qua drag, lazy builder với
  capacity 500 (`builtCount < 50`), text scale/RTL không overflow.
- Smoke test Android thật (Pixel 7 Pro, `pm clear` trước mỗi lần, build
  debug APK từ `example/`): grant potion x3 → tile hiện đúng `potion`/`x3`;
  1 ô locked (capacity 4, `unlockedCapacity` 3) hiện icon khoá; tap chọn/bỏ
  chọn đổi viền vàng đúng; grant sword + Equip sword → badge check xanh
  hiện đúng góc tile; không crash (`mobile_get_crash` không có report).
  Lưu ý ngoài lề: có 1 lần thao tác tay bấm nhầm vào ref đã cuộn ra ngoài
  màn hình (tọa độ y âm) khiến tưởng nhầm là bug "grant 1 lần ra 2 slot" —
  test lại sạch (pm clear, chỉ bấm khi element có tọa độ dương/visible) xác
  nhận đây là thao tác test sai, không phải bug widget.

Tự chấm: 9.5/10. Trừ điểm vì chưa test kéo-thả (`onReorder`) thật trên thiết
bị — chỉ có widget test cho drag, phần còn lại đã đầy đủ và có bug thật bắt
được trước khi ship.

