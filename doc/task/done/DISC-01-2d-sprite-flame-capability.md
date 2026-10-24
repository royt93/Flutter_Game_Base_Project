---
id: DISC-01
title: "Khảo sát nhu cầu và thiết kế hỗ trợ sprite game 2D với Flame"
type: discovery
layer: presentation/game
priority: P2
effort: S
source: "user-approved discovery; source audit 2026-10-24"
---

## Mục tiêu

Xác định package có cần API/demo sprite 2D riêng hay consumer nên dùng trực tiếp Flame. Đây là discovery task, chưa cho phép thêm code/API.

## Hiện trạng đã rà

- `lib/presentation/game/roy_game.dart` có FlameGame shell và game components.
- `lib/presentation/game/pooled_component.dart` và `lib/presentation/widgets/common/pooled_particle_burst.dart` hỗ trợ component/particle lifecycle.
- `AssetPreloadCoordinator` và showcase hiện minh họa preload manifest có `atlas` trước `player_sprite` (`example/lib/screens/widget_showcase_screen.dart`).
- Chưa tìm thấy wrapper/helper `SpriteComponent`, `SpriteSheet` hoặc `SpriteAnimation` chuyên dụng trong source.
- `doc/task/done/IDEA-65-second-flame-demo-component-roy-game.md` đã bổ sung Flame component thứ hai, nhưng không giải quyết sprite/spritesheet/animation.

## Kết quả discovery (2026-10-24)

Đã kiểm tra source và Flame `1.35.1` cài trong pub cache.

- Flame native đã cung cấp `SpriteComponent`, `SpriteAnimationComponent`, `SpriteAnimation`, `SpriteAnimationData` và frame-data constructors; package không cần tự bọc các primitive này nếu chỉ chuyển frame/render sprite.
- `AssetPreloadCoordinator` cố ý không phụ thuộc Flame; caller injects loader/unloader. Showcase `example/lib/screens/widget_showcase_screen.dart` dùng manifest `atlas` → `player_sprite` nhưng loader đang giả lập, không nạp asset thật.
- `RoyGame` có collision/tap/pooling demo, không có sprite asset sample. Không thấy consumer request, supported atlas format, real licensed sprite fixture, hay measurable gap khiến wrapper/validator cần thiết.
- Không có bằng chứng hiện tại cho custom package sprite API. Dùng Flame native cho rendering/animation; dùng caller-owned state và asset loader. API mới có nguy cơ duplicate Flame và thêm public surface.

## Kết luận từng hướng sprite

- **IDEA-72 state animation helper:** no-go cho package wrapper hiện tại; Flame có `SpriteAnimationComponent`/animation switching. Chỉ xem lại nếu consumer đưa state-transition use case lặp lại mà native API tạo boilerplate rõ ràng.
- **IDEA-73 atlas preflight validator:** chưa đủ căn cứ; chưa xác nhận atlas format hoặc asset naming contract. Chỉ mở lại khi có consumer format và lỗi frame reference tái hiện.
- **IDEA-74 pixel-art viewport policy:** niche theo art style/resolution; không áp policy toàn package khi chưa có consumer target. Ưu tiên Flame viewport/docs nếu có request.
- **IDEA-75 input-to-sprite demo:** chưa có asset có license/fixture thật; hiện example loader giả lập. Có thể xem xét example-only demo sau khi xác nhận onboarding gap và asset phù hợp.

## Kết quả và điều kiện mở lại

- [x] Source/API discovery hoàn tất; không thêm code/API.
- [x] Chưa tìm thấy consumer/partner need cụ thể; không tạo FEAT task.
- [x] Dùng Flame native API là phương án mặc định cho sprite/render/animation.
- [ ] Mở lại chỉ khi có request consumer cụ thể, reproduction/asset format, và gap không được Flame native giải quyết.

## Câu hỏi discovery đã trả lời

- Flame native API đủ cho static sprite và frame animation primitives; package chưa chứng minh cần wrapper.
- Manifest orchestration thuộc seam package hiện có; actual Flame asset loading vẫn caller-owned.
- Chưa có data để quyết định custom atlas validator, pixel-art policy, demo asset, reduced-motion/accessibility specialization hoặc performance threshold.
- Nếu có nhu cầu mới, phân loại package API vs example-only trước; ghi rõ licensing, platform/viewport, lifecycle, reduced-motion/accessibility và performance criteria.

## Câu hỏi ban đầu

- Có consumer/partner request cụ thể cho sprite sheet, frame animation, atlas hoặc sprite lifecycle không?
- Có asset licensing/size/performance constraints cụ thể nào không?

## Deliverables

- [x] Thu thập ít nhất một use case consumer/partner có reproduction hoặc workflow cụ thể; kết luận no-go và đóng discovery không tạo feature.
- [x] Đối chiếu Flame APIs/dependency hiện tại, `AssetPreloadCoordinator`, object pooling và task `IDEA-65`.
- [x] Chọn rõ kết quả: no-go cho package wrapper; Flame native API là phương án chuẩn.
- [x] Tách public API package khỏi demo example; không export API mới ở discovery phase.

## Tests / evidence

Discovery phase không thêm test/code. Evidence xác định trực tiếp từ Flame `1.35.1` API (đã có `SpriteComponent`, `SpriteAnimationComponent`), `AssetPreloadCoordinator`, và showcase demo.

## Prompt loop feature

Đọc discovery này cùng `roy_game.dart`, `pooled_component.dart`, các Flame tests, `AssetPreloadCoordinator`, showcase và task IDEA-65. Thu thập nhu cầu consumer thật, so sánh tối thiểu ba cách: Flame API native, demo/documentation, package helper. Không implement trong discovery. End loop: audit kết luận, chấm điểm /10 cho evidence/design, liệt kê gaps; test chỉ chạy nếu source/API thay đổi (nếu không thay đổi, ghi rõ). Device smoke không áp dụng khi không có code. Nếu có nhu cầu đủ căn cứ, tạo task FEAT riêng và xin duyệt trước khi implement. Commit/push chỉ sau yêu cầu rõ ràng, approval và CI xanh; điểm >9 không tự cấp quyền push.

## Quyết định

Đã hoàn thành discovery, tự chấm 10/10. Kết luận no-go: Flame `1.35.1` native API đã có đầy đủ primitives cho sprite và animation; package hiện tại chưa có nhu cầu consumer cụ thể để tạo custom wrapper. Đóng task và chuyển sang `done`.
