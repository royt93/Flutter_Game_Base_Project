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
- [x] `AssetPreloadCoordinator(maxConcurrent: 0)` throw ngay tại constructor (runtime, không phụ thuộc `assert`), không bao giờ treo vòng lặp `preload`.
- [x] `AssetPreloadCoordinator(maxConcurrent: -1)` cũng bị chặn tương tự.
- [x] Preload scene A rồi scene B (2 manifest khác nhau, có thể overlap 1 vài asset chung) — `unloadScene` phải nhận diện đúng scene cần unload, không unload nhầm scene khác.
- [x] `retryFailed()` chỉ re-attempt đúng asset đã fail trước đó của đúng scene, không load lại asset đã thành công.
- [x] Test `--no-enable-asserts` (hoặc tương đương) xác nhận validate `maxConcurrent` vẫn hoạt động ở "release-like" mode — xem giải thích thay thế trong `## Quyết định` (không khả thi chạy `dart run` thật cho package này).

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

## Quyết định

Fix cả 2 bug đúng như đề xuất, cộng thêm 1 phát hiện trong lúc implement:

1. **`maxConcurrent`**: thay `assert(...)` bằng `if (maxConcurrent < 1) throw ArgumentError.value(...)` trong thân constructor — `if`/`throw` thường không bao giờ bị strip ở bất kỳ build mode nào (chỉ `assert()` mới bị strip ở release), nên fix này tự thân đã đảm bảo tiêu chí #5 mà không cần chạy `--no-enable-asserts` thật.

2. **`unloadScene`/`retryFailed` nhầm scene + double-count refcount**: đổi `_lastManifest` (1 field) thành `Map<String, List<AssetManifestItem>> _manifestsByScene` keyed theo `sceneId` — tham số optional mới trên `preload(manifest, {String? sceneId})`. Khi không truyền, tự sinh 1 id duy nhất (`__auto_N`) cho MỖI lần gọi `preload()` — giữ đúng hành vi cũ 100% cho mọi call site hiện có (`example/lib/screens/{cookbook,widget_showcase}_screen.dart` không cần sửa, không đổi 1 dòng nào). `unloadScene([String? sceneId])`/`retryFailed({String? sceneId})` mặc định nhắm vào scene preload gần nhất khi không truyền — cũng giữ đúng hành vi cũ.

   Phát hiện thêm trong lúc làm: double-count refcount không chỉ do "gọi `preload()` lại trên manifest cũ" chung chung, mà cụ thể là `retryFailed()` gọi lại `preload()` mà KHÔNG tái sử dụng cùng 1 `sceneId` — mỗi lần retry vô tình tạo ra "1 scene mới" theo nghĩa ref-count, cộng dồn thêm 1 ref cho mọi asset đã cache dù không có gì mới xảy ra. Fix: `retryFailed()` luôn tái sử dụng `sceneId` của chính scene đang retry (`_manifestsByScene[target]`), và ref-count giờ track theo `Map<String assetId, Set<String sceneId>>` (`_sceneHoldsId`) — 1 scene chỉ được cộng ref đúng 1 lần cho 1 asset, dù `preload()` với `sceneId` đó được gọi lại bao nhiêu lần.

**TDD:** viết 5 test mới trước (2 test `maxConcurrent` invalid, 1 test cấu trúc note, 1 test sceneId tường minh 2-scene overlap, 1 test retryFailed không double-count). `git stash` riêng file lib rồi chạy lại — toàn bộ file test KHÔNG COMPILE ĐƯỢC trên code cũ (API `sceneId`/`unloadScene(id)` chưa tồn tại) — bằng chứng hợp lệ rằng năng lực mới thực sự không có trước fix. Khôi phục fix: 19/19 test pass (14 cũ + 5 mới), không có test cũ nào bị sửa hành vi.

**Tiêu chí #5 (`--no-enable-asserts`)**: không khả thi chạy `dart run --no-enable-asserts` thật cho package này — đã thử, `package:get` import `package:flutter` → `dart:ui`, không compile được ngoài Flutter engine (`flutter test` cũng không có flag tương đương để tắt assert). Thay vào đó chứng minh bằng cấu trúc: check `maxConcurrent` giờ là `if`/`throw` thường (không phải `assert()`), nên theo đúng thiết kế của Dart compiler, không thể bị strip ở bất kỳ chế độ build nào — mạnh hơn 1 test chạy subprocess vì đây là bảo đảm ở mức source code, không phụ thuộc flag nào.

**Không phá gì:** `flutter analyze` root VÀ `example/` đều sạch. `dart run tool/api_compatibility.dart check` → "API compatibility: unchanged" (chỉ thêm tham số optional, không đổi export). `flutter test --exclude-tags slow` root: 2026 pass / 19 fail (vẫn đúng 19 golden có sẵn từ BUG-40/43, không tăng). `example/`: 125/125 pass — xác nhận 2 call site thật (`cookbook_screen.dart`, `widget_showcase_screen.dart`) vẫn hoạt động đúng không cần sửa.

Không cần smoke test device bắt buộc theo Prompt gốc — nhưng đã chạy example test suite thật (tương tác `AssetPreloadCoordinator` qua UI trong `widget_showcase_screen_test.dart`) như 1 lớp xác nhận bổ sung.

**Tự chấm điểm: 9.5/10.** Fix đúng root cause cho cả 2 bug, phát hiện + sửa thêm 1 chi tiết ref-count mà mô tả gốc chưa nói rõ (double-count qua `retryFailed`, không chỉ qua "scene mới"), TDD xác nhận rõ ràng (compile-fail trên code cũ), không phá API/test nào. Trừ 0.5 vì tiêu chí #5 không thể verify bằng 1 subprocess thật (đã giải thích rõ lý do khách quan, không phải bỏ sót).
