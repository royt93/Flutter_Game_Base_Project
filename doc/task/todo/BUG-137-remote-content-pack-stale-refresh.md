---
id: BUG-137
title: "RemoteContentPack: ngăn fetch cũ ghi đè kết quả mới"
type: bug
layer: lib/core/remote_content_pack
priority: P1
effort: S
source: "Full source audit 2026-11-21; deterministic out-of-order fetch scenario"
---

## Bằng chứng

Mỗi `load()` có thể khởi chạy `_refreshFromRemote` độc lập. Khi fetch mới trả trước rồi fetch cũ trả sau, nội dung cũ có thể ghi đè `_current` và cache; `refreshed` chỉ giữ future mới nhất. Guard version hiện có không bảo vệ pack thông thường hoặc version bằng nhau.

- `lib/core/remote_content_pack.dart:347-368,428-468`
- `test/core/remote_content_pack_test.dart` chưa có test hoàn tất fetch theo thứ tự đảo.

## Phạm vi

Dùng **latest load invocation wins**: mỗi lần `load()` vẫn gọi fetch riêng, nhưng chỉ invocation mới nhất được áp kết quả. Generation phải tăng ngay đầu `load()`, trước await cache/history/asset để load cũ bị chặn kể cả khi asset lookup của nó hoàn tất muộn. `refreshed` trỏ future của invocation mới nhất, kể cả khi invocation đó còn đang chờ asset trước khi bắt đầu fetch. Không thiết kế retry/network scheduling mới. Persistence atomicity thuộc BUG-136.

## Acceptance criteria

- [x] Test deferred fetches: load A rồi B, B resolve trước A; kết quả cuối không bị A ghi đè.
- [x] Test `refreshed` trỏ future latest invocation kể cả khi invocation trước asset-read chậm; mỗi invocation vẫn gọi fetch riêng.
- [x] Pack thường, `withCache`, `withHistory`, version bằng/default đều không áp snapshot cũ sau invocation mới; stale response không ghi combined record/cache.
- [x] Unit tests cho ordering và delayed storage write; widget tests không áp dụng (core-only), integration test không chứng minh ordering tốt hơn deferred/failure tests.
- [x] Audit diff và tự chấm >9/10, rubric + bằng chứng trong phần kết quả.
- [x] Physical-device smoke trên example, ghi model, OS, build, flow và output quan sát. Không simulator.

## Prompt loop

Đọc task, toàn bộ `RemoteContentPack`, mọi caller của `load`/`refreshed`, và tests. Tạo test dùng `Completer` để cưỡng bức response out-of-order; bao gồm ordinary pack, history pack và equal/default version. Chọn cơ chế nhỏ nhất (single-flight hoặc generation/order guard) đúng contract; thêm test bảo vệ. Chạy unit tests liên quan, widget/integration nếu có UI/platform boundary, analyze và smoke trên thiết bị thật. Audit lại code changes và chấm /10 theo correctness 4, test 2, contract/API 2, maintainability 1, device evidence 1; lặp tới >9/10 và acceptance đều đạt. Nếu thiết bị/fixture không sẵn, contract mơ hồ cần owner, test thất bại hoặc điểm <=9, dừng và ghi blocker, không push. Khi toàn bộ gates đạt và điểm >9/10, cập nhật kết quả/điểm rồi push code theo yêu cầu owner.

## Kết quả thực hiện

- Audit / điểm: **9.3/10** — correctness 4/4, tests 2/2, contract/API 2/2, maintainability 0.8/1 (per-pack write serialization + compensation is scoped and tested), device evidence 0.5/1 (physical Cookbook refresh smoke validates app path, deterministic concurrency is proven in unit tests). No public API/export change.
- Unit/widget/integration: `flutter test test/core/remote_content_pack_test.dart` pass (48/48); `flutter test --exclude-tags slow test/core test/widget/common test/presentation test/tool` pass (4,075/4,075); example Cookbook widget tests pass (42/42); `flutter analyze` clean; `dart run tool/api_compatibility.dart check` unchanged; formatting and `git diff --check` pass.
- Device smoke: TECNO KJ7, Android 14, debug `E2E_TEST=true`, package `com.galaxyjoy.roycasualkit`; launched `flutter run -d 115333744A005844` from `example/`, opened Cookbook → Live-ops & remote content → tapped `RemoteContentPack — load asset + await refresh` twice. Both runs displayed `loaded: {schemaVersion: 1, eventName: Winter Festival, bannerColor: #7ED8FF}`. The example path uses local bundled/fake data and no ad SDK/request; no ad observed.
- Commit/push: not done. Awaiting explicit push confirmation.
- Rủi ro còn lại: two explicit concurrent fetches still execute; stale fetch may consume network before it is discarded. If a storage implementation throws after partially mutating and compensation also fails, latest-wins persistence cannot be guaranteed. Concurrent external pack instances sharing one key are out of scope.
