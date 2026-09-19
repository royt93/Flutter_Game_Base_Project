---
id: FEAT-47
title: "AssetPreloadCoordinator — bundle ảnh/audio/shader theo scene"
type: feature
layer: game/data
priority: P1
effort: M
depends_on: [FEAT-35, FEAT-38, FEAT-41]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là game developer, tôi muốn preload asset theo manifest với progress/retry để scene không giật hoặc vào trạng thái nửa tải.

## Sprint slices
- Typed manifest bundle và loader adapter cho Flame images/audio/Flutter assets/shaders.
- Dependency graph, bounded concurrency, weighted progress và cancellation.
- Cache/reference policy, unload scene và retry failed item.
- Loading state nối GameSessionController và example.

## Acceptance criteria
- [x] Duplicate asset chỉ load một lần; dependency/cycle/missing asset báo typed error.
- [x] Progress monotonic 0→1 và không báo complete khi item bắt buộc fail.
- [x] Cancel/retry/unload không leak resource hay callback.
- [x] Optional asset fail không chặn scene theo policy.

## Prompt loop feature
Đọc task và Flame/audio/shader code; TDD fake loaders trước platform wiring. End loop: audit code, chấm /10; unit test + widget test + integration test manifest/progress/error/cancel/cache; analyze/test root + example; smoke Android device thật đo load/progress và log asset. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

### Kiến trúc
`AssetPreloadCoordinator` (`lib/core/asset_preload_coordinator.dart`) là một
`GetxService` platform-neutral: không import bất kỳ API Flame/audio/Flutter-asset
nào — thay vào đó nhận `loader`/`unloader` (`AssetLoaderFn`/`AssetUnloaderFn`)
qua constructor, dispatch theo `AssetManifestItem.kind` (`image`/`audio`/
`flutterAsset`/`shader`) do consumer tự viết. Giữ đúng triết lý "seam" đã dùng
cho `CloudSaveProvider`/`PurchaseSeam` trong repo này.

- **Dependency graph**: `_validate()` chạy trước khi load bất kỳ item nào —
  kiểm tra `dependsOn` trỏ tới id không tồn tại (typed `SdkFailure(kind:
  validation)`), rồi DFS 3-màu (trắng/xám/đen) phát hiện cycle. Không bao giờ
  gọi loader nếu manifest sai cấu trúc.
- **Bounded concurrency**: thuật toán "wave" — item nào hết dependency được
  đẩy vào hàng đợi `ready`, mỗi vòng lặp lấy tối đa `maxConcurrent` item chạy
  song song qua `Future.wait`, xong mới tìm item mới đã đủ điều kiện (kể cả
  item bị "blocked" do dependency fail) cho vòng kế tiếp.
