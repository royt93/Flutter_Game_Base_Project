---
id: IDEA-56
title: "SaveSlotManager — nhiều save slot độc lập (nhiều nhân vật/profile) trên cùng 1 thiết bị"
type: idea
priority: medium
effort: L
source: Claude (self-generated backlog brainstorm — đọc `lib/core/storage_service.dart`, `lib/core/versioned_json_store.dart`, `doc/task/done/FEAT-05-save-slot-versioning.md`, `doc/task/done/IDEA-31-backup-restore-panel.md`)
---

## Vị trí
Mới — `lib/core/save_slot_manager.dart`. Thêm 1 method nhỏ vào `lib/core/storage_service.dart` (`removeAllWithPrefix`) để hỗ trợ xoá đúng dữ liệu của 1 slot. Không sửa `VersionedJsonStore` (dùng nguyên trạng, chỉ truyền `key` đã namespace theo slot).

## Hiện trạng
`VersionedJsonStore<T>` (FEAT-05) cho phép 1 object JSON có version/migrate, nhưng CHỈ đúng 1 bản duy nhất mỗi `key` cố định — không có khái niệm "nhiều slot" (nhiều nhân vật, nhiều file save độc lập trên cùng máy, kiểu "New Game" ở 3 vị trí khác nhau). `BackupRestorePanel` (IDEA-31) cũng chỉ export/import ĐÚNG 1 bộ dữ liệu hiện tại (toàn bộ `StorageService`), không có khái niệm "slot nào đang active". Xác nhận qua `grep -rn "SaveSlot\|save_slot"` trong `lib/`: không có gì tồn tại. Đây là khoảng trống thật: package có sẵn 2 khối xây dựng (`StorageService` phẳng, `VersionedJsonStore` có version) nhưng không có tầng NÀO quản lý "nhiều bộ dữ liệu độc lập, chọn 1 cái đang active".

## Vì sao cần / Hậu quả
"Nhiều slot save" (3 file save, chọn nhân vật ở màn hình chính) là tính năng kinh điển của rất nhiều casual/mid-core game. Không có `SaveSlotManager`, mỗi consumer app tự phải nghĩ ra cách namespace key (dễ đụng độ nếu tự nghĩ ra quy ước khác nhau giữa các file), tự quản lý danh sách slot nào tồn tại/tên hiển thị/lần chơi gần nhất, và tự viết logic xoá ĐÚNG toàn bộ key thuộc 1 slot khi xoá slot đó (dễ sót key, để lại rác trong storage).

## Đề xuất
`SaveSlotManager` (`GetxService`) — chỉ quản lý METADATA của slot (id, tên hiển thị, thời điểm tạo, lần chơi gần nhất) + slot nào đang active + cung cấp key đã namespace cho consumer tự dùng với `VersionedJsonStore` của riêng họ. KHÔNG tự sở hữu schema dữ liệu người chơi (mỗi game có player profile khác nhau) — giữ đúng ranh giới "coordinator mỏng" giống `OnboardingCoordinatorService` (IDEA-54) đã làm, nhưng cho 1 domain hoàn toàn khác (save slot, không phải onboarding). Chia 4 slice:

**Slice 1 — Slot metadata & CRUD cơ bản**
- `SaveSlotMeta` (data class): `id` (String, caller tự chọn hoặc auto-generate), `displayName`, `createdAtMs`, `lastPlayedAtMs`.
- `List<SaveSlotMeta> listSlots()` — sắp xếp theo `lastPlayedAtMs` giảm dần (gần chơi nhất lên đầu, đúng UX "Continue" kinh điển).
- `SaveSlotMeta createSlot(String displayName)` — tự sinh `id` duy nhất (không trùng slot đang có), `createdAtMs`/`lastPlayedAtMs` = `nowMsClamped()` (dùng đúng clock chống chỉnh giờ đã có trong repo, KHÔNG dùng `DateTime.now()` trực tiếp).
- `void renameSlot(String id, String newDisplayName)`, `void touchSlot(String id)` (cập nhật `lastPlayedAtMs` — gọi khi consumer bắt đầu 1 phiên chơi trong slot đó).
- Metadata list persist qua 1 `VersionedJsonStore<List<SaveSlotMeta>>` riêng của chính `SaveSlotManager` (namespace riêng, không đụng key của slot con nào).

