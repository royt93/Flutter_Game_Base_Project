# Backlog audit 2026-09-22

## Phạm vi và baseline

Đọc toàn bộ `lib/` (162 file `.dart` / 26.191 dòng) và `example/lib/` (7 file / 4.530 dòng), đối chiếu với 253 task đã có trong `doc/task/done/`. 7 nguồn audit độc lập, chạy song song:

1. `codex exec --dangerously-bypass-approvals-and-sandbox` — đọc `CLAUDE.md`, toàn bộ `lib/core/`+`lib/core/utils/`, 4 widget/game presentation, `example/lib/main.dart` + 5 screen.
2. `agy --dangerously-skip-permissions -p` — đọc toàn bộ `lib/core/` (61 service), `lib/core/utils/` (23 util), `lib/presentation/widgets/` (59 widget), `lib/presentation/game/`, `example/lib/`.
3. `claude --dangerously-skip-permissions -p` — đọc toàn bộ `lib/core/*.dart` (64 file) + `lib/core/utils/*.dart` (23 file) + `lib/presentation/widgets/*.dart` (13 loose + 59 `common/`) + `lib/presentation/game/*.dart` + `example/lib/` + test tương ứng (self-verify từng finding bằng Read/grep trực tiếp trước khi ghi, không suy đoán số dòng).
4. Fork nội bộ — audit `lib/core/*.dart` (61 file, loại `utils/`).
5. Fork nội bộ — audit `lib/core/utils/` + `lib/presentation/widgets/` (ưu tiên file có Timer/AnimationController/StreamSubscription/Ticker).
6. Fork nội bộ — audit `example/lib/` + gap kiểm thử.
7. Fork nội bộ — brainstorm "task/tính năng mới" + "tính năng độc quyền" (verify trước qua `ls lib/core/*.dart` để không đề xuất trùng service đã có).

Bước tổng hợp (fork này): đọc đủ cả 7 nguồn, dedup nghiêm túc (nhiều finding trùng nhau giữa các nguồn — ghi rõ "N nguồn độc lập xác nhận" cho các finding đó, đây là tín hiệu ưu tiên mạnh nhất), tự `Read`/grep lại code thật cho phần lớn bug P0/P1 trước khi viết task (không chỉ chép lại claim của nguồn — vài claim của agy/codex bị lệch số dòng hoặc mô tả sai 1 phần, đã điều chỉnh lại cho khớp code thật), gán ID mới tiếp nối (BUG từ 39, ENH từ 79, FEAT từ 86, IDEA từ 58), bỏ qua các đề xuất mơ hồ/đầu cơ/giá trị thấp so với effort thay vì liệt kê máy móc mọi câu chữ.

## Tổng số task mới theo loại

| Loại | Số lượng | ID |
|---|---|---|
| BUG (bug cần fix) | 31 | BUG-39 → BUG-69 |
| ENH (enhancement) | 10 | ENH-79 → ENH-88 |
| FEAT (tính năng mới + độc quyền) | 10 | FEAT-86 → FEAT-95 |
| IDEA (ý tưởng nhỏ/demo gap) | 10 | IDEA-58 → IDEA-67 |
| **Tổng** | **61** | |

## Danh sách ID mới (tóm tắt 1 dòng/task)

