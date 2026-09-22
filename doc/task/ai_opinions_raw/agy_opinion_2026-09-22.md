# Báo Cáo Audit Độc Lập `roy_casual_kit` (AGY Opinion)
**Agent:** `agy` (Antigravity Agent)  
**Ngày audit:** 2026-09-22  
**Đối tượng audit:** Toàn bộ `lib/core/` (61 services), `lib/core/utils/` (23 utils), `lib/presentation/widgets/` (loose + `common/`, 59 widgets), `lib/presentation/game/`, và `example/lib/` (main.dart + 5 screens).

---

## 1. Bug cần fix

### 1.1. Core Data Loss & Storage Bugs

#### BUG-01: Nguy cơ xóa sạch toàn bộ SharedPreferences khi xóa Save Slot trong `removeAllWithPrefix`
- **Vị trí:** `lib/core/storage_service.dart:359-368`, `412-434`
- **Mức độ & Effort:** **Priority: P0 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - `SaveSlotManager.deleteSlot(slotId)` gọi `StorageService.removeAllWithPrefix('slot_${id}_')`.
  - `removeAllWithPrefix` gọi `importAll(remaining)`, và `importAll` gọi `_replaceAll`.
  - Trong `_replaceAll` (`lib/core/storage_service.dart:415-417`):
    ```dart
    for (final key in prefs.getKeys().toList()) {
      await prefs.remove(key);
    }
    ```
    Hàm thực hiện xóa lần lượt từng key một trên toàn bộ `SharedPreferences` của app (bao gồm cài đặt âm thanh, ngôn ngữ, theme, tất cả các save slot khác, tiến trình offline, v.v.), sau đó mới ghi lại các key còn lại.
  - Do `SharedPreferences` không có cơ chế transaction nguyên tử (atomic), nếu ứng dụng bị OS kill (low memory), crash hoặc mất nguồn ngay giữa vòng lặp xóa, toàn bộ dữ liệu của người chơi sẽ bị xóa sạch vĩnh viễn mà không thể rollback! Ngoài ra việc này gây bão IPC I/O native không đáng có chỉ để xóa vài key.
- **Cách fix đề xuất:**
  Xóa trực tiếp các key khớp với `prefix`, không đụng đến các key khác:
  ```dart
  Future<void> removeAllWithPrefix(String prefix) async {
    if (prefix.isEmpty) throw ArgumentError.value(prefix, 'prefix', 'must not be empty');
    _buffer.removeWhere((k, _) => k.startsWith(prefix));
    final prefs = _prefs;
    if (prefs != null) {
      final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } else {
      _fallback.removeWhere((k, _) => k.startsWith(prefix));
    }
  }
  ```

---

#### BUG-02: Mất trắng dữ liệu / Ghi đè file lưu khi khởi tạo trực tiếp ngoài GetX (`_hydrate()` trong `onInit()`)
- **Vị trí:**
  - `lib/core/player_progression_service.dart:206-210`
  - `lib/core/reward_transaction_pipeline.dart:177-180`
  - `lib/core/offline_outbox_service.dart:236-238`
- **Mức độ & Effort:** **Priority: P0 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Cả 3 service này đặt logic `_hydrate()` trong lifecycle hook `onInit()` của GetX.
  - `onInit()` chỉ được gọi tự động khi service được đăng ký thông qua `Get.put()` hoặc `Get.lazyPut()`.
  - Khi service được khởi tạo trực tiếp (như trong widget cục bộ, unit test, hoặc qua DI container ngoài: ví dụ `final pipeline = RewardTransactionPipeline(wallet: wallet)` như trong chính test `player_progression_service_test.dart:147`), `onInit()` hoàn toàn không được gọi.
  - Kết quả: `_records` hoặc `_totalXpEarned` rỗng (0). Khi người chơi gọi `grant()` hoặc `grantXp()`, `_persist()` sẽ lưu state rỗng/1 phần tử đè lên storage hiện tại, xóa sạch lịch sử giao dịch và level của người chơi.
- **Cách fix đề xuất:**
  Gọi `_hydrate()` ngay trong constructor (như `EconomyWallet`) hoặc sử dụng cơ chế lazy hydration khi truy cập lần đầu.

---

#### BUG-03: Disaster Recovery Restore không đăng ký metadata vào `SaveSlotManager` khiến slot bị mồ côi
- **Vị trí:** `lib/core/disaster_recovery_save_export.dart:264-297`
- **Mức độ & Effort:** **Priority: P0 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Trong `applyRestore(RestorePreview preview)`, vòng lặp import các entry dữ liệu vào storage theo prefix:
    ```dart
    await storage.importWithPrefix(
      slotManager.keyFor(entry.meta.id, ''),
      entry.data,
    );
    ```
  - Tuy nhiên, danh sách slot hiển thị của `SaveSlotManager` được lưu riêng tại key `save_slots_meta_v1` (`lib/core/save_slot_manager.dart:73`).
  - `applyRestore` hoàn toàn không ghi hay cập nhật `entry.meta` vào `SaveSlotManager`.
  - Hậu quả: Quá trình khôi phục báo `SdkSuccess`, nhưng khi người chơi mở giao diện chọn nhân vật/slot thì danh sách vẫn trống rỗng vì metadata chưa từng được cập nhật vào danh sách slot của manager.
- **Cách fix đề xuất:**
  Bổ sung phương thức `slotManager.restoreSlotMeta(entry.meta)` trong `SaveSlotManager` và gọi phương thức này trong `applyRestore`.

---

#### BUG-04: Race Condition mất item mới trong `OfflineOutboxService` khi `enqueue` đồng thời với `drain`
- **Vị trí:** `lib/core/offline_outbox_service.dart:279-296, 345-346, 392-395`
- **Mức độ & Effort:** **Priority: P1 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - `drain()` đang chạy và đang `await uploader(...)` cho một `item` có key `K` (payload cũ).
  - Cùng lúc đó, caller gọi `enqueue(idempotencyKey: K, payload: newPayload)`. Danh sách `items` cập nhật instance `OutboxItem` mới chứa `newPayload`.
  - `uploader(...)` của payload cũ hoàn tất và trả về `SyncAck()`.
  - Dòng 346 gọi: `await _remove(item.idempotencyKey);`.
  - Hàm `_remove` thực hiện `items.removeWhere((i) => i.idempotencyKey == idempotencyKey)`.
  - Hậu quả: `_remove` xóa luôn `OutboxItem` mới vừa được enqueue với `newPayload`! Dữ liệu mới bị mất hoàn toàn và không bao giờ được sync lên server.
- **Cách fix đề xuất:**
  Trong `_remove`, so sánh đối tượng chính xác:
  ```dart
  items.removeWhere((i) => i.idempotencyKey == item.idempotencyKey && identical(i, item));
  ```

---

#### BUG-05: Eviction sai trong `OfflineOutboxService.enqueue` khi outbox đạt capacity
- **Vị trí:** `lib/core/offline_outbox_service.dart:281-287`
- **Mức độ & Effort:** **Priority: P1 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Khi `next.length >= capacity`, code tìm `lowestIndex` có priority thấp nhất trong danh sách hiện tại và xóa nó:
    ```dart
    var lowestIndex = 0;
    for (var i = 1; i < next.length; i++) {
      if (next[i].priority < next[lowestIndex].priority) lowestIndex = i;
    }
    next.removeAt(lowestIndex);
    ```
  - Code không hề so sánh priority của item mới với item bị xóa. Nếu item mới có priority = 0, còn các item hiện tại có priority = 100, item priority 100 vẫn bị xóa để nhường chỗ cho item priority 0!
  - Ngoài ra, cơ chế này có thể evict cả các item đang ở trạng thái `manualReview: true`, làm mất các conflict đang chờ người dùng xử lý.
