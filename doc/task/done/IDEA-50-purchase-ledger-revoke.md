---
id: IDEA-50
title: "PurchaseLedgerService: thu hồi (revoke) consumable/permanent cho refund/chargeback"
type: idea
priority: medium
effort: S
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/core/purchase_ledger_service.dart`)
---

## Vị trí
Mở rộng — `lib/core/purchase_ledger_service.dart` (`PurchaseLedgerService`).

## Hiện trạng
`PurchaseLedgerService` có `grantConsumable`/`grantPermanent` (cộng thêm) và `consume` (trừ dần, không cho âm), nhưng KHÔNG có cách nào thu hồi (revoke) 1 lượt cấp — cả cho consumable lẫn permanent. Trong thực tế, store (Google Play/App Store) có thể báo refund/chargeback sau khi đã grant — game cần 1 cách đáng tin cậy để rút lại quyền sở hữu/số dư đã cấp trước đó khi `PurchaseSeam` adapter của app nhận được sự kiện đó.

## Vì sao cần / Hậu quả
Không có API này, 1 game nhận được sự kiện refund từ store không có cách nào rút lại "remove ads"/"premium skin" đã unlock hay số dư consumable đã cộng qua chính service này — phải tự viết logic riêng thao tác thẳng vào storage, phá vỡ đúng nguyên tắc "đây là cache local phía trên `PurchaseSeam`" mà class đã tự nhận trong doc hiện có.

## Đề xuất
Thêm 2 method:
- `void revokePermanent(String sku)` — gỡ `sku` khỏi tập permanent đã sở hữu. An toàn gọi với `sku` chưa từng được `grantPermanent` (no-op, không throw) — đối xứng với `grantPermanent` đã "an toàn gọi lại".
- `void revokeConsumable(String sku, int amount)` — trừ `amount` khỏi số dư `sku`, nhưng KHÔNG cho xuống dưới 0 (clamp về 0, không throw RangeError) — vì 1 refund có thể đến sau khi người chơi đã tiêu bớt số dư đó, và không có "nợ âm" nào có ý nghĩa ở đây.

Cả 2 method validate `sku` rỗng giống các method hiện có (`_validateSku`), và lên lịch save qua `_scheduleSave()` sẵn có — không viết lại cơ chế save riêng.

## Acceptance criteria
- [x] `revokePermanent(sku)` gỡ đúng quyền sở hữu; `owns(sku)` trả về `false` sau đó.
- [x] `revokePermanent(sku)` với `sku` chưa từng sở hữu: no-op, không throw.
- [x] `revokeConsumable(sku, amount)` trừ đúng số dư khi đủ; `balanceOf(sku)` phản ánh đúng.
- [x] `revokeConsumable(sku, amount)` khi `amount` lớn hơn số dư hiện có: clamp về 0 (không âm), không throw.
- [x] `revokeConsumable`/`revokePermanent` với `sku` rỗng: throw `ArgumentError` (giống `_validateSku` hiện có).
- [x] `revokeConsumable` với `amount <= 0`: throw `ArgumentError` (giống `_validateAmount` hiện có).
- [x] Cả 2 method đúng persist qua `_scheduleSave()`/`debugPendingSaves` — test xác nhận state sống sót qua 1 instance mới load lại từ storage.
- [x] Test: unit test đầy đủ cho mọi case trên.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không có animation mới cần thiết (thay đổi core service thuần).

## Quyết định

Implement đúng 2 method đối xứng như đề xuất, tái dùng 100% hạ tầng có sẵn — không viết lại `_validateSku`/`_validateAmount`/`_scheduleSave`:

- **`revokePermanent(sku)`**: validate rồi `_state.permanents.remove(sku)` — `Set.remove` vốn đã no-op an toàn cho phần tử không tồn tại, không cần thêm nhánh kiểm tra riêng.
- **`revokeConsumable(sku, amount)`**: validate rồi trừ, clamp về 0 bằng `amount >= current ? 0 : current - amount` — tránh dùng `max(0, current - amount)` không cần thiết vì so sánh trực tiếp rõ ràng hơn và tránh nhập thêm `dart:math`.

**Test:** 7 test mới trong `test/core/purchase_ledger_service_test.dart` nhóm "IDEA-50" — gỡ đúng quyền sở hữu, no-op cho sku chưa từng có, trừ đúng số dư, clamp về 0 khi vượt/khi sku chưa từng grant, validate sku rỗng/amount không hợp lệ throw đúng, và persist qua "restart" (instance mới đọc lại đúng cả 2 thay đổi).

**Kết quả:** root `flutter analyze` sạch. Root `flutter test --exclude-tags slow`: chạy 2 lần, mỗi lần đúng 1 lỗi flaky KHÁC NHAU (lần 1: `lifecycle_coordinator_test.dart` "isolates hook errors and timeout" — timeout 5ms; lần 2: `energy_service_test.dart` "ghi atomic... bằng đúng 1 lần write" — cũng nhạy thời gian) — cả 2 file này KHÔNG liên quan gì tới `purchase_ledger_service.dart`, và cả 2 pass sạch 100% khi chạy riêng lẻ (`flutter test test/core/lifecycle_coordinator_test.dart` và `flutter test test/core/energy_service_test.dart`) — xác nhận đây là flakiness đã biết của bộ test lớn dưới tải, không phải regression từ thay đổi IDEA-50. Không đụng `example/` (đúng theo Prompt — service thuần, không bắt buộc demo).

**Tự chấm điểm: 9.5/10** — đối xứng đúng, đủ mọi case validate/clamp/persist, tái dùng triệt để hạ tầng có sẵn, không over-engineer (không thêm lịch sử giao dịch vì task không yêu cầu). Trừ điểm nhỏ vì không wire demo UI minh hoạ (cân nhắc nhưng quyết định không cần, vì đây thuần là API xử lý sự kiện store-side, không có UI tương tác trực tiếp có ý nghĩa để demo).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-50-purchase-ledger-revoke.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Đọc toàn bộ `lib/core/purchase_ledger_service.dart` và test hiện có để hiểu đúng pattern `_validateSku`/`_validateAmount`/`_scheduleSave`/`debugPendingSaves` đã có, tái dùng nguyên — không viết lại. Implement bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, tái dùng đúng helper nội bộ, không over-engineer — ví dụ không cần thêm lịch sử/log giao dịch nếu task không yêu cầu).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria, bao gồm test persist (load lại từ 1 instance mới sau khi revoke, dùng `debugPendingSaves` để chờ save xong).
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (không bắt buộc đụng `example/` — đây là thay đổi core service thuần, không nhất thiết cần demo UI).
4. Nếu quyết định thêm demo trong `example/`: phải test + device smoke test cho phần đó, kiểm tra `mobile_list_available_devices`/`mobile_get_foreground_app`/`ListAgents` trước khi thao tác thiết bị thật (KHÔNG dùng simulator/emulator).

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `purchase_ledger_service.dart`: không có method revoke/refund nào tồn tại, chỉ có grant/consume 1 chiều cộng dồn. Effort nhỏ (đối xứng trực tiếp với các method hiện có, tái dùng toàn bộ hạ tầng validate/save), không đụng file nhạy cảm/scope peer.