### Bug (P0/P1 đa số — data loss, crash, race condition, accessibility)
- **BUG-39** (P1·M) — `removeAllWithPrefix` xoá/ghi lại toàn bộ SharedPreferences thay vì chỉ prefix.
- **BUG-40** (P0·S) — `_hydrate()` chỉ chạy qua `onInit()`, mất state khi khởi tạo ngoài GetX (PlayerProgression/RewardPipeline/OfflineOutbox).
- **BUG-41** (P1·M) — restore save không cập nhật metadata `SaveSlotManager`, slot mồ côi.
- **BUG-42** (P1·S) — `CheckpointCoordinator` completer bị bỏ rơi khi debounce coalesce.
- **BUG-43** (P0·S) — `ConnectivityCoordinator._runProbe` thiếu catch, crash/kẹt trạng thái mạng.
- **BUG-44** (P1·M) — `OfflineOutboxService`: 3 bug concurrency (mất item mới, evict sai priority, merge unhandled exception).
- **BUG-45** (P1·M) — race `_saving`/`_saveChain` lặp ở 7 service ledger.
- **BUG-46** (P1·S) — `EnergyService` thiếu hoàn toàn save-chain guard.
- **BUG-47** (P1·S) — `kit_bootstrap` throw vi phạm never-throws + bỏ sót gọi `init()`.
- **BUG-48** (P1·XS) — `todayEpochDayClamped()` đếm nhầm mọi lần gọi cùng ngày thành rewind.
- **BUG-49** (P0·M) — `AssetPreloadCoordinator`: `maxConcurrent=0` treo vô hạn + refcount/scene bug.
- **BUG-50** (P1·XS) — `DeepLinkCommandRouter`: query param đè path param.
- **BUG-51** (P1·S) — `InventoryService.consume` resort toàn bộ hòm đồ.
- **BUG-52** (P1·XS) — `grantInfiniteLives` ghi đè thay vì cộng dồn.
- **BUG-53** (P1·XS) — `ObjectPool` dùng equality-Set thay vì `Set.identity()`.
- **BUG-54** (P1·S) — `GameClock` treo vô hạn nếu `fixedStep=0` + không pause đúng phase.
- **BUG-55** (P2·M) — string literal thay vì `StorageKeys` ở 9 service.
- **BUG-56** (P0·XS) — `ShaderTickerLayer` crash "ticker started twice".
- **BUG-57** (P1·XS) — `ToastBanner` leak `AnimationController` khi unmounted.
- **BUG-58** (P1·S) — `FlameTrackedOverlay` toạ độ global thay vì local Stack.
- **BUG-59** (P1·S) — `ShareHelper`: leak `ui.Picture` + thiếu `sharePositionOrigin` (crash iPad).
- **BUG-60** (P0·S) — 4 widget nút bấm chính thiếu `excludeSemantics`, đọc lặp accessibility.
- **BUG-61** (P0·S) — `widget_showcase_screen.dart`: 4 chỗ thiếu mounted-guard + `DeepLinkCommandRouter` thiếu `unregisterHandler`.
- **BUG-62** (P1·S) — `widget_showcase_screen.dart`: `ConnectivityCoordinator` demo giữ tham chiếu cũ.
- **BUG-63** (P1·S) — `widget_showcase_screen.dart`: `OfflineOutboxService` uploader trỏ State cũ.
- **BUG-64** (P1·S) — `CookbookScreen` thiếu `dispose()`, leak `CheckpointCoordinator`.
- **BUG-65** (P1·S) — barrel thiếu export `debug_log.dart`/`debug_qa_overlay.dart`.
- **BUG-66** (P2·XS) — `SeasonEventService.isActive` sai cho sự kiện tương lai.
- **BUG-67** (P2·XS) — `OfflineProgressionService`: người chơi mới nhận 0 thưởng lần đầu (cần điều tra trước khi sửa).
- **BUG-68** (P2·XS) — `RemoteConfigService.initResult` nuốt exception.
- **BUG-69** (P2·XS) — `economy_math.regenEnergy` chia 0 nếu `intervalMs<=0`.

### Enhancement
- **ENH-79** (P1·M) — `AudioManager` cần player pool cho combo SFX dồn dập.
- **ENH-80** (P1·S) — `PerformanceTierService` chưa từng đăng ký/demo trong example (3 nguồn xác nhận).
- **ENH-81** (P1·M) — `PooledComponent` zero usage/demo trong `RoyGame`.
- **ENH-82** (P1·M) — `GameSessionController`/lifecycle/Flame pause không đồng bộ.
- **ENH-83** (P1·M) — `VersionedJsonStore.syncWith` conflict policy không quan sát được.
- **ENH-84** (P1·M) — `RemoteConfigService` cần schema/typed validation.
- **ENH-85** (P1·M) — chuẩn hoá runtime validation cho constructor còn lại (`ReplayRecorder`, `LocalScoreboardService`).
- **ENH-86** (P2·M) — `TrustedClockService` xây xong nhưng không service anti-cheat nào tiêu thụ.
- **ENH-87** (P2·M) — `InAppReviewHelper` không có widget wrapper/demo.
- **ENH-88** (P2·M) — `AssetPreloadCoordinator` cần API theo scene-handle.

