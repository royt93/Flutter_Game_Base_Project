---
id: BUG-49
title: "AssetPreloadCoordinator: maxConcurrent=0 gây treo vô hạn (assert-only, mất ở release) + refcount/scene-manifest bug"
type: bug
priority: P0
effort: M
source: "codex + agy (độc lập, 2 khía cạnh khác nhau cùng file), verify lại qua Read lib/core/asset_preload_coordinator.dart:77-100"
---

## Vị trí
`lib/core/asset_preload_coordinator.dart` — constructor (`assert(maxConcurrent >= 1, ...)`, dòng ~81), vòng lặp `preload` dùng `maxConcurrent` để giới hạn batch, `retryFailed()`, `unloadScene()`/`_lastManifest`.

## Hiện trạng
1. **`maxConcurrent` chỉ được bảo vệ bằng `assert`** — bị strip hoàn toàn ở release build. Nếu 1 catalog dựng từ CMS/JSON truyền `maxConcurrent: 0`, vòng lặp `while (ready.isNotEmpty && batch.length < maxConcurrent)` không bao giờ thêm gì vào `batch` (điều kiện `0 < 0` luôn false) — `batch` luôn rỗng, `ready` không bao giờ được rút bớt, vòng `while (ready.isNotEmpty && !_cancelRequested)` bên ngoài lặp vô hạn, treo UI thread.
2. **Scene chỉ lưu 1 `_lastManifest` duy nhất** — preload scene B rồi gọi `unloadScene()` sẽ unload scene B (manifest cuối cùng), không có cách release rõ ràng scene A trước đó nếu 2 scene overlap; `retryFailed()` re-run lại preload cho asset đã load thành công trong cùng retry session thay vì chỉ retry đúng phần thất bại.

## Vì sao cần / Hậu quả
(1) là crash/treo production thật nếu catalog cấu hình sai (dữ liệu remote/CMS, không phải hardcode) — app đơ hoàn toàn ở màn hình loading, không timeout, không thông báo lỗi. (2) làm sai lệch ref-count giữa scene, asset có thể bị unload nhầm hoặc giữ mãi trong bộ nhớ dù không còn scene nào cần.

## Đề xuất
1. Validate `maxConcurrent >= 1` bằng runtime check (`ArgumentError`/`SdkFailure.validation`) trong constructor, không chỉ `assert`. Thêm test `--no-enable-asserts` (hoặc build release-mode equivalent) xác nhận validate vẫn chạy.
2. Đổi `_lastManifest` (1 giá trị) thành map theo `sceneId` (hoặc API `unloadScene(String sceneId)` nhận tham số rõ ràng thay vì ngầm định "scene cuối cùng preload"), sửa `retryFailed` chỉ target đúng `_failedIds` của scene đang retry.

## Acceptance criteria
- [ ] `AssetPreloadCoordinator(maxConcurrent: 0)` throw ngay tại constructor (runtime, không phụ thuộc `assert`), không bao giờ treo vòng lặp `preload`.
- [ ] `AssetPreloadCoordinator(maxConcurrent: -1)` cũng bị chặn tương tự.
- [ ] Preload scene A rồi scene B (2 manifest khác nhau, có thể overlap 1 vài asset chung) — `unloadScene` phải nhận diện đúng scene cần unload, không unload nhầm scene khác.
- [ ] `retryFailed()` chỉ re-attempt đúng asset đã fail trước đó của đúng scene, không load lại asset đã thành công.
- [ ] Test `--no-enable-asserts` (hoặc tương đương) xác nhận validate `maxConcurrent` vẫn hoạt động ở "release-like" mode.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-49-asset-preload-coordinator-bugs.md` này trước khi làm. Đọc toàn bộ `lib/core/asset_preload_coordinator.dart` và test hiện có trước khi sửa — đặc biệt hiểu rõ cơ chế ref-count/cache/dependency-graph đã có trước khi đổi API `unloadScene`/`retryFailed` để tránh phá hành vi đúng hiện tại. Implement bằng TDD, ưu tiên viết test tái hiện treo vô hạn (`maxConcurrent: 0`) trước tiên (dùng `Future.any([...timeout])` để test không treo CI thật nếu fix chưa đúng).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không cần smoke test device bắt buộc (logic thuần, không có UI trực tiếp — cân nhắc thêm vào nếu có demo asset-preload trong example).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao cho bug (1) — tự Read trực tiếp constructor xác nhận `assert(maxConcurrent >= 1, ...)` đúng như mô tả, và logic vòng lặp `batch.length < maxConcurrent` xác nhận treo vô hạn khi `maxConcurrent == 0`. Trung bình cho bug (2) — dựa trên mô tả agy, chưa tự đọc sâu toàn bộ cơ chế ref-count nhiều-scene (effort M, để lại xác nhận chi tiết cho vòng loop implement). Không trùng task nào trong `doc/task/done/`.
