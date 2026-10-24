---
id: IDEA-72
title: "Sprite state animation helper for Flame"
type: idea
layer: presentation/game
priority: P2
effort: M
status: speculative
---

## Giả thuyết

Game consumer có thể cần pattern gọn để ánh xạ trạng thái gameplay (idle/run/hit/win) sang Flame sprite animation mà không lặp state-transition wiring.

## Nền tảng

Package có Flame `RoyGame`, pooled component và asset preload coordinator; chưa thấy API `SpriteAnimation` chuyên dụng.

## Ý tưởng

Khảo sát helper/demo state-to-animation, giữ gameplay state caller-owned và dùng Flame native animation primitives. Không tự quyết định state hoặc gameplay rules thay consumer.

## Discovery gate

- [ ] Xác nhận use case từ consumer/partner hoặc demo requirement cụ thể.
- [ ] Prototype bằng Flame native API trong example trước khi đề xuất public API.
- [ ] Xác định interruption, animation completion, missing asset, pause/resume và reduced-motion behavior.
- [ ] Chỉ tạo FEAT task nếu wrapper giảm code thực sự so với Flame native.

## Prompt loop feature

Đọc `RoyGame`, Flame tests, `AssetPreloadCoordinator` và task `DISC-01`. So sánh dùng Flame native API với helper mới. Không implement trước khi có request/use case cụ thể và người dùng duyệt FEAT task. Khi được duyệt, xác định immutable/caller-owned state, lifecycle, error behavior và test cases; end loop gồm audit diff + score /10, unit/widget/Flame integration tests phù hợp, full analyzer/tests, device smoke nếu UI/device flow liên quan. Nếu score ≤9 thì sửa tiếp; score >9 không tự cấp quyền commit/push. Xin xác nhận trước push; chỉ push sau approval và CI xanh.

## Quyết định

Người dùng duyệt đóng no-go. Flame `1.35.1` đã có `SpriteAnimationComponent`/`SpriteAnimation`; chưa có consumer use case chứng minh package wrapper giảm boilerplate. Dùng native Flame API; mở task mới khi có use case tái hiện cụ thể.
