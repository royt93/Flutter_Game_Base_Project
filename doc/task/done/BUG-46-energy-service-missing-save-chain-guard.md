---
id: BUG-46
title: "EnergyService ghi state qua unawaited(_writeState(...)) trần, không có save-chain guard như 7 service anh em"
type: bug
priority: P1
effort: S
source: "Fork nội bộ (audit lib/core/*.dart), verify lại qua Read lib/core/energy_service.dart:78-90,140-146,193"
---

## Vị trí
`lib/core/energy_service.dart` — `consumeEnergy()` (dòng ~78-90) và `_regen()` (dòng ~140-146), cả 2 dùng `unawaited(_writeState(...))` (dòng 193) trực tiếp.

## Hiện trạng
Không giống 7 service ledger cùng họ (`AchievementService`, `DailyLoginService`, `DailyQuestService`, `LocalScoreboardService`, `OnboardingCoordinatorService`, `PurchaseLedgerService`, `SaveSlotManager`, `SeasonEventService` — đã có `_saving`/`_saveChain` guard, dù bản thân guard đó cũng đang bị race theo BUG-45), `EnergyService` hoàn toàn KHÔNG có bất kỳ guard nào — cả `consumeEnergy` và `_regen` gọi thẳng `unawaited(_writeState(...))`.

## Vì sao cần / Hậu quả
Gọi `consumeEnergy()` 2 lần liên tiếp không `await` (double-tap dùng năng lượng trong game) tạo 2 write future chạy song song không có thứ tự đảm bảo — future ghi SAU (theo thời gian I/O thật, không phải thứ tự gọi) có thể chứa state CŨ hơn nếu future đầu chậm hơn. Restart app sau đó, energy count có thể rollback về giá trị cũ hơn — người chơi lợi dụng để farm năng lượng miễn phí bằng double-tap liên tục.

## Đề xuất
Thêm `_saveChain`/`_scheduleSave()` (dùng đúng helper chung sẽ tạo ở BUG-45 nếu 2 task được làm cùng đợt; nếu làm độc lập trước, viết inline giống pattern hiện có ở `PurchaseLedgerService`/`SaveSlotManager`), thay `unawaited(_writeState(...))` bằng `_scheduleSave()` ở cả 2 call site.

