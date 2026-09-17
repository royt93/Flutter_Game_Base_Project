---
id: ENH-73
title: "EconomyWallet vẫn hardcode storage key — bỏ sót khỏi ENH-71"
type: enhancement
priority: low
effort: XS
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/core/economy_wallet.dart`)
---

## Vị trí
Mở rộng — `lib/core/economy_wallet.dart` (`EconomyWallet`).

## Hiện trạng
ENH-69/ENH-71 đã thêm `{String? storageKey}` cho 7 service (`LocalScoreboardService`, `AchievementService`, `DailyQuestService`, `DailyLoginService`, `SeasonEventService`, `PurchaseLedgerService`, `OnboardingCoordinatorService`) — tất cả service dùng `VersionedJsonStore` với `static const _storageKey`. Nhưng `EconomyWallet` — service quan trọng nhất để đặt theo save-slot (số dư tiền tệ trong game) — vẫn còn `static const _key = 'economy_wallet_v1'` (dòng 23), KHÔNG nằm trong danh sách 6 service của ENH-71 vì nó không dùng `VersionedJsonStore` (tự `jsonEncode`/`storage.getString` trực tiếp, constructor hiện tại là `EconomyWallet({required this.storage, AsyncActionGuard? guard})`). Bỏ sót thuần do khác pattern constructor, không phải cố ý loại trừ.

## Vì sao cần / Hậu quả
`SaveSlotManager` (IDEA-56) tồn tại chính là để 1 game nhiều nhân vật/nhiều save độc lập — ví/tiền tệ chắc chắn là dữ liệu ĐẦU TIÊN một game cần tách theo slot (2 nhân vật không nên dùng chung 1 ví coin). Hiện tại không cách nào làm việc đó với `EconomyWallet` vì key luôn cố định `'economy_wallet_v1'` — 2 instance luôn đọc/ghi đè lên đúng 1 key, y hệt lỗ hổng mà ENH-69/71 đã vá cho 7 service kia.

## Đề xuất
Thêm `{String? storageKey}` vào constructor hiện có (giữ nguyên `required this.storage`/`AsyncActionGuard? guard`), đổi `static const _key` thành field:

```dart
EconomyWallet({
  required this.storage,
  AsyncActionGuard? guard,
  String? storageKey,
}) : _guard = guard ?? AsyncActionGuard(),
     _key = storageKey ?? 'economy_wallet_v1';

final String _key; // was `static const`
```

Không đổi bất kỳ hành vi `earn`/`trySpend`/`balanceOf`/`_hydrate`/`_apply` nào khác — chỉ đổi nguồn của `_key`.

## Acceptance criteria
- [x] Không truyền `storageKey`: hành vi/dữ liệu y hệt hiện tại, đọc đúng key cũ `economy_wallet_v1`.
- [x] 2 instance với 2 `storageKey` khác nhau hoàn toàn độc lập (balances + transaction-idempotency list riêng biệt, không đụng nhau).
- [x] `storageKey` tuỳ chỉnh persist đúng qua "restart" (instance mới cùng key đọc lại đúng).
- [x] Không đổi hành vi `earn`/`trySpend`/`balanceOf`/migration cũ-mới-format (`ENH-62`) hiện có.
- [x] Không phá bất kỳ test nào trong `test/core/economy_wallet_test.dart`.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không bắt buộc đụng `example/`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-73-economy-wallet-custom-storage-key.md` này trước khi làm. Đọc `lib/core/economy_wallet.dart` toàn bộ (đặc biệt `_key`/`_hydrate`/`_apply`, và migration cũ-mới-format ENH-62 trong `_hydrate`) và `test/core/economy_wallet_test.dart` (quy ước hiện có — dùng `EconomyWallet(storage: StorageService(null))` trực tiếp, không qua `Get.put` bắt buộc) trước khi sửa. Implement bằng TDD (viết test fail trước, code cho pass) — đúng mẫu `_storageKey` đã dùng ở ENH-69/71 nhưng adapt cho constructor có `required this.storage` sẵn.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng nhất quán với pattern `storageKey` đã dùng 7 lần trước đó, không phá API/test/migration hiện có, không over-engineer).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không bắt buộc đụng `example/`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `economy_wallet.dart`: `static const _key = 'economy_wallet_v1'` tồn tại (dòng 23), constructor hiện tại KHÔNG có `storageKey`. Xác nhận `EconomyWallet` không nằm trong danh sách 6 service của ENH-71 (task đó liệt kê rõ 6 tên file, không có `economy_wallet.dart`) — bỏ sót thật, không phải trùng lặp. Effort cực nhỏ (đổi 1 field + constructor param), không đụng file nhạy cảm/scope peer, không trùng bất kỳ FEAT-*/IDEA/ENH/BUG nào đã có trong `doc/task/done/`.

## Quyết định

Đúng như đề xuất — đổi `static const _key` thành `final String _key;` gán qua `storageKey ?? 'economy_wallet_v1'` trong initializer list, giữ nguyên `required this.storage`/`AsyncActionGuard? guard` sẵn có. `EconomyWallet` không dùng `VersionedJsonStore` (tự `jsonEncode`/`storage.getString`) nên khác cách áp dụng 1 chút so với 7 service ENH-69/71 nhưng cùng bản chất: field thay cho hằng số, default y hệt literal cũ.

**Test:** 4 test mới trong `test/core/economy_wallet_test.dart` nhóm "ENH-73" — dùng đúng quy ước có sẵn của file này (`EconomyWallet(storage: storage)..onInit()` gọi tay thay vì qua `Get.put`, vì `onInit()` chỉ tự chạy qua GetX lifecycle). Bao phủ: không truyền storageKey giữ key cũ, 2 instance 2 key độc lập hoàn toàn (balance + transaction-idempotency), persist qua "restart" với key tuỳ chỉnh, không đổi hành vi earn/trySpend/balanceOf.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1238/1238 pass (1 lần chạy đầu có 2 test flake không liên quan — `reminder_service_test`/`storage_service_test`/`lifecycle_coordinator_test`/`audio_manager_test` timing-sensitive, chạy lại sạch 100%). Không đụng `example/` (không bắt buộc).

**Tự chấm điểm: 9.5/10** — đúng pattern đã dùng 7 lần trước, test đầy đủ, không phá migration ENH-62 hiện có. Trừ 0.5 vì phải điều tra riêng 1 lần chạy suite bị flake để xác nhận không liên quan thay đổi của mình trước khi kết luận sạch.