- **Cách fix đề xuất:**
  Chỉ evict nếu item mới có priority cao hơn item thấp nhất, và không evict các item đang `manualReview == true`.

---

#### BUG-06: `SaveIntegrity` HMAC canonicalize nông, sai lệch hash đối với nested maps
- **Vị trí:** `lib/core/save_integrity.dart:28-32`
- **Mức độ & Effort:** **Priority: P2 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - `_canonicalize` chỉ sắp xếp các key ở cấp cao nhất (`data.keys.toList()..sort()`).
  - Các nested map bên trong (như metadata, item attributes trong save) không được sort đệ quy.
  - Khi save blob được parse lại hoặc truyền qua các platform, thứ tự key bên trong nested map bị thay đổi, dẫn đến checksum HMAC bị lệch và dữ liệu hợp lệ bị từ chối với lỗi "save corrupted/tampered".
- **Cách fix đề xuất:**
  Viết hàm canonicalize đệ quy sắp xếp tất cả các `Map` lồng nhau trước khi sinh chuỗi JSON tính HMAC.

---

### 1.2. Async, Concurrency & Lifecycle Bugs

#### BUG-07: Completer bị treo vĩnh viễn (Memory/Async Hang) khi debounce trong `CheckpointCoordinator`
- **Vị trí:** `lib/core/checkpoint_coordinator.dart:100-105` & `95-98, 204`
- **Mức độ & Effort:** **Priority: P0 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Trong `requestCheckpoint({bool critical = false})`:
    ```dart
    _debounceTimer?.cancel();
    final completer = Completer<SdkResult<int>>();
    _debounceTimer = _createTimer(debounceWindow, () {
      completer.complete(flushNow());
    });
    return completer.future;
    ```
  - Nếu Call site A gọi `requestCheckpoint()`, `completer_A` được tạo.
  - Khi timer chưa hết hạn, Call site B gọi tiếp `requestCheckpoint()`. Lệnh `_debounceTimer?.cancel()` hủy timer cũ, tạo `completer_B` mới.
  - `completer_A` bị bỏ rơi vĩnh viễn (never completed). Call site A await mãi mãi, gây leak luồng async.
  - Tương tự khi gọi `critical: true` hoặc `onClose()`, timer bị hủy nhưng completer đang chờ không bao giờ được complete.
- **Cách fix đề xuất:**
  Duy trì danh sách `final _pendingCompleters = <Completer<SdkResult<int>>>[];`. Khi timer kích hoạt hoặc `flushNow()` chạy, complete toàn bộ completers đang chờ.

---

#### BUG-08: Thiếu `catch` block trong `ConnectivityCoordinator._runProbe` gây crash unhandled error và kẹt trạng thái mạng
- **Vị trí:** `lib/core/connectivity_coordinator.dart:193-213`
- **Mức độ & Effort:** **Priority: P0 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Trong `_runProbe()`:
    ```dart
    try {
      final ok = await probe();
      ...
    } finally {
      _probeInFlight = false;
    }
    ```
  - Trong môi trường thực tế, probe kiểm tra internet (HTTP HEAD hoặc Socket) khi mất mạng/lỗi DNS sẽ ném ngoại lệ (`SocketException`, `TimeoutException`).
  - Do chỉ có `try...finally` mà không có `catch`, exception thoát ra ngoài lệnh gọi `unawaited(_runProbe())` gây crash app hoặc kích hoạt Flutter uncaught error handler.
  - Hơn nữa, `_consecutiveFailures` không được tăng, `_setState` không được gọi, khiến coordinator kẹt ở `checking` hoặc `online` vĩnh viễn dù thiết bị đã mất mạng hoàn toàn.
- **Cách fix đề xuất:**
  Thêm khối `catch` bọc `await probe()`, ghi nhận ngoại lệ tương đương `ok = false`.

---

#### BUG-09: Unhandled Exception trong `OfflineOutboxService` khi conflict merge re-upload gặp lỗi mạng
- **Vị trí:** `lib/core/offline_outbox_service.dart:361-372`
- **Mức độ & Effort:** **Priority: P1 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Trong `_handleConflict()` nhánh `ConflictPolicy.merge` (dòng 363):
    ```dart
    final merged = merger!(item.payload, remote);
    final retryOutcome = await uploader(merged, item.idempotencyKey);
    ```
    Lệnh gọi `uploader()` thứ hai này không nằm trong `_retryExecutor.run()` và không có `try/catch`.
  - Nếu mạng chập chờn hoặc timeout lúc re-upload, exception sẽ ném ra ngoài `unawaited(drain())`, gây unhandled asynchronous exception crash ứng dụng.
- **Cách fix đề xuất:**
  Bọc lệnh gọi `uploader` thứ hai trong `_retryExecutor.run()` hoặc `try/catch`.

---

#### BUG-10: Race Condition và Task Orphaning trong Save-Chain của nhiều Core Services
- **Vị trí:**
  - `lib/core/achievement_service.dart:119-127, 169-172`
  - `lib/core/daily_login_service.dart:201-211, 280`
  - `lib/core/daily_quest_service.dart:143-156`
  - `lib/core/local_scoreboard_service.dart:185`
  - `lib/core/onboarding_coordinator_service.dart:150-153`
  - `lib/core/save_slot_manager.dart:159-161`
  - `lib/core/season_event_service.dart:154`
- **Mức độ & Effort:** **Priority: P1 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Mẫu code: `_saveChain = _saving ? _saveChain.then((_) => _runSave()) : _runSave();`
  - Trong `_runSave()`: `finally { _saving = false; }`.
  - Khi Future của lần save trước kết thúc, khối `finally` chạy đồng bộ đặt `_saving = false`. Microtask `.then` tiếp theo chưa kịp chạy.
  - Nếu có thao tác save mới ngay khoảnh khắc này, `_saving` là `false`, code gọi `_saveChain = _runSave()`. Chuỗi `_saveChain` cũ bị mồ côi (orphaned), hai tác vụ save chạy song song ghi đè disk, và `debugPendingSaves` mất dấu tác vụ trước.
- **Cách fix đề xuất:**
  Bỏ cờ `_saving`, dùng queue tuần tự chuẩn: `_saveChain = _saveChain.then((_) => _runSave(), onError: (_) {});`.

---

### 1.3. Core Logic, Math & Bootstrap Bugs