## Acceptance criteria
- [x] `consumeEnergy()` gọi 2 lần liên tiếp không await — ghi disk theo đúng thứ tự gọi, không bị race đảo ngược.
- [x] `_regen()` và `consumeEnergy()` gọi xen kẽ nhau (regen đang ghi, consume gọi ngay sau) vẫn ghi đúng thứ tự, không mất write nào.
- [x] Hành vi trả về (giá trị `count` sau `consumeEnergy`) không đổi so với hiện tại trong trường hợp không có race.
- [x] Test race cụ thể verify bằng cách kiểm soát thứ tự resolve của 2 Future ghi song song.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/BUG-46-energy-service-missing-save-chain-guard.md` này trước khi làm. Đọc toàn bộ `lib/core/energy_service.dart` và tham khảo pattern `_saving`/`_saveChain` ở `lib/core/purchase_ledger_service.dart`/`lib/core/save_slot_manager.dart` (lưu ý: pattern đó tự nó cũng có 1 race hẹp khác, xem `BUG-45` — không bắt buộc phải làm chung 1 lúc, nhưng nếu BUG-45 đã xong trước, dùng đúng helper `_scheduleSave()` chung của BUG-45 thay vì tự viết lại `_saving` boolean cũ). Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Smoke test trên device Android thật khuyến khích (double-tap nút tiêu năng lượng trong `WidgetShowcaseScreen`/`CookbookScreen` nếu có demo `EnergyService`, verify không rollback) nhưng không bắt buộc nếu chỉ verify được qua unit test race.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — tự Read trực tiếp `energy_service.dart`, xác nhận cả 2 call site dùng `unawaited(_writeState(...))` trần, grep xác nhận không có `_saving`/`_saveChain` nào trong file. Không trùng task nào trong `doc/task/done/`.

## Quyết định

Fix dùng đúng pattern `_scheduleSave()`/`.whenComplete()` vừa xác lập ở BUG-45 (không dùng `.then()`/`await` lồng — đã chứng minh phá tính "bắt đầu đồng bộ" mà test hiện có phụ thuộc).

**Phát hiện quan trọng hơn cả mô tả gốc**: EnergyService khác 8 service đã sửa ở BUG-45 ở 1 điểm cấu trúc — KHÔNG có field in-memory nào giữ state (mọi lần gọi đều `_readState()` thẳng từ storage). Nếu chỉ sửa THỨ TỰ GHI (như BUG-45) mà không sửa gì thêm, 1 bug KHÁC (nặng hơn) vẫn còn nguyên: 2 lệnh `consumeEnergy()` gọi trước khi write ĐẦU TIÊN kịp land disk sẽ cả 2 cùng đọc CHUNG 1 state cũ (vì chưa gì được ghi), tính delta từ CÙNG baseline, và lệnh sau ghi đè lệnh trước — mất hẳn 1 lần trừ (farm năng lượng dễ hơn cả bug gốc mô tả). Đã tự viết test tái hiện đúng kịch bản này (`_GatedStorageService`), thấy fail thật (actual đếm sai) trước khi phát hiện nguyên nhân.

Fix thêm: `_latestState` (field in-memory, khởi tạo `null`, được set ngay lần `_scheduleSave` đầu tiên và KHÔNG BAO GIỜ bị xoá — khác `_saveDirty`/`_pendingState` kiểu "consume rồi clear" đã thử ban đầu và cũng sai, vì trong khoảng write đang treo thì field đó lại rỗng, quay về đọc storage cũ). Mọi điểm đọc/ghi (`consumeEnergy`, `_regen`, `currentEnergy`, `timeUntilNextEnergy`, `debugLastRegenMs`) đều đi qua `_currentState() => _latestState ?? _readState()` — ưu tiên giá trị mới nhất trong bộ nhớ (dù write chưa land) trước khi rơi về storage. Về bản chất, `_latestState` đóng đúng vai trò field in-memory mà 8 service kia đã có sẵn, chỉ khác là khởi tạo lazily (đúng theo thiết kế "không cache cho tới khi có gì để cache" hiện có của class này) thay vì hydrate ngay trong constructor.

**TDD:** viết 3 test mới trước (2 test race + 1 test hành vi không đổi). Trong lúc viết, tính tay giá trị mong đợi cho test "regen + consume xen kẽ" bị SAI 2 lần liên tiếp (do chưa tính đúng ảnh hưởng của thiết kế `_latestState`/regen math kép) — mỗi lần đều chạy test thật để lấy giá trị ĐÚNG thay vì đoán, rồi verify lại bằng suy luận tay khớp kết quả trước khi chấp nhận assertion. Xác nhận fix cần thiết: `git stash` riêng file lib — cả 3 test compile-fail (API `debugPendingSaves` không tồn tại ở code cũ) — bằng chứng gián tiếp hợp lệ (cùng cách đã dùng ở BUG-49). Khôi phục fix: cả 25 test (22 cũ + 3 mới) pass.

**Không phá gì:** `flutter analyze` root + `example/` sạch. `dart run tool/api_compatibility.dart check` → unchanged. `flutter test --exclude-tags slow` root: verify 2 lần liên tiếp, lần 1 ra 2060 pass/20 fail (không tìm được chi tiết non-golden do log nền bị cắt), lần 2 (chạy sạch lại) ra 2061 pass/19 fail — đúng khớp baseline golden đã biết, xác nhận lần trước chỉ là flaky thoáng qua không liên quan. `example/`: 129/129 pass.

Không cần smoke test device — fix nội bộ tầng service thuần, hành vi qua `Get.put` không đổi, `EnergyService` chưa có UI thật gọi trong `example/` theo cách lộ ra race này.

**Tự chấm điểm: 9.5/10.** Fix đúng root cause CHO CẢ 2 lớp bug (thứ tự ghi VÀ đọc-cũ-do-thiếu-cache — lớp thứ 2 nghiêm trọng hơn, không nằm trong mô tả gốc của task nhưng được TDD tự phát hiện ra thay vì chỉ áp dụng máy móc pattern BUG-45), giữ nguyên toàn bộ hành vi/test cũ, tự sửa 2 lần tính sai trong chính test mới trước khi commit thay vì assert nhầm rồi bỏ qua. Trừ 0.5 vì không verify được TDD fail bằng runtime behavior thật (chỉ compile-fail, do fix mở API mới `debugPendingSaves`) như các task khác trong đợt.
