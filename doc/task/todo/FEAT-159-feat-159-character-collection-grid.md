---
id: FEAT-159
title: CharacterCollectionGrid — Bộ sưu tập nhân vật owned/locked với rarity và filter
type: feature
priority: P1
effort: M
source: Scrum Master Epic: Progression, Crafting & Collection Meta UI (Wave 14)
---

## Vì sao cần
Game có nhiều nhân vật cần một màn collection giúp người chơi xem nhân vật sở hữu/chưa mở, rarity và chọn nhân vật hiện hành. Grid cần hoạt động với catalog dài mà không tự quản lý entitlement hay equip state.

## Đề xuất phạm vi
Widget `CharacterCollectionGrid` hiển thị:
- Danh sách `CharacterCollectionItem` caller cung cấp: id, tên, rarity, asset/icon, owned/selected state.
- Filter All/Owned/Locked và highlight selection hiện tại.
- Tap nhân vật gọi `onCharacterTap(characterId)`; action chọn gọi `onSelect(characterId)` nếu caller cho phép.
- Lazy 3-column grid; names dài dùng ellipsis, semantics nêu rarity và locked/owned.
- Presentation-only: caller xác thực unlock/equip và cung cấp catalog/asset.

## Ma trận kiểm thử bắt buộc (DoD)
- [ ] **Unit test**: Validate IDs duy nhất, tên không rỗng, trạng thái selection nhất quán.
- [ ] **Widget test**: Filter, rarity/owned/locked badges, current selection, tap/select callbacks, empty state, semantics, textScale/Reduced Motion.
- [ ] **Integration test (Device)**: Pixel 7 Pro filter/select nhân vật qua caller seam; không dùng simulator.
- [ ] **Golden test**: Owned/locked/selected, nhiều rarity và empty trên light/dark/vi/RTL/textScale/reducedMotion.
- [ ] **Interruption test**: Đổi filter/unmount khi scroll không giữ selection state cũ hoặc ticker orphan.
- [ ] **Network conditioning test**: N/A — catalog/unlock sync thuộc caller.
- [ ] **Memory leak & profiling test**: MemoryWatchdog trên grid dài sau scroll/unmount.
- [ ] **Frame rate / Jank test**: Scroll 50+ nhân vật, báo FrameTiming p50/p95/p99, slow-frame %, jank count.
- [ ] **IAP & Ad mediation test**: N/A — unlock/purchase logic ở caller.

## Hiệu năng & Animation
- [ ] `GridView.builder` lazy rendering; không decode toàn bộ portrait assets ngoài viewport.
- [ ] Sustained 60 FPS benchmark: chỉ ghi sau đo grid trên thiết bị vật lý.