#### BUG-11: `RoyCasualKit.initialize` ném `ArgumentError` vi phạm cam kết "Never Throws" & Quên gọi `init()` của `AudioManager` và `WakeLockService`
- **Vị trí:** `lib/core/kit_bootstrap.dart:84-88, 122-130, 158-166`
- **Mức độ & Effort:** **Priority: P1 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  1. `kit_bootstrap.dart:87`:
     ```dart
     if (requested.contains(RoyCasualKitModule.locale) &&
         !requested.contains(RoyCasualKitModule.storage) &&
         !Get.isRegistered<StorageService>()) {
       throw ArgumentError('locale module requires storage module');
     }
     ```
     CLAUDE.md (dòng 81) cam kết: `RoyCasualKit.initialize` *never throws: a module whose registration throws is recorded in RoyCasualKitResult.errors and status becomes degraded*. Việc ném `ArgumentError` làm crash boot của host app.
  2. `AudioManager` và `WakeLockService` đều có hàm `Future<void> init()` để restore preference từ storage và áp dụng thiết lập (BGM cache, wakelock native). Nhưng `kit_bootstrap.dart` chỉ gọi `Get.put(AudioManager())` và `Get.put(WakeLockService())` mà **không hề gọi `init()`**. Khiến BGM không bao giờ sẵn sàng (`_ready = false`) và màn hình không được giữ sáng khi boot qua bootstrap module.
- **Cách fix đề xuất:**
  Ghi lỗi cấu hình vào `errors[RoyCasualKitModule.locale]` thay vì throw; thêm lệnh `await (service as dynamic).init()` trong bootstrap.

---

#### BUG-12: `clamped_clock.dart:todayEpochDayClamped` đếm nhầm mọi lần gọi trong ngày thành gian lận tua ngược đồng hồ
- **Vị trí:** `lib/core/utils/clamped_clock.dart:52-61`
- **Mức độ & Effort:** **Priority: P1 | Effort: XS**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Đoạn code:
    ```dart
    int todayEpochDayClamped() {
      final current = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
      final maxSeen = StorageService.to.getInt(StorageKeys.maxEpochDaySeen);
      if (current > maxSeen) {
        StorageService.to.setInt(StorageKeys.maxEpochDaySeen, current);
        return current;
      }
      clockRewindBlockedCount++;
      return maxSeen;
    }
    ```
  - Trong suốt 24 giờ của cùng một ngày, `current == maxSeen`!
  - Khi người chơi mở app lần thứ 2 trong ngày, hoặc chuyển màn hình khiến `todayEpochDayClamped()` được gọi lại, điều kiện `current > maxSeen` bị `false`. Nhánh `else` thực thi `clockRewindBlockedCount++;`!
  - Người chơi chơi game hoàn toàn bình thường bị tích lũy hàng chục/hàng trăm lần "chặn hack tua ngược", làm sai lệch chẩn đoán QA và analytics gian lận.
- **Cách fix đề xuất:**
  Chỉ tăng biến đếm khi thời gian thật sự bị lùi:
  ```dart
  if (current < maxSeen) {
    clockRewindBlockedCount++;
  }
  ```

---

#### BUG-13: Rò rỉ RefCount trên `retryFailed()` và đè nhầm `_lastManifest` khi đổi Scene trong `AssetPreloadCoordinator`
- **Vị trí:** `lib/core/asset_preload_coordinator.dart:154-156, 207-225`
- **Mức độ & Effort:** **Priority: P1 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Kịch bản 1: Scene load 2 asset A và B. A thành công (ref=1), B lỗi. Gọi `retryFailed()`: A đã có trong `_loadedIds` nên được coi là thành công, refcount của A bị tăng lên 2. Khi thoát scene gọi `unloadScene()`, ref của A giảm về 1 -> A không bao giờ được giải phóng khỏi RAM.
  - Kịch bản 2: Chuyển Scene 1 sang Scene 2. Gọi `preload(scene2Manifest)`, `_lastManifest` bị ghi đè. Khi Scene 1 unmount và gọi `unloadScene()`, nó duyệt `_lastManifest` của Scene 2 và giải phóng nhầm tài nguyên của Scene 2 vừa tải!
- **Cách fix đề xuất:**
  Không tăng refcount cho asset đã load trong cùng retry session; hỗ trợ `unloadScene([List<AssetManifestItem>? manifest])`.

---

#### BUG-14: `DeepLinkCommandRouter.dispatch` ghi đè Path Params bằng Query Params
- **Vị trí:** `lib/core/deep_link_command_router.dart:77` đối chiếu dòng `29-30`
- **Mức độ & Effort:** **Priority: P1 | Effort: XS**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Doc cam kết: *"a query key never overrides a path param of the same name, since path params are captured first"*.
  - Tuy nhiên tại dòng 77: `params.addAll(uri.queryParameters);` trực tiếp đè lên path params đã parse trước đó.
- **Cách fix đề xuất:**
  Dùng `uri.queryParameters.forEach((k, v) => params.putIfAbsent(k, () => v));`.

---

#### BUG-15: `InventoryService.consume` tự ý sort lại toàn bộ hòm đồ, phá vỡ sắp xếp của người chơi
- **Vị trí:** `lib/core/inventory_service.dart:319-338`
- **Mức độ & Effort:** **Priority: P1 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Khi người chơi dùng 1 vật phẩm, code thực hiện:
    `var scratch = [..._slots]..sort((a, b) => a.slotId.compareTo(b.slotId));` rồi gán lại `_slots = scratch`.
  - Mọi vị trí sắp xếp tùy chỉnh mà người chơi đã kéo thả trước đó bị đảo lộn trở về thứ tự mặc định theo `slotId`.
- **Cách fix đề xuất:**
  Trừ số lượng trực tiếp trên stack tương ứng mà không sort lại danh sách `_slots`.

---

#### BUG-16: `grantInfiniteLives` ghi đè thời gian thay vì cộng dồn (Stacking Bug)
- **Vị trí:** `lib/core/energy_service.dart:99-103`
- **Mức độ & Effort:** **Priority: P1 | Effort: XS**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Khi người chơi đang còn 15 phút vô hạn tim và nhận thêm phần thưởng 30 phút vô hạn tim, hàm ghi: `nowMsClamped() + duration.inMilliseconds`.
  - 15 phút cũ bị ghi đè mất hoàn toàn thay vì được cộng dồn thành 45 phút.
- **Cách fix đề xuất:**
  Lấy mốc cơ sở: `final base = math.max(currentInfiniteUntilMs, nowMsClamped());` rồi cộng thêm duration.

---

#### BUG-17: `ObjectPool` dùng `LinkedHashSet` thay vì `Set.identity()`, phá vỡ cơ chế kiểm tra double-release
- **Vị trí:** `lib/core/utils/object_pool.dart:33, 83`
- **Mức độ & Effort:** **Priority: P1 | Effort: XS**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Doc cam kết kiểm tra identity chứ không dùng equality. Tuy nhiên dòng 33 khai báo `final _active = <T>{};`.
  - Nếu đối tượng `T` (Flame Component, Vector2, v.v.) override `==` và `hashCode`, 2 đối tượng có cùng thuộc tính khi active sẽ gây lỗi phát hiện sai lệch ở `release()`.
- **Cách fix đề xuất:**
  Khai báo `final Set<T> _active = Set<T>.identity();`.

---

#### BUG-18: `SeasonEventService.currentWindow` đảo ngược logic `isActive` cho sự kiện tương lai
- **Vị trí:** `lib/core/season_event_service.dart:158, 171`
- **Mức độ & Effort:** **Priority: P2 | Effort: XS**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Dòng 171: `isActive: now - startMs < length.inMilliseconds`.
  - Với sự kiện chưa diễn ra (`now < startMs`), `now - startMs` là số âm, luôn nhỏ hơn `length`, khiến hàm trả về `isActive == true` cho sự kiện trong tương lai!