**Slice 2 — Active slot & key namespacing**
- `String? activeSlotId` (getter) / `void setActiveSlot(String id)` — persist qua `StorageService` (1 key đơn giản, không cần `VersionedJsonStore` vì chỉ là 1 String), sống sót qua restart.
- `String keyFor(String slotId, String suffix)` — trả về key đã namespace (ví dụ `'slot_${slotId}_$suffix'`) để consumer tự dùng làm `key:` khi tự construct `VersionedJsonStore` riêng của họ cho dữ liệu người chơi trong slot đó (ví dụ player profile, level progress) — `SaveSlotManager` không hề biết/đụng vào nội dung JSON thật của consumer.
- `setActiveSlot` với `id` không tồn tại trong danh sách slot hiện có → throw `ArgumentError` (an toàn, tránh active vào 1 slot ma).

**Slice 3 — Xoá slot đúng, không để sót rác**
- Thêm `Future<void> removeAllWithPrefix(String prefix)` vào `StorageService` (method nhỏ, tương tự tinh thần `eraseAll` IDEA-55 vừa làm — quét `allKeys()`/`exportAll()` hiện có, lọc key có prefix, `remove` từng key, rollback-safe theo đúng convention nếu 1 bước giữa chừng lỗi — tái dùng logic đã có, không phát minh cơ chế mới).
- `Future<void> deleteSlot(String id)` trong `SaveSlotManager`: xoá metadata của slot khỏi danh sách VÀ gọi `storage.removeAllWithPrefix('slot_${id}_')` để dọn sạch mọi key con thuộc slot đó. Nếu `id` đang là `activeSlotId` → set `activeSlotId` về `null` sau khi xoá (không để trỏ vào slot đã biến mất).
- JSON metadata cũ/hỏng (field sai kiểu, danh sách rỗng bất thường...) → domain trust boundary: rơi về danh sách slot rỗng an toàn, không throw, không crash — đúng convention `VersionedJsonStore`/các service khác trong repo.
- Race: nhiều `createSlot`/`touchSlot`/`deleteSlot` gọi dồn dập liên tiếp không `await` giữa các lần vẫn ghi đúng qua "restart" (đúng pattern BUG-17/BUG-18 đã sửa ở các service khác — `_saving`/`_saveChain`).

**Slice 4 — Wiring ví dụ + demo thật**
- Trong `example/`, thêm 1 demo nhỏ (màn hình mới `SaveSlotsScreen` hoặc 1 section trong `SettingsScreen` — quyết định khi implement) minh hoạ: tạo 2-3 slot mẫu, hiện danh sách (`CommonListTile`/`PanelCard` có sẵn), chọn 1 slot làm active (dùng luôn `keyFor` để lưu 1 giá trị mẫu — ví dụ điểm số demo — riêng biệt theo từng slot, chứng minh 2 slot KHÔNG chia sẻ dữ liệu), xoá 1 slot (có `ConfirmDialog` xác nhận trước vì là hành động phá huỷ dữ liệu, giống quyết định đã đưa ra ở IDEA-55).

**KHÔNG làm** (giữ đúng phạm vi effort L, tránh phình to hơn nữa): `SaveSlotManager` KHÔNG tự định nghĩa schema player profile nào (mỗi game khác nhau — đây là lý do IDEA-56 tách biệt với FEAT-05/`VersionedJsonStore`, không thay thế nó). KHÔNG tự động sync cloud (đã có `CloudSaveProvider`/`VersionedJsonStore.syncWith` riêng — nếu consumer cần multi-slot cloud sync, tự ghép ở tầng gọi bằng `keyFor`). KHÔNG giới hạn cứng số lượng slot tối đa trong code (để consumer tự quyết định UX, ví dụ giới hạn 3 slot ở tầng UI của họ).

