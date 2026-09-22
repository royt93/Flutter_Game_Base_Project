---
id: ENH-88
title: "AssetPreloadCoordinator cần API theo scene-handle thay vì API ngầm định 1 _lastManifest"
type: enhancement
priority: P2
effort: M
source: "codex (độc lập) — mở rộng thiết kế sau khi BUG-49 đã fix các bug cụ thể nhất trên cùng file"
---

## Vị trí
`lib/core/asset_preload_coordinator.dart` — API `preload`/`unloadScene`/`retryFailed` hiện dựa vào khái niệm ngầm "scene gần nhất" thay vì handle tường minh.

## Hiện trạng
BUG-49 đã fix các bug cụ thể (maxConcurrent=0 treo, retryFailed/scene-overwrite sai) trên cùng file này bằng cách sửa tối thiểu. Nhưng thiết kế API tổng thể vẫn dựa vào "scene cuối cùng preload" ngầm định thay vì 1 handle/id tường minh cho mỗi scene — mọi cải tiến tương lai (nhiều scene preload song song, undo/redo scene transition...) sẽ tiếp tục khó vì thiếu khái niệm handle rõ ràng.

## Vì sao cần / Hậu quả
Khi game có > 2 scene preload chồng lấn (ví dụ preload scene B trong lúc scene A vẫn active để transition mượt), API hiện tại không đủ biểu cảm để quản lý đúng ref-count từng scene độc lập — thiết kế lại 1 lần cho đúng sẽ rẻ hơn vá thêm nhiều lần nữa.

## Đề xuất
Đổi `preload(manifest)` trả về 1 `AssetSceneHandle` (hoặc nhận `sceneId` tường minh) — mọi API sau đó (`unloadScene`, `retryFailed`, `progress`) thao tác qua handle/id này thay vì ngầm định "gần nhất". Giữ 1 overload/tiện ích tương thích ngược cho usage đơn-scene hiện tại (không breaking).

## Acceptance criteria
- [ ] API mới cho phép quản lý ĐỘC LẬP ref-count của 2+ scene preload chồng lấn nhau.
- [ ] Usage đơn-scene hiện tại (như `example/` đang dùng, nếu có) không cần đổi code, hoặc chỉ cần đổi tối thiểu với migration rõ ràng.
- [ ] Test verify 2 scene overlap không còn bug "unload nhầm scene" (regression test cho đúng bug đã fix ở BUG-49, giờ verify qua API mới).
- [ ] `dart run tool/api_compatibility.dart check`/`snapshot` cập nhật nếu export mới.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-88-asset-preload-coordinator-scene-lease-api.md` này trước khi làm. Đọc toàn bộ `lib/core/asset_preload_coordinator.dart` (đặc biệt các thay đổi đã áp dụng ở BUG-49, làm SAU BUG-49 nếu có thể) và mọi usage hiện tại trước khi đổi API. Implement bằng TDD. Cân nhắc (ponytail) — đây là effort M, chỉ redesign phần thực sự cần cho multi-scene, không thêm tính năng speculative khác.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`.
4. Không cần smoke test device bắt buộc (logic thuần, trừ khi có demo asset-preload thật trong example).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — codex mô tả hợp lý phần thiết kế mở rộng, đã đối chiếu với BUG-49 (đã verify code thật) để đảm bảo không trùng lặp phạm vi. Effort M vì đây là redesign API, không phải bug fix — nên cân nhắc kỹ độ ưu tiên so với nhu cầu thật của consumer (nhiều scene overlap có thể chưa phải nhu cầu cấp thiết). Không trùng task nào trong `doc/task/done/`.