- **Cách fix đề xuất:**
  Sửa thành: `isActive: now >= startMs && now < startMs + length.inMilliseconds`.

---

#### BUG-19: Người chơi mới luôn nhận 0 xu thưởng offline lần đầu trong `OfflineProgressionService`
- **Vị trí:** `lib/core/offline_progression_service.dart:42-48, 80-84`
- **Mức độ & Effort:** **Priority: P2 | Effort: XS**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - `StorageKeys.offlineLastClaimedMs` chỉ được lưu khi gọi `claim()`.
  - Người chơi mới cài game chơi 15 phút rồi tắt máy. Lần đầu tiên không có claim nên key = 0.
  - Sau 8 tiếng mở lại game, `saved == 0` khiến hàm trả về `now`, `elapsed = now - now = 0`. Người chơi nhận 0 xu dù đã vắng mặt 8 tiếng.
- **Cách fix đề xuất:**
  Tự động lưu `offlineLastClaimedMs = now` ngay trong lần đầu tiên service được khởi tạo nếu key chưa tồn tại.

---

#### BUG-20: `RemoteConfigService.initResult` nuốt exception và luôn trả về `SdkSuccess`
- **Vị trí:** `lib/core/remote_config_service.dart:72-117`
- **Mức độ & Effort:** **Priority: P2 | Effort: XS**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Hàm `init()` bắt mọi exception và gán `_source = RemoteConfigSource.remoteFailed`.
  - Do đó `initResult()` không bao giờ bắt được exception nào và luôn trả về `SdkSuccess(null)` kể cả khi mất mạng.
- **Cách fix đề xuất:**
  Kiểm tra nếu `_source == RemoteConfigSource.remoteFailed` thì trả về `SdkFailure`.

---

#### BUG-21: `regenEnergy` ném `IntegerDivisionByZeroException` nếu `intervalMs <= 0`
- **Vị trí:** `lib/core/utils/economy_math.dart:38`
- **Mức độ & Effort:** **Priority: P2 | Effort: XS**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Phép tính `(nowMs - lastMs) ~/ intervalMs` không validate `intervalMs > 0`. Truyền 0 sẽ làm crash app ngay lập tức.
- **Cách fix đề xuất:**
  Thêm validation: `if (intervalMs <= 0) throw ArgumentError.value(intervalMs, 'intervalMs', 'must be > 0');`.

---

#### BUG-22: `GameClock` chạy thời gian khi game ở trạng thái `loading`, `ready`, `won`, `lost`
- **Vị trí:** `lib/core/game_time_controller.dart:124-126` & `lib/core/game_time_controller.dart:16-19`
- **Mức độ & Effort:** **Priority: P2 | Effort: XS**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Điều kiện pause chỉ xét `phase == GameSessionPhase.paused`. Nếu game ở `loading`, `ready`, `won`, `lost`, `_clock.paused` vẫn là `false`. Nếu game loop vẫn tick, thời gian chơi tiếp tục tăng sai lệch.
  - Tham số `fixedStep` không assert `> Duration.zero`, truyền `Duration.zero` gây vòng lặp `while` vô tận.
- **Cách fix đề xuất:**
  Gán `_clock.paused = owningSession.snapshot.value.phase != GameSessionPhase.playing;` và assert `fixedStep > Duration.zero`.

---

#### BUG-23: Lệch pha múi giờ giữa UTC Epoch Day và Local Midnight
- **Vị trí:** `lib/core/utils/clamped_clock.dart:53` đối chiếu `lib/core/utils/format.dart:14-22` & `lib/core/daily_login_service.dart:240`
- **Mức độ & Effort:** **Priority: P2 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - `todayEpochDayClamped()` tính ngày theo UTC 00:00. `durationToLocalMidnight()` đếm ngược theo Local 00:00.
  - Ở múi giờ UTC+7 (Việt Nam): Lúc 00:00 nửa đêm local time, widget countdown báo "Đã sang ngày mới!", nhưng `DailyLoginService.canClaimToday()` vẫn trả về `false` trong suốt 7 tiếng tiếp theo (phải đến 07:00 sáng mới nhận được).
- **Cách fix đề xuất:**
  Cung cấp tùy chọn epoch day theo local date hoặc đồng bộ logic đếm ngược theo múi giờ thống nhất.

---

#### BUG-24: Thiếu public getter `currentRunLength` trong `DailyLoginService`
- **Vị trí:** `lib/core/daily_login_service.dart:59-70`, `224-238`
- **Mức độ & Effort:** **Priority: P2 | Effort: XS**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Model `_DailyLoginState` có trường `currentRunLength` lưu số ngày đăng nhập liên tục thực tế (> 7 ngày, theo IDEA-49).
  - Tuy nhiên `DailyLoginService` chỉ expose `currentStreakDay` (1..7) và `longestStreakEver`, hoàn toàn quên viết getter `int get currentRunLength => _state.currentRunLength;`. UI không thể hiển thị chuỗi ngày thực tế.
- **Cách fix đề xuất:**
  Thêm `int get currentRunLength => _state.currentRunLength;`.

---

#### BUG-25: Vi phạm quy ước `StorageKeys` - Sử dụng String Literals rải rác
- **Vị trí:**
  - `lib/core/achievement_service.dart:29` (`'achievement_progress_v1'`)
  - `lib/core/checkpoint_coordinator.dart:45` (`'checkpoint_coordinator_v1'`)
  - `lib/core/daily_login_service.dart:82` (`'daily_login_state_v1'`)
  - `lib/core/daily_quest_service.dart:62` (`'daily_quest_progress_v1'`)
  - `lib/core/economy_wallet.dart:15` (`'economy_wallet_v1'`)
  - `lib/core/inventory_service.dart:110` (`'inventory_service_v1'`)
- **Mức độ & Effort:** **Priority: P2 | Effort: XS**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - CLAUDE.md quy định: *"Never use string literals for prefs keys — add a new named constant in StorageKeys instead"*. Các key trên đang dùng hardcoded string literals làm default thay vì hằng số trong `StorageKeys`.
- **Cách fix đề xuất:**
  Định nghĩa các key tương ứng vào class `StorageKeys` trong `storage_service.dart`.

---

### 1.4. Presentation, Widget & Flame Bugs

#### BUG-26: Crash runtime khi nâng Performance Tier trong `ShaderTickerLayer`
- **Vị trí:** `lib/presentation/widgets/shader_ticker_layer.dart:83`
- **Mức độ & Effort:** **Priority: P0 | Effort: XS**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Khi thiết bị chuyển tier từ `medium` sang `high` (hoặc `tierService.tier` emit lại giá trị không phải `low` trong lúc ticker đã được khởi tạo và đang chạy), nhánh `else` gọi `_ticker!.start();`.
  - Trong Flutter SDK, gọi `Ticker.start()` khi ticker đang active sẽ văng ngay ngoại lệ runtime: `FlutterError: A ticker was started twice. / An active ticker cannot be started again.` làm crash app.
- **Cách fix đề xuất:**
  ```dart
  if (_ticker?.isTicking == false) {
    _ticker!.start();
  }
  ```

---