## Acceptance criteria
- [x] `createSlot`/`listSlots`/`renameSlot`/`touchSlot` hoạt động đúng cơ bản; `listSlots()` sắp xếp đúng theo `lastPlayedAtMs` giảm dần.
- [x] `createSlot` sinh `id` không trùng với bất kỳ slot nào đang tồn tại, kể cả gọi liên tiếp nhiều lần nhanh.
- [x] `setActiveSlot`/`activeSlotId` persist đúng qua restart; `setActiveSlot` với id không tồn tại throw `ArgumentError`, không đổi `activeSlotId` hiện tại.
- [x] `keyFor(slotId, suffix)` sinh key ổn định, xác định (cùng input luôn ra cùng output), và 2 `slotId`/`suffix` khác nhau không bao giờ đụng key nhau.
- [x] `deleteSlot`: xoá đúng metadata VÀ mọi key con của slot đó (verify qua `StorageService.exportAll()` không còn key nào bắt đầu bằng đúng prefix của slot đã xoá); không đụng key của slot KHÁC. Nếu xoá đúng `activeSlotId` hiện tại → `activeSlotId` trở thành `null` sau đó.
- [x] `StorageService.removeAllWithPrefix`: xoá đúng mọi key có prefix, không đụng key khác không có prefix đó; prefix rỗng (`''`) throw `ArgumentError` thay vì âm thầm xoá sạch toàn bộ storage (an toàn, tránh lỗi gọi nhầm).
- [x] JSON metadata cũ/thiếu/hỏng: rơi về danh sách slot rỗng an toàn, không throw.
- [x] Race: nhiều `createSlot`/`touchSlot`/`deleteSlot` gọi liên tiếp không `await` giữa các lần cho nhiều slot khác nhau vẫn ghi đúng toàn bộ qua "restart".
- [x] Test: unit test đầy đủ mọi case trên (cả `SaveSlotManager` lẫn `StorageService.removeAllWithPrefix`).
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
- [ ] Device smoke test thật: tạo 2 slot, ghi 2 giá trị demo khác nhau vào mỗi slot qua `keyFor`, xác nhận đổi active slot thấy đúng dữ liệu riêng của từng slot, xoá 1 slot (qua `ConfirmDialog`) thấy dữ liệu biến mất đúng, restart app thấy state đúng — trên thiết bị thật hiện đang online.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-56-save-slot-manager.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Đọc toàn bộ `lib/core/storage_service.dart`, `lib/core/versioned_json_store.dart`, và 2 task đã done `IDEA-54-onboarding-coordinator-service.md`/`IDEA-55-storage-service-erase-all.md` để hiểu đúng convention persist/rollback/race-guard/trust-boundary đã dùng nhất quán trong repo trước khi viết code mới — tái dùng, không phát minh lại. Implement từng slice bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Sau MỖI slice: tự audit code vừa viết, chấm điểm /10 (đúng ranh giới trách nhiệm đã nêu ở "KHÔNG làm", không phá API/test hiện có của `StorageService`/`VersionedJsonStore`, không over-engineer).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria trước khi coi 1 slice là xong.
3. Sau khi cả 4 slice xong: chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
4. Device smoke test thật trên máy đang online hiện có (kiểm tra `mobile_list_available_devices` FRESH — KHÔNG dùng serial cũ từ file này hay từ phiên trước, thiết bị đổi liên tục qua session) — chụp screenshot/log logcat làm bằng chứng cụ thể 2 slot độc lập + xoá slot đúng. Kiểm tra `mobile_get_foreground_app`/`ListAgents` trước khi thao tác, dừng ngay nếu phát hiện app khác đang foreground (thiết bị có thể chia sẻ với peer session khác).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk (`git show :path | grep -c '\[x\]'` so với `grep -c '\[x\]'` trên disk), commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `storage_service.dart` (không có `removeAllWithPrefix`/`SaveSlot` nào tồn tại, `grep -rn "SaveSlot\|save_slot" lib/` rỗng) và qua đọc `doc/task/done/FEAT-05-save-slot-versioning.md` (xác nhận đây chỉ là tiền thân của `VersionedJsonStore` — 1 object JSON có version, KHÔNG phải khái niệm "nhiều slot") và `doc/task/done/IDEA-31-backup-restore-panel.md` (xác nhận đó là export/import UI cho ĐÚNG 1 bộ dữ liệu, không phải multi-slot). Không trùng `IDEA-54-onboarding-coordinator-service.md` (domain hoàn toàn khác — save slot, không phải onboarding/tutorial). Không trùng bất kỳ FEAT-* nào còn trong `doc/task/todo/` (đã đọc qua tên file, không có FEAT nào về save slot/multi-profile). Effort L hợp lý vì 4 mảng trách nhiệm tách bạch thật (metadata CRUD, active-slot + namespacing, xoá-đúng-không-sót-rác kèm 1 API mới trên `StorageService`, wiring demo thật + device smoke test) — không phải 1 getter/method đơn lẻ như các IDEA/ENH effort S/M gần đây trong session này.

## Quyết định

Implement đủ cả 4 slice như đề xuất, mô hình hoá `SaveSlotManager` theo sát `OnboardingCoordinatorService`/`AchievementService` (cùng convention lazy-hydrate + `VersionedJsonStore` + `_saving`/`_saveChain` chống race BUG-17/BUG-18) — tái dùng pattern đã kiểm chứng, không phát minh cơ chế mới.

**Slice 3 (`StorageService.removeAllWithPrefix`)**: thay vì tự viết vòng lặp `remove()` từng key (không có atomic rollback), tận dụng LUÔN `_replaceAll`'s rollback-on-error đã có bằng cách tính trước "trạng thái mong muốn sau khi xoá" (`exportAll()` trừ đi các key có prefix) rồi gọi thẳng `importAll(remaining)` — có atomicity miễn phí, đúng tinh thần "tái dùng logic đã có, không phát minh cơ chế mới" trong Đề xuất.