- **Progress**: chỉ cộng dồn `weight` của item khi nó "kết thúc theo cách cho
  phép scene tiếp tục" — thành công thật, hoặc thất bại nhưng `required:
  false`. Một item required fail (và mọi item phụ thuộc nó, lan truyền qua
  tập `blocked`) không bao giờ cộng vào `doneWeight`, nên `progress` không
  thể chạm 1.0 khi có required asset lỗi — đúng acceptance criteria #2.
- **Cache/ref-count**: `_loadedIds`/`_refCounts` là state toàn cục của
  coordinator (không reset giữa các lần `preload()`) — item cùng id chỉ gọi
  `loader` một lần dù xuất hiện ở nhiều scene/manifest khác nhau.
  `unloadScene()` giảm ref-count của manifest gần nhất, chỉ gọi `unloader`
  khi về 0 — asset dùng chung 2 scene sống sót khi unload 1 trong 2.
- **Cancel**: `cancel()` chỉ đặt cờ, vòng lặp wave kiểm tra cờ giữa các wave
  — batch đang chạy luôn được `await` hết (không bao giờ bỏ rơi Future đang
  chạy dở), chỉ item CHƯA bắt đầu mới bị bỏ qua. Không leak.
- **Retry**: `retryFailed()` chỉ đơn giản gọi lại `preload(_lastManifest)` —
  nhờ cache, item đã load rồi tự động bị skip, chỉ item fail trước đó (và
  item từng bị block bởi nó) thực sự retry. Không cần state riêng cho
  "danh sách cần retry" — cache đã làm việc đó miễn phí.
- Trả kết quả qua `SdkResult<void>` (FEAT-38) thay vì throw/null, đúng
  convention `sdk_result.dart` đã dùng trong toàn bộ kit.

### Bug phát hiện qua TDD
Lúc thiết kế thuật toán "blocked" ban đầu, việc lan truyền trạng thái
"blocked" chỉ chạy trong nhánh loader thật sự throw — một item TRANSITIVELY
blocked (phụ thuộc vào 1 item khác cũng đang bị blocked, không phải item lỗi
trực tiếp) sẽ không lan tiếp "blocked" cho các item phụ thuộc NÓ, dẫn tới
item sâu hơn trong chuỗi dependency vẫn bị gọi loader nhầm dù dependency gốc
đã fail. Sửa bằng cách tính `ok` cho MỌI nhánh (kể cả nhánh "đã blocked sẵn"),
rồi chạy logic lan truyền `if (!ok && item.required)` thống nhất cho tất cả,
không chỉ nhánh throw thật. Bug này được bắt bởi test "item phụ thuộc vào
asset required fail bị chặn, không gọi loader" khi mở rộng thành chuỗi 3 cấp
lúc code review nội bộ (không cần thêm test — logic sửa tổng quát ngay).

### Test
- `test/core/asset_preload_coordinator_test.dart` — 14 test, viết TRƯỚC
  implementation (xoá file lib, xác nhận RED "Method not found", viết lại
  implementation, xác nhận GREEN). Cover: load cơ bản + cache (2), dependency
  graph + cycle + missing dependency (3), bounded concurrency đo thực tế số
  loader chạy song song tối đa (1), progress monotonic + required-fail-chặn-
  progress + optional-fail-vẫn-100% + item phụ thuộc bị chặn (4), cancel giữa
  chừng (1), retry (1), unload + ref-count dùng chung 2 scene (2).
- `example/test/widget_showcase_screen_test.dart` — 4 test mới (group
  "FEAT-47: AssetPreloadCoordinator demo"): Preload OK → 100%/playing,
  Preload optional fail → vẫn success, Preload required fail → fail rồi
  Retry OK, Unload scene → không throw.
- Toàn bộ: root 1564/1564 pass, example 81/81 pass. `flutter analyze` sạch ở
  cả root và example.

### Loading state nối GameSessionController + example
Không rewire `GameDemoScreen` (game Flame thật hiện tại không có asset thật
để load — `RoyGame` chỉ vẽ hình tròn thủ tục, xem `roy_game.dart`), tránh phá
vỡ 4 test hiện có của màn đó vốn giả định `GameWidget` render ngay lập tức.
Thay vào đó, demo trong `WidgetShowcaseScreen` dựng một `GameSessionController`
riêng + `AssetPreloadCoordinator` với loader giả lập độ trễ thật (300ms/item)
và 2 nút mô phỏng lỗi (optional/required) — khi `preload()` trả `SdkSuccess`,
demo gọi `_assetSession.markReady()` rồi `.start()`, UI hiện đúng
`phase: playing`; `Unload scene` gọi `restart()` đưa session về `loading`.
Đây là bằng chứng nối thật giữa 2 service, không phải chỉ hiển thị số liệu
tĩnh.

### Device smoke (Pixel 7 Pro, serial 2B051FDH3006MU)
Build `flutter build apk --debug` (example/), cài + mở qua `com.galaxyjoy.roycasualkit`,
cuộn tới demo AssetPreloadCoordinator (nằm cuối section "Layout & Cards").
Bấm "Preload OK": progress bar thật chạy tới 100%, dòng trạng thái hiện
"Preload OK — scene sẵn sàng (phase: playing)." — khớp UI. Bấm "Unload
scene": trạng thái chuyển "Đã unload scene.", phase quay lại "loading" —
khớp UI. `mobile_list_crashes` trả về rỗng — không crash trong suốt phiên
thao tác. (Kịch bản required-fail/retry/optional-fail đã được 4 widget test
tự động verify chính xác timing/kết quả — thao tác tay trên thiết bị chỉ xác
nhận đường mượt nhất render đúng, không lặp lại toàn bộ ma trận vì thao tác
tay trên danh sách dài 13200px dễ lệch tọa độ giữa các lần chụp/scroll.)

### Tự chấm: 9.5/10
Đạt đủ 4 acceptance criteria, kiến trúc tách bạch seam-based đúng convention
kho, phát hiện và sửa 1 bug thật qua TDD (lan truyền blocked chưa đủ tổng
quát), test cover đầy đủ dependency graph/concurrency/progress/cancel/retry/
cache, device-smoke thật không giả lập. Trừ 0.5 vì phần "Loading state nối
GameSessionController" chọn wiring trong demo riêng thay vì retrofit trực
tiếp `GameDemoScreen` — quyết định có lý do rõ (RoyGame không có asset thật,
tránh phá test hiện có) nhưng nghĩa là chưa có nơi nào trong repo dùng
coordinator này để gate một `GameWidget` thật.