#### BUG-27: Rò rỉ bộ nhớ `AnimationController` & `Ticker` trong `ToastBanner.show` khi Pop Route
- **Vị trí:** `lib/presentation/widgets/common/toast_banner.dart:101-112`
- **Mức độ & Effort:** **Priority: P1 | Effort: XS**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - `ToastBanner.show()` tạo `AnimationController(vsync: Navigator.of(context))` và hẹn giờ đóng sau `duration`.
  - Trong hàm `remove()`:
    ```dart
    if (!entry.mounted) return;
    try { await controller.reverse(); } catch (_) {}
    entry.remove();
    controller.dispose();
    ```
  - Nếu người dùng chuyển màn hình trước khi toast đóng, `entry.mounted` trở thành `false`. Câu lệnh `if (!entry.mounted) return;` thoát ngay, bỏ qua hoàn toàn `controller.dispose()`. Controller và ticker bị rò rỉ trong bộ nhớ.
- **Cách fix đề xuất:**
  Đảm bảo luôn gọi `controller.dispose()`:
  ```dart
  Future<void> remove() async {
    try {
      if (entry.mounted) {
        await controller.reverse();
        entry.remove();
      }
    } catch (_) {}
    controller.dispose();
  }
  ```

---

#### BUG-28: Lệch toạ độ nghiêm trọng trong `FlameTrackedOverlay` khi Stack không nằm ở gốc màn hình
- **Vị trí:** `lib/presentation/widgets/flame_tracked_overlay.dart:96-126`
- **Mức độ & Effort:** **Priority: P1 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - `renderBox.localToGlobal(Offset.zero)` tính toạ độ góc trên-trái của GameWidget theo toạ độ màn hình gốc (Window Coordinates).
  - Tuy nhiên `FlameTrackedOverlay` trả về `Positioned(left: offset.dx, top: offset.dy)` đặt trong `Stack`.
  - Trong Flutter, `Positioned` nhận toạ độ tương đối với RenderBox của Stack cha, không phải toạ độ màn hình. Nếu Stack nằm dưới `NeonAppBar`, có `SafeArea` hoặc margin, toạ độ bị cộng dồn lệch xuống dưới/sang phải khiến HUD bay lệch khỏi entity game.
- **Cách fix đề xuất:**
  Chuyển đổi toạ độ sang hệ quy chiếu local của Stack:
  ```dart
  final stackBox = context.findRenderObject() as RenderBox?;
  final gameWidgetTopLeft = stackBox != null 
      ? stackBox.globalToLocal(renderBox.localToGlobal(Offset.zero))
      : renderBox.localToGlobal(Offset.zero);
  ```

---

#### BUG-29: Rò rỉ native Skia `ui.Picture` và Crash trên iPad trong `ShareHelper`
- **Vị trí:** `lib/core/share_helper.dart:78-90, 101-107, 122-128`
- **Mức độ & Effort:** **Priority: P1 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  1. Trong `_withTextOverlay`: `final picture = recorder.endRecording(); return picture.toImage(...);`. Native Skia `ui.Picture` không bao giờ được `picture.dispose()`, gây rò rỉ RAM đồ họa mỗi lần share thẻ chiến thắng/journey.
  2. Các hàm `shareText`, `shareBoardImage`, `shareScoreCard` gọi `SharePlus.instance.share` mà không truyền `sharePositionOrigin`. Trên iPad / iPadOS, thiếu popover anchor sẽ ném `NSGenericException` crash ứng dụng ngay lập tức.
- **Cách fix đề xuất:**
  Bọc `toImage` trong `try ... finally { picture.dispose(); }` và bổ sung tham số tùy chọn `Rect? sharePositionOrigin`.

---

#### BUG-30: Trùng lặp Accessibility / Semantics trong `StrokeText` (Screen Reader đọc lặp 2 lần)
- **Vị trí:** `lib/presentation/widgets/stroke_text.dart:31-60`
- **Mức độ & Effort:** **Priority: P2 | Effort: XS**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - `StrokeText` xếp chồng 2 widget `Text(text)` trong `Stack` (1 viền nét vẽ stroke + 1 fill chữ).
  - Cả 2 widget đều đăng ký vào Semantics tree. TalkBack / VoiceOver đọc chuỗi văn bản 2 lần liên tiếp.
- **Cách fix đề xuất:**
  Bọc lớp Text viền nền bằng `ExcludeSemantics`.

---

#### BUG-31: Double-Pop làm thoát nhầm màn hình cha trong `NeonDialog.show`
- **Vị trí:** `lib/presentation/widgets/neon_dialog.dart:125-128`
- **Mức độ & Effort:** **Priority: P2 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Doc comment ghi: *"onTap tự chịu trách nhiệm đóng dialog"*.
  - Nhưng dòng 126 `NeonDialog.show` lại tự ý gọi `if (nav.canPop()) nav.pop();` trước khi kích hoạt `onTap`.
  - Nếu action của caller cũng gọi `Get.back()` hoặc `Navigator.pop()`, dialog bị pop trước và lệnh pop thứ hai sẽ pop luôn màn hình game/menu bên dưới.
- **Cách fix đề xuất:**
  Thống nhất contract: chỉ pop khi action không tự đóng, hoặc thêm cờ `autoClose: true/false`.

---

#### BUG-32: Không thể kéo thả vào ô trống trong `InventoryGrid`
- **Vị trí:** `lib/presentation/widgets/common/inventory_grid.dart:114-127, 197-208`
- **Mức độ & Effort:** **Priority: P2 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Các ô có vật phẩm được bọc trong `DragTarget<int>`, nhưng các ô trống (`emptyBuilder`) thì không.
  - Người chơi chỉ có thể tráo đổi 2 ô đã có vật phẩm, hoàn toàn không thể di chuyển một vật phẩm sang một ô trống trong kho đồ.
- **Cách fix đề xuất:**
  Bọc `emptyBuilder` bằng `DragTarget<int>` và gọi `onReorder(details.data, emptySlotIndex)`.

---

#### BUG-33: Tràn RenderFlex khi màn hình xoay ngang và lỗi ParentData trong `PauseOverlay`
- **Vị trí:** `lib/presentation/widgets/common/pause_overlay.dart:108, 144-185`
- **Mức độ & Effort:** **Priority: P2 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  1. `build()` trả về `Positioned.fill(...)`. Nếu widget này được nhúng ở nơi cha không phải là `Stack`, Flutter ném `ParentDataWidget` Error.
  2. Toàn bộ 4 nút bấm + Title nằm trong `Column` không cuộn với chiều cao > 360px. Trên thiết bị xoay ngang (chiều cao 320–390dp), menu bị `RenderFlex overflowed`.
- **Cách fix đề xuất:**
  Bọc nội dung panel trong `SingleChildScrollView`.

---

#### BUG-34: Double-spin trong `WheelSpinner` hủy spin đang chạy và làm mất phần thưởng của người chơi
- **Vị trí:** `lib/presentation/widgets/common/wheel_spinner.dart:210-226`
- **Mức độ & Effort:** **Priority: P2 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Khi vòng quay đang quay (`_controller.isAnimating`), nếu `controller.spin()` được gọi lần nữa, token tăng lên `myToken != _spinToken`.
  - Callback `whenComplete` của lần quay trước kiểm tra `if (myToken != _spinToken) return;` và hủy bỏ hoàn toàn callback `onSpinEnd` của lần quay trước.
  - Nếu game đã trừ xu/vé quay của người chơi ở lần bấm đầu, người chơi bị mất trắng phần thưởng của lần quay đó.