**Bug phát hiện qua TDD (bug thật, không phải suy đoán)**: thiết kế ban đầu cho `_generateUniqueId` xử lý va chạm cùng mili-giây bằng cách nối hậu tố (`'${base}_1'`, `'${base}_2'`, ...). Test "deleteSlot không đụng slot khác" FAIL ngay: xoá slot A (`'slot_100'`) vô tình xoá LUÔN dữ liệu slot B nếu B được tạo cùng mili-giây và nhận id `'slot_100_1'` — vì tiền tố xoá `'slot_slot_100_'` chính là tiền tố của mọi key thuộc B (`'slot_slot_100_1_...'`). Sửa bằng cách đổi cơ chế chống trùng: TĂNG SỐ thay vì nối hậu tố (`'slot_100'` → `'slot_101'` khi trùng) — không có id nào là tiền tố-có-dấu-gạch-dưới của id khác, loại bỏ hoàn toàn lớp lỗi này.

**Test:** 22 test mới trong `test/core/save_slot_manager_test.dart` (3 nhóm slice) + 3 test mới trong `test/core/storage_service_test.dart` cho `removeAllWithPrefix` — bao phủ đúng mọi acceptance criteria: CRUD cơ bản, id không trùng kể cả burst nhanh, sort đúng theo `lastPlayedAtMs`, active slot persist + validate id không tồn tại, `keyFor` ổn định/không đụng nhau, xoá đúng-không-sót-rác (chính test này bắt được bug ở trên), JSON hỏng an toàn, race nhiều thao tác liên tiếp.

**Demo trong `example/`**: thêm section "SaveSlotManager (IDEA-56)" trong `widget_showcase_screen.dart` — tạo slot, hiện danh sách qua `CommonListTile`, nút "+10 score" ghi vào đúng `keyFor(activeSlotId, 'demo_score')` (chứng minh 2 slot độc lập dữ liệu), xoá slot qua `ConfirmDialog` (đúng quyết định thận trọng với hành động phá huỷ dữ liệu, giống IDEA-55). Phải tăng `physicalSize` test viewport từ `9600` lên `10200` trong `_pumpShowcase` vì demo mới làm trang dài hơn, đẩy 1 section khác ra ngoài vùng "build sẵn" giả lập của test cũ (không phải bug, chỉ là kích thước cố định cần cập nhật theo nội dung trang).

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1189/1189 pass; `example/flutter analyze` sạch, `example/flutter test --exclude-tags slow` 54/54 pass (bao gồm 1 widget test tích hợp mới cho toàn bộ luồng tạo/chuyển/xoá slot qua UI thật). CHANGELOG.md đã cập nhật; `tool/api_compatibility.dart snapshot` đã regenerate với 2 class mới (`SaveSlotManager`, `SaveSlotMeta`) + 2 method mới trên `StorageService`.

**KHÔNG có device smoke test thật** — thiết bị Android duy nhất đang online trong suốt quá trình hoàn thành task (lần lượt `R9JN61LDLFJ` rồi `115333744A005844`) liên tục bị phiên AI khác (peer session dùng chung máy) chiếm dụng cho app riêng của họ (`com.roy.admobwrapper`). Đã chủ động đợi thiết bị rảnh qua polling tự động (`adb dumpsys window` mỗi 10s) tổng cộng ~7 phút liên tục, foreground app không đổi suốt thời gian đó — không phải thiếu sót do làm ẩu, mà là giới hạn thực tế của môi trường dùng chung tại thời điểm này.

**Tự chấm điểm: 9/10** — đúng cả 4 slice, ranh giới trách nhiệm "coordinator mỏng" được tôn trọng tuyệt đối (không tự định nghĩa schema player profile, không tự sync cloud), tái dùng triệt để `_replaceAll`'s atomicity cho `removeAllWithPrefix` thay vì viết lại, và quan trọng nhất: TDD thật sự bắt được 1 bug tinh vi (id-collision-suffix có thể trở thành tiền tố của id khác, gây xoá nhầm dữ liệu chéo slot) trước khi code này có cơ hội chạy trên thiết bị thật hay production — đúng giá trị cốt lõi của TDD mà session này theo đuổi xuyên suốt. Trừ điểm vì thiếu bằng chứng device thật (ngoài tầm kiểm soát, đã nỗ lực đợi thật sự thay vì bỏ qua ngay).
