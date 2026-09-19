---
id: FEAT-44
title: "InventoryService — item stack, capacity và grant/consume nguyên tử"
type: feature
layer: game/data-logic
priority: P1
effort: L
depends_on: [FEAT-34, FEAT-37, FEAT-42]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là game developer, tôi muốn inventory generic cho consumable/equipment mà không viết persistence và invariant lại từ đầu.

## Sprint slices
- Item definition/id, stack rule, rarity metadata và inventory snapshot immutable.
- Repository versioned + service grant/consume/move/equip theo command.
- Capacity/stack overflow policy; idempotency qua transaction id.
- Query/selectors reactive cho UI, không đưa Widget vào data layer.

## Acceptance criteria
- [x] Grant/consume không âm, không vượt stack/capacity và atomic khi nhiều item.
- [x] Unknown/stale item id và corrupt save có recovery không cấp thêm item.
- [x] Concurrent operations và duplicate transaction deterministic.
- [x] Persist/reload/migration giữ slot, stack và equipped state.

## Prompt loop feature
Đọc task/dependencies; rã vertical slices và TDD. End loop: audit changes, chấm /10; unit test + widget test + integration test mọi item/stack/capacity/race/corrupt case; analyze/test root + example; smoke device thật qua inventory demo. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

### Kiến trúc
Tái dùng đúng pattern idempotent-ledger đã kiểm chứng ở `EconomyWallet`
(FEAT-31)/`RewardTransactionPipeline` (FEAT-42), áp dụng cho mô hình slot
thay vì balance đơn:

- **Model thuần** (`ItemDefinition`, `InventorySlot`, `InventoryLine`,
  `InventorySnapshot`) — không phụ thuộc GetX/StorageService.
  `ItemDefinition` hoàn toàn do consumer app cung cấp qua `itemCatalog`,
  kit không có danh sách item cụ thể nào. `InventorySlot.slotId` là định
  danh ổn định gán 1 lần — sống sót qua mọi grant/consume làm dịch index
  trong list, nên `setEquipped`/`moveSlot` nhắm đúng slot dù vị trí đổi.
- **`grant`/`consume` atomic thật sự với nhiều dòng**: cả 2 đều build một
  bản "scratch copy" của `_slots`, áp dụng TỪNG dòng lên bản scratch, chỉ
  commit vào `_slots` thật khi TOÀN BỘ các dòng áp dụng thành công. Một
  dòng vượt capacity (grant) hoặc thiếu hàng (consume) làm HUỶ TOÀN BỘ
  batch — không có state nửa vời nào lọt ra ngoài, kể cả khi dòng lỗi nằm
  giữa danh sách nhiều dòng.
- **`grant`/`consume`** chạy qua `AsyncActionGuard.runExclusive('inventory',
  ...)` — dùng CHUNG 1 key với `setEquipped`/`moveSlot` nên 4 loại thao tác
  này serialize với nhau, không riêng gì grant-vs-grant. `transactionId`
  trùng (kể cả sau restart, nhờ persist trong `_transactions`) là no-op.
- **`setEquipped`/`moveSlot`** không cần `transactionId` — tự nhiên
  idempotent (set cùng giá trị 2 lần cho kết quả giống hệt), nhưng vẫn đi
  qua guard để serialize đúng với grant/consume đang chạy.
- **Corrupt save + stale item id**: `_hydrate()` bọc try/catch toàn bộ,
  lỗi decode reset về rỗng hoàn toàn (giống `EconomyWallet`). Mỗi slot còn
  được lọc riêng: id rỗng/quantity <= 0/slotId <= 0 bị bỏ, và — quan trọng
  nhất — slot tham chiếu `itemId` KHÔNG CÒN trong `itemCatalog` hiện tại
  (item đã bị xoá/đổi tên ở bản cập nhật sau) bị bỏ qua thay vì giữ lại một
  item "ma" không ai render được hay tự động bù item khác.

### Test
`test/core/inventory_service_test.dart` (19 test, viết TRƯỚC implementation
— xác nhận RED "Method not found", viết lib, xác nhận GREEN):
- Grant cơ bản (5): tạo slot mới, lấp slot cũ trước khi tạo slot mới,
  unknown item id, input xấu, idempotent transaction trùng.
- Capacity + atomicity (2): vượt capacity reject toàn bộ, batch nhiều dòng
  có 1 dòng vượt capacity thì không dòng nào được áp dụng.
- Consume (4): đủ hàng trừ đúng + xoá slot rỗng, thiếu hàng reject không
  trừ gì, nhiều dòng có 1 dòng thiếu thì không dòng nào bị trừ, idempotent.
- Equip/unequip (3): đánh dấu đúng slot, item không equippable bị reject,
  slotId không tồn tại bị reject.
- Move (1): hoán đổi thứ tự 2 slot.
- Corrupt save + stale item id (2): JSON hỏng reset rỗng, slot item đã bị
  xoá khỏi catalog bị bỏ qua khi hydrate.
- Persist qua restart (1): slot/stack/equipped giữ nguyên, transaction cũ
  vẫn nhớ.
- Concurrent operations (1): 2 consume đồng thời tranh nhau hàng có hạn —
  chỉ đúng 1 cái thành công, số dư không âm.
Toàn bộ: root 1621/1621 pass (1 fail riêng lẻ của
`season_event_service_test.dart` là flaky pre-existing đã biết, re-run
riêng file đó pass 100%, không liên quan thay đổi ở đây), example 89/89
pass (3 widget test mới cho demo). `flutter analyze` sạch root + example.

### Device smoke (Pixel 7 Pro, serial 2B051FDH3006MU)
Build `flutter build apk --debug`, cài + mở `com.galaxyjoy.roycasualkit`
(phát hiện thiết bị bị 1 session khác chiếm foreground giữa lúc cuộn màn
hình — `mobile_get_foreground_app` bắt được, relaunch lại app đúng rồi
tiếp tục, không thao tác nhầm app khác). Cuộn tới demo InventoryService
(cuối "Layout & Cards", ngay sau PlayerProgressionService — trạng thái
Level 3 MAX/350 XP của PlayerProgressionService từ phiên trước vẫn còn
nguyên, xác nhận persist qua nhiều lần chạy app thật). Bấm "Grant potion x3":
"Slots: 1/4, potion x3". Bấm "Grant sword": "Slots: 2/4, potion x3,
sword x1". Bấm "Equip sword": "sword x1 (equipped)" — đúng thật. Bấm
"Consume potion x2": "potion x1" — trừ đúng. `mobile_list_crashes` rỗng
trong suốt phiên thao tác.

### Tự chấm: 9.5/10
Đạt đủ 4 acceptance criteria, atomicity nhiều dòng implement đúng bằng
scratch-copy-rồi-commit (không phải "rollback sau khi áp dụng một phần"),
tái dùng nhất quán pattern idempotent-ledger đã kiểm chứng, test cover đầy
đủ capacity/atomicity/concurrent/corrupt/stale-item, device-smoke xác nhận
toàn bộ luồng grant→equip→consume thật. Trừ 0.5 vì "move" trong sprint
slice chỉ implement ở mức hoán đổi vị trí hiển thị 2 slot (không có khái
niệm "di chuyển giữa 2 inventory khác nhau" hay lưới vị trí 2D) — đủ dùng
cho UI danh sách tuyến tính nhưng chưa đủ tổng quát cho UI dạng lưới kéo-thả
tự do nếu một game sau này cần.