- **Cách fix đề xuất:**
  Chặn nhận lệnh spin mới khi `_controller.isAnimating`, hoặc ném `StateError('Wheel is already spinning')`.

---

### 1.5. Example App Lifecycle & Integration Bugs

#### BUG-35: Rò rỉ bộ nhớ & Crash `setState() after dispose` trong DeepLink Handler
- **Vị trí:** `example/lib/screens/widget_showcase_screen.dart:409-418`
- **Mức độ & Effort:** **Priority: P0 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Trong `initState()`, `_deepLinks.registerHandler('level', (command) => setState(...))` đăng ký closure vào router vĩnh viễn (`permanent: true`).
  - Trong `dispose()`, các handler không được dọn dẹp (do `DeepLinkCommandRouter` thiếu hàm `unregisterHandler`).
  - Closure giữ tham chiếu đến State cũ gây memory leak. Khi người chơi thoát ra Home và deep link kích hoạt, gọi `setState()` trên State đã unmount gây crash app.
- **Cách fix đề xuất:**
  Bổ sung `unregisterHandler` vào `DeepLinkCommandRouter` và gọi trong `dispose()`, bọc `if (!mounted) return;`.

---

#### BUG-36: Stale Signal làm "liệt" toàn bộ Demo Network Banner khi vào lại màn hình
- **Vị trí:** `example/lib/screens/widget_showcase_screen.dart:375-385, 1360-1367`
- **Mức độ & Effort:** **Priority: P1 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Lần đầu mở màn hình: `ConnectivityCoordinator` nhận `_connectivitySignal` (Signal A) và lưu `permanent: true`.
  - Người dùng back ra Home rồi vào lại: `_connectivitySignal` được khởi tạo mới (Signal B). Nhưng `ConnectivityCoordinator.maybe` trả về instance cũ đang nối với Signal A!
  - Nút bấm "Interface up/down" gọi trên Signal B, Coordinator không nhận được tín hiệu, demo bị "đơ" hoàn toàn. Ngoài ra probe 5s giữ closure tham chiếu State cũ gây rò rỉ bộ nhớ.
- **Cách fix đề xuất:**
  Không đăng ký permanent cho coordinator demo giả lập trong màn hình showcase, hoặc dọn dẹp service trong `dispose()`.

---

#### BUG-37: `OfflineOutboxService` lưu stale `uploader` callback trỏ vào State đã unmount
- **Vị trí:** `example/lib/screens/widget_showcase_screen.dart:482-492, 623-633`
- **Mức độ & Effort:** **Priority: P1 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - `OfflineOutboxService` đăng ký `permanent: true` với `uploader: _outboxUploader`.
  - `_outboxUploader` là method của `_WidgetShowcaseScreenState`. Instance service giữ tham chiếu tới State instance của lần mở đầu tiên, gây memory leak nặng nề.
- **Cách fix đề xuất:**
  Tách `uploader` thành static hoặc delegate độc lập không giữ tham chiếu State widget.

---

#### BUG-38: Thiếu `dispose()` trong `CookbookScreen` làm rò rỉ closure trong `CheckpointCoordinator`
- **Vị trí:** `example/lib/screens/cookbook_screen.dart:95-99`
- **Mức độ & Effort:** **Priority: P1 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - Class `_CookbookScreenState` hoàn toàn không có hàm `dispose()`.
  - Trong `initState()`, hàm đăng ký `_checkpoints.registerParticipant('cookbook_counter', snapshot: () => _checkpointCounter, ...)` vào permanent service. Mỗi lần mở và đóng màn hình này, một State instance cũ bị rò rỉ trong bảng `_participants`.
- **Cách fix đề xuất:**
  Thêm `dispose()` vào `CookbookScreen` và gọi `_checkpoints.removeParticipant('cookbook_counter')`.

---

#### BUG-39: Thiếu export `core/debug_log.dart` và `presentation/widgets/debug_qa_overlay.dart` trong `lib/roy_casual_kit.dart`
- **Vị trí:** `lib/roy_casual_kit.dart:95` đối chiếu `example/lib/main.dart:12-13` và `CLAUDE.md:139, 156`
- **Mức độ & Effort:** **Priority: P1 | Effort: S**
- **Mô tả lỗi & Kịch bản gây lỗi:**
  - `CLAUDE.md` hướng dẫn người dùng bọc app root bằng `DebugQaOverlay` và dùng `dlog()`.
  - Nhưng cả hai file này không hề được export trong `lib/roy_casual_kit.dart`. Trong `example/lib/main.dart`, tác giả buộc phải dùng deep internal import:
    ```dart
    import 'package:roy_casual_kit/core/debug_log.dart';
    import 'package:roy_casual_kit/presentation/widgets/debug_qa_overlay.dart';
    ```
    Vi phạm khuyến cáo của chính file barrel không dùng internal import.
- **Cách fix đề xuất:**
  Export `core/debug_log.dart` và `presentation/widgets/debug_qa_overlay.dart` trong `lib/roy_casual_kit.dart`, cập nhật `tool/api_snapshot.json`.

---

## 2. Enhancement cần làm

### 2.1. Kiến trúc API & Boundary Handling
1. **Bổ sung API `unregisterHandler(String type)` vào `DeepLinkCommandRouter`**
   - **Vị trí:** `lib/core/deep_link_command_router.dart:170`
   - **Mức độ & Effort:** **Priority: P1 | Effort: S**
   - **Mô tả:** Hiện tại chỉ có `registerHandler`, thiếu hàm unregister hoặc cancel token khiến mọi widget/screen đăng ký handler nội bộ đều bị dính memory leak.
2. **Bổ sung Audio Player Pool / Concurrency Limiter trong `AudioManager`**
   - **Vị trí:** `lib/core/audio_manager.dart:168-171`
   - **Mức độ & Effort:** **Priority: P1 | Effort: M**
   - **Mô tả:** Mỗi lần gọi `playSfx()` lại tạo mới 1 `AudioPlayer`. Khi nổ combo kẹo liên tục (15-20 sound/giây), việc mở 20 native audio channels đồng thời sẽ gây nghẽn audio driver trên Android cấp thấp. Cần pool tối đa 4-6 player tái sử dụng.
3. **Cache In-Memory cho `ConsentStateService` tránh JSON Decode trên hot-path**
   - **Vị trí:** `lib/core/consent_state_service.dart:112-145`
   - **Mức độ & Effort:** **Priority: P2 | Effort: S**
   - **Mô tả:** Mỗi sự kiện analytics gửi qua `ConsentGatedAnalyticsProvider` đều gọi `isGranted()`. Hàm này đọc raw string từ SharedPreferences và chạy `jsonDecode` mỗi lần. Cần cache in-memory `Map<ConsentCategory, ConsentRecord>? _cache`.
4. **Bổ sung Reactivity (`Rx` / listener) cho `PurchaseLedgerService`**
   - **Vị trí:** `lib/core/purchase_ledger_service.dart:180, 192`
   - **Mức độ & Effort:** **Priority: P2 | Effort: S**
   - **Mô tả:** `balanceOf(sku)` và `owns(sku)` đọc từ Map thuần, không có `Rx` thông báo khi `grantConsumable`/`consume` diễn ra. Widget UI hiển thị số tiền/vé không tự cập nhật được.
