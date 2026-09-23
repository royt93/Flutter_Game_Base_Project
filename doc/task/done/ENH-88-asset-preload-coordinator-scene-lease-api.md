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
- [x] API mới cho phép quản lý ĐỘC LẬP ref-count của 2+ scene preload chồng lấn nhau.
- [x] Usage đơn-scene hiện tại (như `example/` đang dùng, nếu có) không cần đổi code, hoặc chỉ cần đổi tối thiểu với migration rõ ràng.
- [x] Test verify 2 scene overlap không còn bug "unload nhầm scene" (regression test cho đúng bug đã fix ở BUG-49, giờ verify qua API mới).
- [x] `dart run tool/api_compatibility.dart check`/`snapshot` cập nhật nếu export mới.

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

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Phát hiện quan trọng khi Read lại code trước khi implement**: phần lớn
đề xuất của task này (đổi từ "scene gần nhất" ngầm định sang `sceneId`
tường minh cho `preload`/`unloadScene`/`retryFailed`, ref-count độc lập
theo từng scene) **ĐÃ ĐƯỢC BUG-49 LÀM RỒI** — code hiện tại đã có
`preload(manifest, {String? sceneId})`, `_manifestsByScene`,
`_sceneHoldsId` (ref-count theo scene id), `unloadScene([String?
sceneId])`, `retryFailed({String? sceneId})`, đều hoạt động đúng, có test
regression riêng (`BUG-49: sceneId tường minh...`). Task này ban đầu (viết
trước BUG-49 fix xong) không biết điều đó.

**Phần THẬT SỰ còn thiếu (đúng như đề xuất có nhắc tới nhưng BUG-49 chưa
đụng)**: `progress` — field `RxDouble` DUY NHẤT dùng chung cho MỌI lời gọi
`preload()`, bất kể scene nào. Khi 2 scene preload thật sự CHỒNG LẤN
(gọi `preload()` không await tuần tự — đúng use case chính task mô tả:
preload scene B trong lúc scene A còn active), cả 2 cùng ghi đè lên field
`progress` chung này — scene xong trước "làm giả" progress thành 1.0 dù
scene kia chưa xong gì cả. Đây là lỗ hổng thật, cụ thể, verify được bằng
test — đúng phạm vi effort M của task, KHÔNG cần dựng thêm 1
`AssetSceneHandle` object mới (đề xuất tự cho phép chọn "hoặc nhận
sceneId tường minh" — đã có sẵn, chỉ cần áp dụng nốt cho `progress`).

**Implement**: thêm `Map<String, RxDouble> _progressByScene` + method
public `RxDouble progressOf(String sceneId)` (tạo lazy qua
`putIfAbsent`, mặc định `0.0.obs` cho sceneId chưa từng preload). Trong
`preload()`, tại mọi điểm ghi `progress.value` (reset về 0.0 đầu hàm,
early-return `1.0` cho manifest rỗng, cập nhật theo `doneWeight/totalWeight`
trong wave loop) đều ghi tương ứng vào `sceneProgress` (biến cục bộ trỏ
đúng entry của `resolvedSceneId` trong `_progressByScene`). Field `progress`
cũ GIỮ NGUYÊN 100% hành vi (không xoá, không đổi semantics) — chỉ bổ sung
doc comment nói rõ nó là "shared, đúng cho usage 1-scene-tại-1-thời-điểm,
không tin cậy được khi có > 1 scene preload chồng lấn thật sự, dùng
`progressOf` thay thế cho trường hợp đó".

**Không đổi `cancel()`/`_cancelRequested`**: vẫn là flag CHUNG (chưa theo
scene) — nằm ngoài phạm vi đề xuất gốc (chỉ nêu đích danh `unloadScene`/
`retryFailed`/`progress` cần theo sceneId, không nhắc `cancel`), và AC1
chỉ yêu cầu "ref-count" độc lập (đã có từ BUG-49) — không mở rộng thêm
tính năng speculative ngoài yêu cầu, đúng tinh thần ponytail đã ghi ngay
trong chính Prompt của task.

**TDD**: viết test dùng `progressOf` trước, chạy → fail biên dịch
("Method 'progressOf' isn't defined") trên code cũ (`git stash` riêng
`lib/core/asset_preload_coordinator.dart`), khôi phục, chạy lại — pass.
2 test mới nhóm "ENH-88": (1) fire `preload(A)`/`preload(B)` KHÔNG await
tuần tự (A gate bằng `Completer`, B load ngay) — verify field `progress`
chung bị B "đánh lừa" thành 1.0 dù A chưa xong gì (chứng minh đúng bug,
ghi rõ đây là hành vi ĐÃ CÓ SẴN giữ nguyên để backward-compat, không phải
lỗi mới), còn `progressOf('A')`/`progressOf('B')` báo đúng độc lập từng
scene; (2) unload đúng theo sceneId khi 2 scene KHÔNG chung asset được
preload chồng lấn thật (B còn treo dở khi A đã unload xong) — regression
mở rộng đúng bug BUG-49 đã fix, giờ verify dưới điều kiện concurrency
THẬT thay vì sequential-await như test BUG-49 gốc.

Lưu ý: bản nháp đầu của test (2) có gate cả asset `shared` dùng chung 2
scene — gây deadlock thật (scene A tự block chính nó khi cùng cố load
'shared') — phát hiện qua timeout 30s khi chạy test, sửa lại bằng 2 scene
KHÔNG chung asset nào để tránh nhầm giữa 2 lớp bug khác nhau (ref-count
asset dùng chung — đã có test riêng BUG-49 — và thứ tự concurrency —
việc test (2) này thực sự nhắm tới).

**Kết quả**: `flutter analyze` sạch cả root lẫn `example/`. `flutter test
--exclude-tags slow` root: 2249 test (+2 đúng số test mới), 19 fail —
khớp baseline golden-image, không fail mới. `example/`: 142/142 pass
(không đổi gì ở `example/`, không có demo asset-preload multi-scene mới —
`AssetPreloadCoordinator (FEAT-47)` demo có sẵn vẫn dùng single-scene, đúng
AC2 "usage đơn-scene không cần đổi code"). `dart run
tool/api_compatibility.dart check` → `unchanged` — đúng kỳ vọng, tool chỉ
scan symbol class/enum/top-level trong file export trực tiếp, không scan
method mới trên class đã có sẵn (giống hệt ENH-86's `trustedClock` param).

Tự chấm: **9.5/10** — xác định đúng phần CÒN THỪA thật sự (không làm lại
việc BUG-49 đã xong), fix đúng trọng tâm effort M, TDD chứng minh cả lỗi
gốc lẫn fix đúng dưới điều kiện concurrency thật (không phải sequential-
await giả), phát hiện và sửa đúng 1 bug thiết kế test (deadlock) trước khi
nộp. Trừ 0.5 vì `cancel()` vẫn chưa theo scene (documented, ngoài phạm vi
AC nhưng là giới hạn còn tồn tại của thiết kế multi-scene tổng thể).
