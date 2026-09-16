---
id: ENH-62
title: "EconomyWallet: persist processed transaction id để idempotency sống sót qua restart"
type: enhancement
priority: high
effort: S
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/core/economy_wallet.dart`)
---

## Vị trí
Sửa lỗi — `lib/core/economy_wallet.dart` (`EconomyWallet._transactions`).

## Hiện trạng
`EconomyWallet.earn`/`trySpend` dùng `_transactions` (một `Set<String>` thuần trong bộ nhớ) để chống double-apply cùng 1 `transactionId` — gọi lại với id đã thấy sẽ no-op, trả về `SdkSuccess(balanceOf(currency))` mà không cộng/trừ lần 2. NHƯNG chỉ `balances` được persist xuống `StorageService` qua `_key` — `_transactions` không bao giờ được ghi xuống disk. Nghĩa là sau khi app restart, `_transactions` rỗng trở lại, và gọi lại `earn`/`trySpend` với đúng `transactionId` đã áp dụng trước khi restart sẽ bị cộng/trừ THÊM 1 lần nữa.

## Vì sao cần / Hậu quả
Đây chính là kịch bản thực tế phổ biến nhất của idempotency: 1 receipt IAP được xử lý xong (earn thành công), app bị kill/crash NGAY SAU đó trước khi tầng gọi (ví dụ `PurchaseSeam` adapter) kịp đánh dấu receipt đã xử lý ở phía nó, rồi app khởi động lại và store/adapter phát lại đúng transactionId đó (hành vi bình thường của StoreKit/Billing Library khi giao dịch chưa được "finish/consume" tường minh) — `EconomyWallet` sẽ cộng tiền/tài nguyên 2 lần dù chính nó tự nhận là có cơ chế chống trùng. Đây là lỗi liên quan trực tiếp tới tiền/tài nguyên trong game, không phải chi tiết vặt.

## Đề xuất
Persist `_transactions` cùng với `balances`, nhưng KHÔNG để nó phình vô hạn qua hàng nghìn giao dịch trong đời game — bounded (ví dụ giữ N id gần nhất, LRU hoặc FIFO đơn giản, N có thể là hằng số nhỏ như 200) tương tự `ReplayRecorder`'s ring buffer (IDEA-42) hoặc đơn giản hơn nếu đủ dùng. Ghi + đọc cùng 1 file JSON `_key` hiện có (ví dụ thêm field `transactions: [...]` cạnh field balances hiện tại) — không cần file/khoá storage riêng.

## Acceptance criteria
- [x] Sau khi `earn`/`trySpend` thành công với `transactionId` X, tạo 1 `EconomyWallet` MỚI (mô phỏng restart) rồi gọi lại đúng `earn`/`trySpend` với cùng X: không cộng/trừ thêm lần 2 (đúng hành vi idempotent, y hệt khi gọi lại trong CÙNG 1 instance).
- [x] Danh sách transaction id đã xử lý KHÔNG phình vô hạn — vượt quá giới hạn (N) thì id CŨ NHẤT bị loại bỏ trước, id MỚI vẫn được chống trùng đúng.
- [x] JSON cũ (từ trước khi field transaction ids tồn tại, chỉ có balances) vẫn load được, không throw — coi như danh sách transaction đã xử lý rỗng (chấp nhận: 1 giao dịch cũ trước bản này có thể bị áp dụng lại đúng 1 lần duy nhất ngay sau khi migrate, không lặp vô hạn).
- [x] JSON hỏng cho field transaction ids (sai kiểu): rơi về danh sách rỗng an toàn, không throw, không làm hỏng luôn `balances` đang đọc đúng.
- [x] Không phá bất kỳ test/hành vi hiện có nào của `earn`/`trySpend`/`balanceOf` (bao gồm `_guard.runExclusive` khoá đồng thời).
- [x] Test: unit test đầy đủ mọi case trên, đặc biệt test "restart rồi gọi lại đúng transactionId cũ" — đây là bug chính cần chứng minh đã sửa.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không có animation mới cần thiết (thay đổi core service thuần).

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-62-economy-wallet-persist-transaction-ids.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Đọc toàn bộ `lib/core/economy_wallet.dart` và `test/core/economy_wallet_test.dart` hiện có để hiểu đúng cơ chế `_guard.runExclusive`/persist hiện tại trước khi sửa. Viết test TRƯỚC xác nhận đúng bug (restart rồi gọi lại transactionId cũ bị cộng thêm lần 2) — nếu test đó PASS ngay từ đầu (tức bug không tái hiện được như mô tả), dừng lại và báo cáo rõ thay vì tự suy diễn tiếp. Sau khi xác nhận bug, sửa bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, cơ chế bounded không over-engineer — ưu tiên cấu trúc đơn giản nhất đủ dùng, ví dụ 1 `List<String>` FIFO thay vì cấu trúc LRU phức tạp nếu không thật sự cần).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Cân nhắc có nên đổi format JSON theo cách cần bump `schemaVersion`/migration rõ ràng hay không (nếu `EconomyWallet` hiện không dùng `VersionedJsonStore`, cân nhắc có nên chuyển sang dùng để nhất quán với các service khác, hoặc giữ nguyên cách tự `jsonEncode`/`jsonDecode` hiện có nếu đủ đơn giản — quyết định và giải thích ngắn gọn trong `## Quyết định`).
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root (service thuần, không bắt buộc đụng `example/`).
5. Không cần device smoke test riêng (thay đổi core service thuần, không có UI liên quan trực tiếp) — nhưng nếu cân nhắc và quyết định thêm demo minh hoạ vào `example/`, phải test + device smoke test cho phần đó.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk (`git show :path | grep -c '\[x\]'` so với `grep -c '\[x\]'` trên disk), commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `economy_wallet.dart`: `_transactions` là field instance thuần (`final _transactions = <String>{}`), không xuất hiện trong `_hydrate()`/`jsonEncode(snapshot)` nào — chỉ `balances` được đọc/ghi storage. Đây là lỗi thật, không phải suy đoán. Effort nhỏ (thêm 1 field vào JSON + logic bounded đơn giản), không đụng file nhạy cảm/scope peer.

