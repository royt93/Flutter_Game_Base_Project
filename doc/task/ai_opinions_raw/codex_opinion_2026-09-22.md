# Independent audit — 2026-09-22

Phạm vi đã đọc: `CLAUDE.md`, toàn bộ `lib/core/` và `lib/core/utils/`, các
widget/game presentation được yêu cầu, cùng `example/lib/main.dart` và các
screen ví dụ. `flutter analyze` hiện sạch; các điểm dưới đây là lỗi hành vi/
API có thể tái hiện, không suy ra từ warning tĩnh hay backlog cũ.

## 1. Bug cần fix

### 1.1 Restore dữ liệu slot nhưng không restore metadata slot

- **Priority P1 · Effort M** — [disaster_recovery_save_export.dart:264](../../../lib/core/disaster_recovery_save_export.dart#L264), [save_slot_manager.dart:70](../../../lib/core/save_slot_manager.dart#L70), [save_slot_manager.dart:175](../../../lib/core/save_slot_manager.dart#L175)
- `applyRestore` chỉ gọi `importWithPrefix` cho các key của slot. `SaveSlotManager.listSlots()` lại chỉ đọc danh sách metadata riêng ở `save_slot_meta_v1`; không có API nào ở luồng restore ghi `entry.meta` vào danh sách đó.
- Tái hiện: export `slot_123`, cài app/fresh profile không có slot này, `previewRestore` rồi `applyRestore`. Các key `slot_slot_123_*` đã nằm trên disk, nhưng `listSlots()` không trả slot; người chơi không thể chọn nó qua API công khai. Với collision, metadata cũ cũng có thể hiển thị tên/thời gian sai so với data vừa import.
- Fix: thêm API restore/upsert metadata được tuần tự hoá trong `SaveSlotManager`, xác định rõ policy collision (replace/rename/reject), và commit metadata cùng bước restore (có recovery journal nếu cần). Test fresh target, replace target, và failure giữa data/metadata.

### 1.2 `maxConcurrent: 0` làm preloader quay vòng vô hạn ở release

- **Priority P0 · Effort S** — [asset_preload_coordinator.dart:77](../../../lib/core/asset_preload_coordinator.dart#L77), [asset_preload_coordinator.dart:125](../../../lib/core/asset_preload_coordinator.dart#L125)
- Constructor chỉ dùng `assert(maxConcurrent >= 1)`. Assert bị bỏ ở bản release. Khi manifest không rỗng và `maxConcurrent == 0`, vòng trong không lấy phần tử nào vào `batch`; `Future.wait([])` hoàn thành ngay, `ready` vẫn nguyên, rồi vòng ngoài lặp vô hạn, khóa isolate/UI.
- Tái hiện: app production tạo `AssetPreloadCoordinator(loader: ..., maxConcurrent: 0).preload([item])` (giá trị có thể đến từ build flag/remote setup).
- Fix: runtime-validate `maxConcurrent >= 1` và `AssetManifestItem.weight.isFinite && weight > 0`; trả `ArgumentError` ở constructor hoặc `SdkFailure.validation`. Thêm test chạy không dựa vào assert.

### 1.3 Catalog item invalid có thể treo vòng grant inventory

- **Priority P0 · Effort S** — [inventory_service.dart:16](../../../lib/core/inventory_service.dart#L16), [inventory_service.dart:259](../../../lib/core/inventory_service.dart#L259)
- `ItemDefinition.maxStack` chỉ được bảo vệ bằng assert. Ở release, `maxStack: 0` đi tới `add = min(0, remaining)`, sau đó `remaining -= add` không đổi, nên `while (remaining > 0)` không bao giờ kết thúc.
- Tái hiện: catalog được dựng từ CMS/JSON có một item `maxStack: 0`, rồi gọi `grant` với quantity dương cho item đó. App freeze trước khi trả `SdkResult`.
- Fix: validate runtime `id.trim().isNotEmpty`, `maxStack > 0`, `capacity > 0` khi khởi tạo service/catalog; phòng thủ thêm trong `grant` để trả `SdkFailure.validation` thay vì loop. Thêm product-mode test cho `maxStack` bằng 0 và âm.

### 1.4 Hai lệnh cooldown liên tiếp có thể ghi snapshot cũ đè snapshot mới

- **Priority P1 · Effort M** — [persistent_cooldown_service.dart:54](../../../lib/core/persistent_cooldown_service.dart#L54), [persistent_cooldown_service.dart:70](../../../lib/core/persistent_cooldown_service.dart#L70), [persistent_cooldown_service.dart:125](../../../lib/core/persistent_cooldown_service.dart#L125), [storage_service.dart:241](../../../lib/core/storage_service.dart#L241)
- `start`/`cancel` đọc-đổi-ghi blob riêng, nhưng `_persist` bỏ qua `Future` của `setString`. Hai write async không được xếp hàng; completion của snapshot cũ có thể đến sau snapshot mới.
- Tái hiện: `start('daily_reward', 10m)` rồi lập tức `cancel('daily_reward')`; ép write đầu hoàn thành sau write hai. Sau restart, cooldown đã bị hủy lại xuất hiện và khóa reward.
- Fix: đổi mutation thành `Future`, giữ state cache trong service và đưa mọi persist qua một save chain/revision; caller quan trọng phải await. Test với storage fake dùng completer đảo thứ tự completion.

### 1.5 Regen energy và consume cùng dùng snapshot stale

- **Priority P1 · Effort M** — [energy_service.dart:54](../../../lib/core/energy_service.dart#L54), [energy_service.dart:72](../../../lib/core/energy_service.dart#L72), [energy_service.dart:133](../../../lib/core/energy_service.dart#L133), [energy_service.dart:193](../../../lib/core/energy_service.dart#L193)
- Getter `currentEnergy` gọi `_regen`, còn `consumeEnergy` cũng gọi `_regen`; cả hai fire-and-forget `_writeState` rồi đọc lại storage thay vì state trong memory. Một snapshot refill và một snapshot spend có thể ghi đảo thứ tự.
- Tái hiện: energy còn 1, đã đủ một refill tick; đọc `currentEnergy` (queue write count=2) rồi ngay `consumeEnergy()` (queue write count=1). Nếu write refill về sau, lần mở app kế tiếp có thêm một energy không đúng (đảo thứ tự khác có thể làm mất state mới hơn).
- Fix: chuyển state thành single in-memory source of truth, serialize transition + persist, và để mutation quan trọng trả `Future`; getters không được tạo write không chờ. Thêm test completion đảo thứ tự và test read/consume burst.

### 1.6 Claim lần đầu bị báo là “streak reset”

- **Priority P2 · Effort S** — [daily_login_service.dart:242](../../../lib/core/daily_login_service.dart#L242), [daily_login_service.dart:257](../../../lib/core/daily_login_service.dart#L257)
- Fresh state dùng `lastClaimedEpochDay == -1`. Vì vậy `continuesStreak` false và `streakWasReset` true, trái với mô tả chỉ reset khi đã bỏ lỡ ngày kể từ *lần claim trước*.
- Tái hiện: fresh install gọi `claimToday()`: kết quả day 1 nhưng `streakWasReset: true`; UI dùng cờ này sẽ chạy thông báo/animation “mất streak” ngay lần đầu.
- Fix: tách `hasPreviousClaim = lastClaimedEpochDay >= 0`; chỉ reset khi có previous claim và không liên tiếp. Thêm test fresh claim, consecutive claim, skipped-day claim.

### 1.7 Preview restore nhận backup không thể import được

- **Priority P2 · Effort S** — [disaster_recovery_save_export.dart:32](../../../lib/core/disaster_recovery_save_export.dart#L32), [disaster_recovery_save_export.dart:226](../../../lib/core/disaster_recovery_save_export.dart#L226), [storage_service.dart:303](../../../lib/core/storage_service.dart#L303)
- `SlotExportEntry.fromJson` chỉ kiểm tra `data` là Map. `previewRestore` vì vậy trả success cho value như List/map/null, nhưng `StorageService.importAll` chỉ cho phép int/bool/double/String và sẽ ném `FormatException` lúc apply. Preview đã hứa validated nhưng UI chỉ biết lỗi sau khi người dùng xác nhận restore.
- Tái hiện: một export đã được ký hợp lệ từ tool/support nhưng data có `{ "some_key": [] }`; preview thành công, apply thất bại ở slot đầu.
- Fix: dùng cùng validator value-type khi parse entry, kiểm tra prefix từng key và duplicate slot id trước preview; trả `SdkFailure.validation` trước khi có thao tác ghi. Test malformed-but-signed bundle.

### 1.8 Capacity không hợp lệ làm reward pipeline mất record pending

- **Priority P1 · Effort S** — [reward_transaction_pipeline.dart:133](../../../lib/core/reward_transaction_pipeline.dart#L133), [reward_transaction_pipeline.dart:207](../../../lib/core/reward_transaction_pipeline.dart#L207)
- `capacity` không runtime-validated. Với `capacity: 0`, `_upsert` thêm record pending rồi xóa toàn bộ record ngay tại `removeRange`; trường hợp partial sau một line wallet thành công không còn record để `resumePending` tìm lại. Capacity âm còn có thể tạo range invalid.
- Tái hiện: khởi tạo pipeline production bằng config 0, grant nhiều reward lines và làm line thứ hai fail; audit storage rỗng, retry không thể resume transaction đã partial.
- Fix: reject `capacity <= 0` trong constructor; không evict `pending/partial` trước khi terminal, hoặc tách retention của audit completed. Thêm test capacity zero/negative và eviction khi transaction partial.

## 2. Enhancement cần làm

### 2.1 Cho cloud save một conflict policy có quan sát được

- **Priority P1 · Effort M** — [versioned_json_store.dart:143](../../../lib/core/versioned_json_store.dart#L143)
- Hiện tại last-write-wins chỉ dựa `syncedAtMs`; timestamp bằng nhau tự chọn local rồi upload lại. Với clock lệch hoặc offline edits trên hai thiết bị, host không có callback để hiển thị “giữ bản nào”, log telemetry, hay merge domain data.
- Bổ sung `SyncConflict<T>` và strategy/callback (`preferLocal`, `preferCloud`, `manual`, `merge`) cùng checksum/device/revision metadata. Viết test equal timestamp, skewed clock, callback throw, và cloud malformed.

### 2.2 Remote config cần schema/ràng buộc typed và diagnostic result thật

- **Priority P1 · Effort M** — [remote_config_service.dart:72](../../../lib/core/remote_config_service.dart#L72), [remote_config_service.dart:104](../../../lib/core/remote_config_service.dart#L104), [remote_config_service.dart:119](../../../lib/core/remote_config_service.dart#L119)
- Asset/fetch error đều bị nuốt trong `init`, vì vậy `initResult()` thực tế hầu như luôn success; các getter primitive cũng không biết range/enum/shape hợp lệ. Đây là gap boundary, nhất là khi config điều khiển economy/feature flag.
- Thêm `RemoteConfigSchema` (type, required, min/max/allowed enum), report các key bị reject và một init outcome phân biệt asset-missing, remote-failed, remote-applied. Example nên có screen mô phỏng remote config sai và fallback.

### 2.3 Sửa lifecycle ownership của deep-link stream ở example

- **Priority P2 · Effort S** — [example/lib/main.dart:110](../../../example/lib/main.dart#L110), [example/lib/main.dart:114](../../../example/lib/main.dart#L114), [example/lib/main.dart:180](../../../example/lib/main.dart#L180)
- `AppLinks().uriLinkStream.listen(...)` không giữ `StreamSubscription`; trong khi comment chính thừa nhận `app()` có thể chạy nhiều lần trong cùng process. Mỗi invocation thêm listener không thể cancel, làm một deep link có thể dispatch nhiều lần trong test/hot-restart-like setup.
- Đưa subscription vào một lifecycle service có `dispose`, hoặc giữ singleton/subscription và guard một lần; thêm widget/integration test gọi bootstrap hai lần rồi gửi một URI.

### 2.4 Chuẩn hóa runtime validation cho public constructor config

- **Priority P1 · Effort M** — [asset_preload_coordinator.dart:21](../../../lib/core/asset_preload_coordinator.dart#L21), [replay_recorder.dart:160](../../../lib/core/replay_recorder.dart#L160), [local_scoreboard_service.dart:44](../../../lib/core/local_scoreboard_service.dart#L44)
- Nhiều service public vẫn chỉ dùng `assert` cho invariant. Ngoài các crash/hang đã nêu, `ReplayRecorder(capacity: 0)` sẽ modulo 0 tại record; `LocalScoreboardService(capacity: 0)` có semantics âm thầm drop mọi submit.
- Lập một convention: public config phải runtime-check và có test `--no-enable-asserts`; dùng `ArgumentError` cho programmer API và `SdkFailure.validation` cho input runtime. Đây cũng là test matrix chung cho toàn bộ core.

### 2.5 Preloader cần API theo scene handle thay vì một `_lastManifest`

- **Priority P2 · Effort M** — [asset_preload_coordinator.dart:98](../../../lib/core/asset_preload_coordinator.dart#L98), [asset_preload_coordinator.dart:103](../../../lib/core/asset_preload_coordinator.dart#L103), [asset_preload_coordinator.dart:209](../../../lib/core/asset_preload_coordinator.dart#L209)
- Service nói cache/ref-count shared giữa scene, nhưng chỉ lưu một `_lastManifest`; preload scene B rồi `unloadScene()` sẽ unload B, không thể release rõ ràng scene A và concurrent preload cũng ghi đè manifest/cancel flag.
- Trả `AssetSceneLease`/token từ `preload`, với `lease.release()` idempotent; tách job-local progress/cancel. Thêm test A/B shared asset, release đúng thứ tự, two concurrent jobs và cancellation.

## 3. Task/tính năng mới nên thêm

### 3.1 Game-event bridge có type từ Flame sang economy/progression

- **Priority P1 · Effort L** — [roy_game.dart:1](../../../lib/presentation/game/roy_game.dart#L1), [economy_wallet.dart:1](../../../lib/core/economy_wallet.dart#L1)
- Thêm bridge khai báo `GameEvent`/command typed (tap, collision, level-complete, ad-reward) từ `FlameGame` component tree sang `EconomyWallet`, achievement, quest và analytics. Cần idempotency key/frame/session ID, queue khi app paused, và adapter mẫu trong example.
- SDK đã có các service business rời rạc; bridge này giảm đáng kể glue code dễ double-grant mà vẫn không áp gameplay cụ thể lên game host.

### 3.2 Privacy data-rights workflow hoàn chỉnh

- **Priority P1 · Effort M** — [consent_state_service.dart:1](../../../lib/core/consent_state_service.dart#L1), [storage_service.dart:338](../../../lib/core/storage_service.dart#L338), [diagnostics_export_bundle.dart:1](../../../lib/core/diagnostics_export_bundle.dart#L1)
- Thêm `PlayerDataRightsService`: preview/export dữ liệu theo category, one-tap erase có countdown/confirm, receipt sau erase, hook để app xóa cloud/analytics identity. Consent và erase storage đã có primitive, nhưng chưa thành luồng data-subject có thể ship.

### 3.3 Handoff save an toàn qua QR/deep-link cho đổi máy

- **Priority P1 · Effort L** — [disaster_recovery_save_export.dart:97](../../../lib/core/disaster_recovery_save_export.dart#L97), [deep_link_command_router.dart:1](../../../lib/core/deep_link_command_router.dart#L1)
- Thêm transfer session một-lần: encrypt export bằng key exchange/expiry, chunk QR hoặc deep link, preview slot conflict, acknowledge rồi invalidate token. Đây là use case đổi thiết bị/offline support khác với signed manual export hiện tại.

### 3.4 Pacing experiment harness có simulation snapshot

- **Priority P2 · Effort M** — [energy_service.dart:124](../../../lib/core/energy_service.dart#L124), [daily_login_service.dart:242](../../../lib/core/daily_login_service.dart#L242), [remote_config_service.dart:64](../../../lib/core/remote_config_service.dart#L64)
- Thêm API headless để chạy cohort/config qua nhiều ngày giả lập: energy, login, cooldown, quest/reward; xuất histogram wait-time, sources/sinks currency và invariant violations. Nó biến remote tuning thành thay đổi có thể so sánh/review trước rollout.

## 4. Idea mới đáng cân nhắc

### 4.1 Save-health card cho Settings/QA overlay

- **Priority P2 · Effort S** — [save_integrity.dart:1](../../../lib/core/save_integrity.dart#L1), [diagnostics_export_bundle.dart:1](../../../lib/core/diagnostics_export_bundle.dart#L1)
- Hiển thị lần save/flush gần nhất, schema version, số key, slot active, checksum status và action “copy support capsule”. Giá trị chính là rút ngắn triage support; không nên biến thành UI bắt buộc cho mọi game.

### 4.2 Clock anomaly policy thống nhất

- **Priority P2 · Effort M** — [game_time_controller.dart:1](../../../lib/core/game_time_controller.dart#L1), [persistent_cooldown_service.dart:81](../../../lib/core/persistent_cooldown_service.dart#L81), [daily_login_service.dart:246](../../../lib/core/daily_login_service.dart#L246)
- Thay các call wall-clock rời rạc bằng policy phát hiện rollback/jump lớn, có action per feature (freeze, clamp, server-check). Casual game rất hay gặp đổi giờ máy; idea này nên pilot ở energy/cooldown trước.

### 4.3 Accessibility gameplay preset có thể lưu/export

- **Priority P2 · Effort M** — [neon_theme.dart:1](../../../lib/core/neon_theme.dart#L1), [example/lib/main.dart:117](../../../example/lib/main.dart#L117)
- Mở rộng color-blind setting hiện có thành preset gồm reduced motion, haptic/audio intensity, hold duration, font scale, high contrast; widget/game overlay đọc một profile chung. Nên giữ opt-in để không ép style lên host.

### 4.4 QA scenario runner dựa trên replay capsule

- **Priority P2 · Effort M** — [replay_recorder.dart:146](../../../lib/core/replay_recorder.dart#L146), [debug_qa_overlay.dart:1](../../../lib/presentation/widgets/debug_qa_overlay.dart#L1)
- Cho phép lưu các scenario JSON có seed/events/assert checkpoint và chạy chúng từ debug overlay/CI. Đây là bước nhỏ, thực dụng hơn một full visual test framework.

## 5. Tính năng độc quyền (competitive differentiator)

Đối chiếu công khai cho thấy Flame tập trung game loop/component/overlay, còn Get tập trung state/DI/route; không package nào trong hai nền tảng này quảng bá workflow casual-game end-to-end dưới đây ([Flame](https://docs.flame-engine.org/), [Get](https://pub.dev/packages/get)). Nhận định “độc quyền” ở đây là lợi thế của một SDK casual tổng hợp, không phải khẳng định không có một repository private nào từng làm điều tương tự.

### 5.1 Support Reproduction Capsule: replay + save + config tối giản, có privacy redaction

- **Priority P1 · Effort L** — [replay_recorder.dart:146](../../../lib/core/replay_recorder.dart#L146), [disaster_recovery_save_export.dart:97](../../../lib/core/disaster_recovery_save_export.dart#L97), [diagnostics_export_bundle.dart:1](../../../lib/core/diagnostics_export_bundle.dart#L1)
- Đóng gói đúng phần cần tái hiện một lỗi: RNG seed/event trace, active save slot, remote-config hash, device/time anomaly và log lỗi; tự redact PII, size-budget, encrypt, rồi cung cấp importer chạy deterministic. SDK đã có primitive riêng lẻ, nhưng một capsule support-first có reproduction verdict sẽ khác biệt rõ so với engine/state-manager chung.

### 5.2 LiveOps “shadow activation” có rollback theo outcome game economy

- **Priority P1 · Effort L** — [remote_config_service.dart:72](../../../lib/core/remote_config_service.dart#L72), [remote_content_pack.dart:1](../../../lib/core/remote_content_pack.dart#L1), [remote_kill_switch_controller.dart:1](../../../lib/core/remote_kill_switch_controller.dart#L1)
- Trước khi activate config/content mới, client chạy validator + pacing simulation trên snapshot local, áp vào cohort nhỏ, theo dõi guardrail (grant failure, currency delta, crash/retry), rồi tự rollback bằng kill switch/version pin khi vượt ngưỡng. Flame/Get chỉ cung cấp nền; “safe live tuning for idle economy” là pain point chuyên biệt và đáng thành signature feature.

### 5.3 Progression Safety Net: ledger bất biến + proof-of-play tùy chọn

- **Priority P1 · Effort L** — [reward_transaction_pipeline.dart:120](../../../lib/core/reward_transaction_pipeline.dart#L120), [economy_wallet.dart:1](../../../lib/core/economy_wallet.dart#L1), [save_integrity.dart:1](../../../lib/core/save_integrity.dart#L1)
- Tạo event ledger hash-chain cho mọi thay đổi progression/economy, checkpoint bằng HMAC/server nonce tùy chọn, và trình reconcile khôi phục transaction partial hoặc gắn cờ tamper mà không khóa oan người chơi offline. Điểm khác biệt là cân bằng anti-cheat, offline-first và support recovery trong một API casual-friendly — vượt ra ngoài những gì engine/DI package phổ biến cung cấp.