5. **Bổ sung API `reset()` / `clear()` cho Save Slot scoped services**
   - **Vị trí:** `lib/core/local_scoreboard_service.dart`, `onboarding_coordinator_service.dart`, `persistent_cooldown_service.dart`
   - **Mức độ & Effort:** **Priority: P2 | Effort: S**
   - **Mô tả:** Khi người chơi xóa save slot hoặc đổi profile, các service này không có cách nào reset trạng thái về rỗng.
6. **Ngăn chặn `isKilled()` ghi đè `_auditLog` trên hàm đọc getter của `RemoteKillSwitchController`**
   - **Vị trí:** `lib/core/remote_kill_switch_controller.dart:125-136`
   - **Mức độ & Effort:** **Priority: P2 | Effort: S**
   - **Mô tả:** Gọi `isKilled(featureId)` trong `build()` hoặc `Obx()` kích hoạt mutation và làm tràn 200 entry audit log chỉ sau vài giây.
7. **Bảo toàn `{placeholder}` trong `PseudoLocale`**
   - **Vị trí:** `lib/core/utils/pseudo_locale.dart:34-39`
   - **Mức độ & Effort:** **Priority: P3 | Effort: S**
   - **Mô tả:** Thuật toán đổi nguyên âm hiện tại đổi cả `{count}` thành `'{cóúnt}'`, phá vỡ các thư viện định dạng chuỗi tham số của game.
8. **Đồng bộ hóa I18n cho các Widget chung (`PauseOverlay`, `VictoryCardTemplate`)**
   - **Vị trí:** `lib/core/app_translations.dart`, `lib/presentation/widgets/common/pause_overlay.dart:148-180`
   - **Mức độ & Effort:** **Priority: P2 | Effort: S**
   - **Mô tả:** `PauseOverlay` đang hardcode tiếng Anh ('Paused', 'Resume', 'Restart', 'Settings', 'Quit') thay vì dùng key trong `AppTranslations`.

### 2.2. Gap kiểm thử & Bổ sung Demo trong `example/`
9. **Bổ sung Demo cho 11 Core Services & Widgets chưa từng xuất hiện trong `example/`**
   - **Mức độ & Effort:** **Priority: P2 | Effort: M**
   - **Danh sách thiếu:**
     - `PerformanceTierService` + `AuroraBgLayer` / `NeonAuraLayer` (Demo toggle FPS và bật tắt shader nền).
     - `ObjectPool` & `PooledComponent` (Demo tái sử dụng component Flame chống GC).
     - `TrustedClockService` (Demo phát hiện can thiệp đồng hồ).
     - `SaveMigrationRegistry` (Demo migrate save schema qua các version).
     - `NeonIcon` / `NeonIconButton` (Demo icon candy chuẩn bộ kit).
     - `FocusTrapScope` & `PressableScale` (Demo điều hướng bàn phím/gamepad).
10. **Đồng bộ Pause State giữa `GameSessionController` và Flame Engine trong `GameDemoScreen`**
    - **Vị trí:** `example/lib/screens/game_demo_screen.dart:100-110`
    - **Mức độ & Effort:** **Priority: P2 | Effort: S**
    - **Mô tả:** Khi mở Pause menu, session pause nhưng Flame game engine không gọi `_game.pauseEngine()`. Game loop vẫn chạy ngầm dưới dialog.

---

## 3. Task/tính năng mới nên thêm
*(Tính năng CHƯA có trong SDK nhưng phù hợp với 1 casual/idle game SDK dùng GetX+Flame)*

### TASK-01: Idle Prestige / Ascension Engine (`PrestigeService`)
- **Mức độ & Effort:** **Priority: P1 | Effort: M**
- **Lý do & Mô tả:**
  - Cơ chế cốt lõi của mọi tựa game Idle/Incremental (như Cookie Clicker, Adventure Capitalist): người chơi tích lũy tài nguyên đến một ngưỡng rồi kích hoạt "Prestige" (trùng sinh/thăng hoa).
  - Hệ thống tự động soft-reset các tài nguyên cấp thấp (vàng, level thường) và quy đổi sang Meta-Currency vĩnh viễn (vd: Relics/Stars) với công thức exponential multiplier: `multiplier = 1 + (relics * bonusPerRelic)`.
  - SDK hiện đã có `OfflineProgressionService` và `EconomyWallet`, nhưng thiếu hoàn toàn engine quản lý vòng đời Prestige này.

### TASK-02: Offline Reward Multiplier Dialog & Ad Booster Flow Widget
- **Mức độ & Effort:** **Priority: P1 | Effort: M**
- **Lý do & Mô tả:**
  - `OfflineProgressionService` hiện chỉ có logic tính toán thô `pendingEarnings` và `claim()`.
  - Trong thực tế 100% casual/idle game đều cần UI Popup: "Chào mừng trở lại! Bạn vắng mặt 4 giờ và nhận được 1,000 Vàng. [Xem Ads để nhân đôi x2 = 2,000 Vàng] hoặc [Nhận thường]".
  - Đóng gói sẵn widget `OfflineRewardDialog` kết nối trực tiếp với `OfflineProgressionService` và hook quảng cáo thưởng (`PurchaseSeam` hoặc Ad callback).

### TASK-03: Floating Juice FX & Damage/Coin Text Component Pool cho Flame
- **Mức độ & Effort:** **Priority: P1 | Effort: M**
- **Lý do & Mô tả:**
  - Hiện `PooledComponent` chỉ là mixin rỗng. Casual game cần hiệu ứng text nhảy số (+100 Gold, Critical Hit!, Combo x3) bay lên theo parabol/easing rồi mờ dần (juice feel).
  - Cung cấp sẵn `FlameFloatingTextComponent` và `FlameParticleBurstComponent` kế thừa `PooledComponent`, tự acquire từ pool và tự release khi animation kết thúc.

### TASK-04: Casual Battle Pass / Season Journey Service (`BattlePassService`)
- **Mức độ & Effort:** **Priority: P1 | Effort: L**
- **Lý do & Mô tả:**
  - `SeasonEventService` hiện chỉ quản lý time window (start/end). Casual game hiện đại luôn có Battle Pass: Cột Free Tier và Cột Premium/Gold Pass, thanh tiến trình XP từ cấp 1..50, logic claim từng mốc và claim all.
  - Tích hợp chặt chẽ với `RewardTransactionPipeline` và `PlayerProgressionService`.

### TASK-05: Gacha / Loot Box Opening Presentation Kit
- **Mức độ & Effort:** **Priority: P2 | Effort: M**
- **Lý do & Mô tả:**
  - `WeightedRandomPick` đã có thuật toán bốc thăm xác suất, nhưng thiếu hoàn toàn widget trình diễn mở quà: animation lắc rương, nổ tia sáng neon, lật thẻ bài với viền phát sáng theo độ hiếm (Common: xám, Rare: xanh, Epic: tím, Legendary: vàng).

### TASK-06: Dynamic Audio Ducking & Pitch Escalation for Combos
- **Mức độ & Effort:** **Priority: P2 | Effort: M**
- **Lý do & Mô tả:**
  - `AudioManager` hiện có ducking bgm cơ bản. Cần bổ sung cơ chế tăng cao độ (pitch escalation): khi người chơi ăn combo liên tiếp 1, 2, 3, 4, 5..., cùng một SFX nổ nhưng pitch tự động nhân `1.0 + (combo * 0.05)` (âm điệu Đô - Rê - Mi - Pha - Son) tạo cảm giác cực kỳ hưng phấn (casual game juice).

