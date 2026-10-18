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
- [ ] **Unit test**: Validate collection/item IDs duy nhất, label không rỗng, tổng/owned hợp lệ.
- [ ] **Widget test**: Owned/missing/rarity states, progress, filter/tab, callbacks, empty state, semantics và Reduced Motion.
- [ ] **Integration test (Device)**: Pixel 7 Pro mở album, lọc/chạm item gọi caller seam; không dùng simulator.
- [ ] **Golden test**: Collection ít/nhiều item, nhiều rarity, empty và completion trên light/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: Đổi filter hoặc unmount trong lúc animation không giữ state/ticker mồ côi.
- [ ] **Network conditioning test**: N/A — widget presentation-only; catalog sync thuộc caller.
- [ ] **Memory leak & profiling test**: MemoryWatchdog sau scroll/unmount album lớn.
- [ ] **Frame rate / Jank test**: Scroll grid 50+ items, báo FrameTiming p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A — widget không mua hoặc cấp entitlement.

## Hiệu năng & Animation
- [ ] Dùng builder lazy cho album lớn; ưu tiên placeholder icon, không decode mọi ảnh ngoài viewport.
- [ ] Sustained 60 FPS benchmark: chỉ ghi sau đo trên thiết bị vật lý.