### Feature (task mới + tính năng độc quyền)
- **FEAT-86** (P1·M) — `AdMediationSeam` (rewarded/interstitial, mirror `PurchaseSeam`).
- **FEAT-87** (P1·M) — `LeaderboardSyncSeam` (Play Games/Game Center/server riêng).
- **FEAT-88** (P1·L) — Typed game-event bus nối Flame ↔ economy/progression/analytics.
- **FEAT-89** (P1·L) — 🌟 Support Reproduction Capsule (replay+RNG+save+clock, 2 nguồn độc lập đề xuất trùng ý).
- **FEAT-90** (P1·L) — LiveOps shadow activation + auto-rollback theo guardrail kinh tế.
- **FEAT-91** (P1·L) — 🌟 Cheat-Proof Economy Certificate (2 nguồn độc lập đề xuất trùng ý).
- **FEAT-92** (P2·L) — 🌟 Flame-GetX Zero-Jank State Bridge (cần prototype go/no-go trước).
- **FEAT-93** (P1·M) — 🌟 Live-Ops In-App DevTools Sidecar (Time Travel/Network Sim/Variant Switcher).
- **FEAT-94** (P1·M) — `PlayerDataRightsService` (export/xoá dữ liệu, GDPR/CCPA-style).
- **FEAT-95** (P1·M) — `PrestigeService` (cơ chế trùng sinh idle-game kinh điển).

### Idea
- **IDEA-58** (low·S) — `FeatureFlagOverridePanel` trong `DebugQaOverlay`.
- **IDEA-59** (low·S) — Save-health diagnostic card.
- **IDEA-60** (low·S) — Directional screen shake theo vector va chạm Flame.
- **IDEA-61** (low·S) — Smart review funnel (like/dislike trước khi mở store).
- **IDEA-62** (low·S) — Smart push notification theo energy/streak.
- **IDEA-63** (low·S) — Battery saver mode coordinator.
- **IDEA-64** (low·S) — Hiển thị `RoyCasualKitResult` trong `DebugQaOverlay`.
- **IDEA-65** (low·M) — Component Flame thứ 2 (collision/camera-follow) trong `RoyGame`.
- **IDEA-66** (low·L) — Demo/doc hoá luồng save-security đầy đủ (migrate+HMAC+cloud).
- **IDEA-67** (low·S) — `AudioHapticSync` — đồng bộ haptic theo nhịp SFX.

## Đã cân nhắc nhưng KHÔNG tạo task riêng (backlog cho vòng sau nếu cần)

Số lượng finding gốc từ 7 nguồn (~150+) vượt xa số task hợp lý cho 1 đợt scrum — các mục dưới đây được xem xét nhưng **chủ động bỏ qua** (giá trị/effort thấp, đơn nguồn không verify được, hoặc trùng lặp quá nhiều với task đã chọn): `ConsentStateService` cache in-memory, `PurchaseLedgerService` reactivity Rx, API `reset()` chung cho vài service, `RemoteKillSwitchController.isKilled` ghi audit log mỗi lần đọc, `PseudoLocale` không giữ `{placeholder}`, `PauseOverlay` hardcode tiếng Anh, `ToastBanner` thiếu action-button slot, `BottomSheetPanel` thiếu guard `GameWidget`-ancestor, trùng logic particle giữa `ConfettiOverlay`/`RewardPopup`, `WheelSpinner` dùng raw `ArgumentError` thay vì `SdkResult`, `IconBadgeButton` semanticLabel fallback debug, `RemoteConfigService`/`RemoteContentPack` thiếu `retryRemote()`, `SaveSlotManager` thiếu `duplicateSlot()`, `accessibility_audit.dart` không phân biệt `rules: []`, `AsyncActionGuard.runSingleFlight` cast không an toàn khác generic type cùng key, `NeonTheme.lockedBorder/lockedFill` thiếu dark-mode variant, `RetryExecutor.nextDelay` hiển thị sai lệch ~20% so với delay thật, `AppVersionGate` so sánh semver prerelease sai (string thay vì numeric), `SaveIntegrity` HMAC canonicalize không đệ quy cho nested map, `NeonDialog.show` double-pop, `InventoryGrid` không kéo-thả được vào ô trống, `PauseOverlay` overflow landscape, và các task/tính năng lớn hơn (Offline Reward Multiplier Dialog, Gacha Kit, Audio Pitch Escalation Combo, Battle Pass/Season Journey, Self-Balancing Economy Autopilot, Anti-Bot Fingerprint, Golden-Path Regression Player, ExperimentRemoteKillOverride, CrashFreeSessionRateCollector, ServerTimeSyncService, CloudSaveConflictResolver-pluggable, WheelSpinner double-spin — đã xác nhận là hành vi ĐÃ ĐƯỢC REVIEW và CHỦ ĐỘNG GIỮ NGUYÊN trong `BUG-34` done trước đó, không phải gap mới).