## Quyết định

Xác nhận đúng bug bằng TDD trước: viết test "restart rồi gọi lại đúng transactionId cũ" — FAIL ngay (balance thành 20 thay vì giữ 10), đúng như "Ghi chú độ tin cậy" dự đoán. Sửa bằng cách:

- Đổi `_transactions` từ `Set<String>` sang `List<String>` (FIFO đơn giản — quyết định KHÔNG dùng cấu trúc LRU phức tạp hơn, vì "id cũ nhất bị loại trước" là đúng yêu cầu và `List` + `removeRange` đủ rẻ cho N=200) — vẫn giữ nguyên `.contains()` cho check chống trùng.
- Đổi format JSON persist từ raw balances map sang `{'balances': {...}, 'transactions': [...]}`. Migration dựa vào chính sự có/không có key `'balances'` để phân biệt save CŨ (raw JSON chính là balances map) với save MỚI — không cần thêm field `schemaVersion` riêng cho việc này.
- **Quyết định KHÔNG chuyển sang `VersionedJsonStore`**: logic migrate ở đây chỉ có đúng 1 bước rẽ nhánh (`containsKey('balances')`), không cần cơ chế `migrate(fromVersion, json)` nhiều bước của `VersionedJsonStore` — giữ nguyên `jsonEncode`/`jsonDecode` tự viết là đủ đơn giản và nhất quán với cách `EconomyWallet` đã tự quản lý persist từ đầu, tránh thêm 1 tầng trừu tượng không cần thiết cho 1 thay đổi nhỏ.

**Test:** 6 test mới trong `test/core/economy_wallet_test.dart` nhóm "ENH-62" — xác nhận đúng bug ban đầu đã sửa (test chính), id mới vẫn chống trùng đúng sau restart, bounded FIFO (250 giao dịch không phình vô hạn, id mới nhất vẫn đúng), JSON cũ load được, JSON hỏng field `transactions` rơi về rỗng an toàn (balances vẫn đọc đúng), không phá hành vi atomic/idempotent hiện có trong cùng 1 instance.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1104/1104 pass. Không đụng `example/` (đúng theo Prompt — service thuần, không có UI liên quan trực tiếp, không cần demo).

**Tự chấm điểm: 9.5/10** — sửa đúng bug thật liên quan trực tiếp tới tiền/tài nguyên (mức độ nghiêm trọng cao nhất trong các ENH gần đây), cấu trúc bounded đơn giản nhất đủ dùng, migration rõ ràng không phá dữ liệu cũ, quyết định kiến trúc (không chuyển sang `VersionedJsonStore`) được cân nhắc và giải thích rõ thay vì áp dụng máy móc. Trừ điểm nhỏ vì "chấp nhận 1 giao dịch cũ có thể bị áp dụng lại đúng 1 lần duy nhất ngay sau migrate" là 1 giới hạn đã biết trước (ghi rõ trong Acceptance criteria), không phải giải pháp hoàn hảo tuyệt đối — nhưng đây là đánh đổi hợp lý vì không thể biết được các transactionId nào đã xử lý trước khi field này tồn tại.
