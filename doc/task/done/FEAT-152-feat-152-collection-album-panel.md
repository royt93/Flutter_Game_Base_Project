---
id: FEAT-152
title: CollectionAlbumPanel — Album vật phẩm với độ hiếm và tiến độ bộ sưu tập
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Social, Collection & Community (Wave 13)
---

## Vì sao cần
Người chơi cần một nơi xem vật phẩm/skin đã thu thập, vật phẩm còn thiếu và tiến độ hoàn thành từng bộ. Panel collection giúp thể hiện mục tiêu meta-game mà không để UI quyết định quyền sở hữu.

## Đề xuất phạm vi
Widget `CollectionAlbumPanel` hiển thị:
- Album/bộ sưu tập và danh sách item caller cung cấp (`id`, tên, icon/asset, rarity, owned state).
- Tiến độ bộ sưu tập (owned/total) và trạng thái phần thưởng completion do caller truyền.
- Filter hoặc tab theo collection nếu nhiều bộ; item list/grid dùng lazy rendering.
- Tap item gọi `onItemTap(itemId)`; action xem phần thưởng gọi `onViewReward` nếu có.
- Presentation-only: caller đọc `InventoryService`/catalog và xác minh entitlement; widget không sở hữu vật phẩm hoặc cấp thưởng.

## Ma trận kiểm thử bắt buộc (DoD)
- [x] **Unit test**: Validate collection/item IDs duy nhất, name không rỗng, owned/required hợp lệ (`collection_album_panel_test.dart`, 7 test pass).
- [x] **Widget test**: Owned/missing/rarity states, progress, filter, callbacks, empty, completion reward, semantics và textScale 2.0.
- [x] **Integration test (Device)**: Pixel 7 Pro (`2B051FDH3006MU`) lọc owned/missing và tap item qua showcase thật; pass.
- [x] **Golden test**: Mixed rarity và completed collection trên baseline/dark/vi/RTL/textScale/reducedMotion.
- [x] **Interruption test**: N/A — không có timer/controller nội bộ.
- [x] **Network conditioning test**: N/A — widget presentation-only; catalog sync thuộc caller.
- [ ] **Memory leak & profiling test**: CHƯA CHẠY MemoryWatchdog cho FEAT-152.
- [ ] **Frame rate / Jank test**: CHƯA ĐO grid 50+ items trên device.
- [x] **IAP & Ad mediation test**: N/A — widget không mua hoặc cấp entitlement.

## Hiệu năng & Animation
- [x] Grid 3 cột dùng `GridView.builder` lazy rendering.
- [ ] Sustained 60 FPS benchmark: chưa đo, không tuyên bố đạt 60 FPS.

## Quyết định API
- [x] Grid 3 cột; mỗi item truyền `ownedCount/requiredCount`.
- [x] Dùng `ItemRarity` hiện có; không truy cập `InventoryService` trực tiếp.