## Các phương án để owner chọn

| Option | Nội dung | Ưu điểm | Nhược điểm |
|---|---|---|---|
| **A — Reliability first (khuyến nghị)** | Ưu tiên toàn bộ P0 (BUG-40/43/49/56/60/61) → race/data-loss P1 quan trọng nhất (BUG-39/41/42/44/45/46/54) → phần còn lại của BUG theo P1/P2 | Loại bỏ rủi ro mất dữ liệu/crash thật trước — đây là loại lỗi nghiêm trọng nhất tìm thấy (nhiều hơn hẳn đợt audit 09-12), một số đã được 2-3 nguồn độc lập xác nhận nên độ tin cậy rất cao | Backlog ENH/FEAT/IDEA (differentiator, genre-fit) bị đẩy lùi, chưa có tiến triển sản phẩm mới trong đợt này |
| **B — Balanced (bug quan trọng + 1 differentiator)** | Toàn bộ P0 BUG trước, sau đó chọn 1 FEAT differentiator có 2 nguồn xác nhận độc lập (FEAT-89 Reproduction Capsule HOẶC FEAT-91 Economy Certificate) làm song song với phần BUG còn lại | Vẫn ưu tiên an toàn nhưng có 1 điểm nhấn sản phẩm mới ngay trong đợt này, tận dụng đúng lúc tín hiệu "2 AI độc lập cùng nghĩ ra ý tưởng giống nhau" | Cần điều phối 2 luồng công việc song song (bug-fix + feature mới), rủi ro conflict nếu cả 2 đụng chung file (ví dụ cả 2 đều liên quan `save_integrity.dart`) |
| **C — Genre-completeness push** | Ưu tiên FEAT-95 (Prestige) + FEAT-86/87 (Ad/Leaderboard seam) + ENH-80 (PerformanceTierService demo, 3-nguồn) trước, xen kẽ đúng các BUG P0 (không thể bỏ qua) | Nhanh chóng lấp gap thể loại "idle/casual SDK" rõ ràng nhất, tăng sức hấp dẫn cho tích hợp viên mới ngay | Vẫn còn nhiều P1 bug (race condition, leak) tồn tại lâu hơn trong lúc chờ; rủi ro 1 dev tích hợp mới gặp đúng 1 trong các bug đó trước khi được fix |

**Khuyến nghị: Option A.** Đây là đợt audit tìm ra SỐ LƯỢNG bug P0/P1 nhiều nhất từ trước tới giờ (31 bug, trong đó có data-loss thật ở `_hydrate()`/BUG-40, treo vô hạn ở 2 nơi/BUG-49+54, và 1 accessibility issue ảnh hưởng gần như mọi màn hình/BUG-60) — nhiều bug được 2-3 nguồn AI độc lập cùng xác nhận, độ tin cậy rất cao. Một package định hướng production-ready nên đóng các lỗ hổng này trước khi đầu tư thêm tính năng mới, đặc biệt vì BUG-40 (mất dữ liệu thật khi khởi tạo service ngoài GetX) ảnh hưởng trực tiếp tới đúng pattern mà 1 file test của chính repo (`player_progression_service_test.dart:147`) đang minh hoạ.

## Quyết định của owner

Owner chọn **Option A — Reliability first** (2026-09-22). Thứ tự thực thi:
1. P0: BUG-40, BUG-43, BUG-49, BUG-56, BUG-60, BUG-61.
2. P1 race/data-loss quan trọng nhất: BUG-39, BUG-41, BUG-42, BUG-44, BUG-45, BUG-46, BUG-54.
3. Phần BUG P1 còn lại, rồi BUG P2.
4. Sau khi backlog BUG cạn: quay lại ENH/FEAT/IDEA theo P1 trước P2.

## Definition of Done dùng chung (không đổi so với đợt 09-12)

Mỗi task là 1 file riêng trong `doc/task/todo/`. Loop chỉ kết thúc khi agent tự audit changes và đạt >9/10, có unit + widget + integration test cho mọi case, `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root và `example/`, smoke test trên Android device thật có bằng chứng (khi task đổi hành vi quan sát được), rồi mới `git commit` + `git push`. Sau push, cập nhật mục `## Quyết định`/tick checkbox, chuyển file sang `doc/task/done/` bằng `git mv`, commit + push lần hai.