---

## 4. Idea mới đáng cân nhắc

### IDEA-01: Haptic-Audio Pattern Synchronization (`AudioHapticSync`)
- **Mức độ & Effort:** **Priority: P2 | Effort: S**
- **Mô tả:** Tự động đồng bộ hóa các xung haptic (`HapticPattern`) khớp với nhịp điệu của file âm thanh SFX (tiếng bom nổ thì rung dồn dập, tiếng coin rơi thì rung nhẹ lách cách).

### IDEA-02: Directional Screen Shake theo Vector Va Chạm Flame
- **Mức độ & Effort:** **Priority: P2 | Effort: S**
- **Mô tả:** `ScreenShake` hiện tại rung đẳng hướng ngẫu nhiên. Nâng cấp nhận vector va chạm từ Flame (`Vector2 impactDirection`) để rung theo đúng hướng va chạm và hồi vị dạng tắt dần (damped harmonic oscillator).

### IDEA-03: Smart App Review Funnel Widget (`SmartReviewFunnel`)
- **Mức độ & Effort:** **Priority: P2 | Effort: S**
- **Mô tả:** Mở rộng `InAppReviewHelper`: trước khi mở In-App Review của Store, hiện micro-survey dễ thương: "Bạn có thích game không?". Nếu người chơi bấm "Thích ❤️" -> mở Google Play / App Store rating (tối ưu đánh giá 5 sao). Nếu bấm "Chưa thích 💔" -> mở form góp ý nội bộ để tránh nhận đánh giá 1 sao ngoài chợ ứng dụng.

### IDEA-04: Smart Push Notification Scheduler based on Energy Refill
- **Mức độ & Effort:** **Priority: P2 | Effort: S**
- **Mô tả:** Kết nối `ReminderService` với `EnergyService`: tự động tính chính xác thời điểm hồi đầy năng lượng (`fullEnergyAtMs`) để hẹn giờ thông báo: *"Năng lượng của bạn đã đầy 100%, quay lại tiếp tục cuộc chơi thôi!"*, hoặc nhắc nhở trước khi streak đăng nhập bị mất hạn.

### IDEA-05: Low Power / Battery Saver Mode Coordinator
- **Mức độ & Effort:** **Priority: P2 | Effort: S**
- **Mô tả:** Tự động lắng nghe mức pin thiết bị: khi pin < 20% hoặc khi game đang ở chế độ Auto-play, tự động hạ target frame rate từ 60/120fps xuống 30fps và tạm dừng các shader background (`AuroraBgLayer`) để chống nóng máy và tiết kiệm pin.

---

## 5. Tính năng độc quyền (Competitive Differentiator)
*(So sánh với các package phổ biến trên pub.dev như `flame`, `get`, `bonfire`, `flame_behaviors`... tạo lợi thế cạnh tranh thực sự cho `roy_casual_kit`)*

### 🌟 DIFFERENTIATOR 1: "Flame-GetX Zero-Jank State Bridge" (Bi-directional World-to-UI Binding with Zero Allocation)
- **Mức độ & Effort:** **Priority: P0 | Effort: L**
- **Bối cảnh thị trường:**
  - Các game làm bằng Flame khi muốn gắn thanh máu, tên quái vật, damage number hoặc bubble chat bằng Flutter widget đều gặp bế tắc lớn: hoặc dùng `game.overlays.add` rất thô sơ, hoặc dùng Ticker lắng nghe và gọi `setState()` ở 60/120fps (như `FlameTrackedOverlay` hiện tại). Việc này kích hoạt lại layout pass của Flutter và sinh rác bộ nhớ (GC allocation) liên tục, gây giật lag (jank) khung hình nghiêm trọng.
- **Giải pháp độc quyền:**
  - Xây dựng một custom `RenderObjectWidget` chuyên dụng (ví dụ `FlameWorldTrackerScope`) liên kết trực tiếp với Viewport Transform Matrix của Flame Camera.
  - Cập nhật trực tiếp `TransformLayer` trong paint pass của RenderObject mà **hoàn toàn KHÔNG trigger build hay layout pass của Flutter subtree**.
  - Cho phép hiển thị mượt mà hàng trăm widget Flutter bám theo các thực thể Flame đang di chuyển với **0% GC overhead và 120 FPS ổn định**. Đây là tính năng chưa từng có package nào trên pub.dev làm hoàn chỉnh.

---

### 🌟 DIFFERENTIATOR 2: "Deterministic Anti-Cheat Time & Replay Verification Engine"
- **Mức độ & Effort:** **Priority: P0 | Effort: L**
- **Bối cảnh thị trường:**
  - 99% game casual/idle phát hành client-only (không có game server chuyên dụng) đều bị người chơi hack bằng cách vặn lùi giờ máy hoặc tua nhanh giờ để farm vàng vô hạn, hack daily streak, và submit điểm ảo lên bảng xếp hạng. Các game engine hay base kit hiện tại hoàn toàn bỏ ngỏ vấn đề này.
- **Giải pháp độc quyền:**
  - Kết hợp kiềng 3 chân: `TrustedClock` (phân tích độ lệch wall-clock vs monotonic tick) + `ReplayRecorder` (ghi log input/event theo tick máy ảo) + `SaveIntegrity` (chữ ký HMAC chống chỉnh sửa file lưu).
  - SDK cung cấp cơ chế headless verification: khi người chơi đạt điểm kỷ lục (High Score), SDK xuất kèm 1 `ReplayCapsule`. Client hoặc server đơn giản có thể chạy lại capsule đó trong 50ms (headless không cần render UI) để xác thực người chơi có thực sự đạt điểm số đó một cách hợp lệ hay không.
  - Mang lại sự công bằng tuyệt đối cho các tựa game offline-first có Global Leaderboard.

---

### 🌟 DIFFERENTIATOR 3: "Casual Game Live-Ops In-App DevTools Sidecar"
- **Mức độ & Effort:** **Priority: P1 | Effort: M**
- **Bối cảnh thị trường:**
  - Việc kiểm thử Live-Ops (A/B testing, kill-switch, roll-out sự kiện mùa, test chuyển version save) trong quá trình phát triển game thường rất mất thời gian: lập trình viên phải sửa tay trong database hoặc deploy lên Firebase Remote Config thật.
- **Giải pháp độc quyền:**
  - Nâng cấp `DebugQaOverlay` thành một bộ In-App DevTools hoàn chỉnh:
    - **Time Travel Slider:** Kéo thanh trượt để giả lập thời gian trôi qua +2h, +24h, +7 ngày để xem ngay lập tức phản ứng của Daily Quest, Streak, Energy, Season Event mà không cần đổi giờ hệ thống máy thật.
    - **Network Simulator:** Giả lập mất mạng, mạng chập chờn, force conflict sync của `OfflineOutboxService`.
    - **Variant Switcher:** Đổi tức thì nhóm thử nghiệm A/B testing để so sánh UI và cân bằng kinh tế in-game.
  - Giúp các studio casual game rút ngắn 50% thời gian QA và cân bằng game trước khi release.

---
*Báo cáo được thực hiện độc lập, khách quan, dựa trên phân tích trực tiếp từ mã nguồn thực tế của `roy_casual_kit`.*
