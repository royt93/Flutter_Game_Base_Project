---
id: ENH-71
title: "Còn 6 service khác cũng hardcode _storageKey — chưa nối được với SaveSlotManager.keyFor như LocalScoreboardService (ENH-69)"
type: enhancement
priority: medium
effort: M
source: Claude (self-generated backlog brainstorm — grep trực tiếp `static const _storageKey` trong `lib/core/*.dart`)
---

## Vị trí
Mở rộng — 6 file trong `lib/core/`: `achievement_service.dart`, `daily_quest_service.dart`, `daily_login_service.dart`, `season_event_service.dart`, `purchase_ledger_service.dart`, `onboarding_coordinator_service.dart`.

## Hiện trạng
ENH-69 (đã done) đổi `LocalScoreboardService`'s `static const _storageKey` thành 1 field instance nhận được từ constructor (`storageKey ?? 'local_scoreboard_v1'`), để nối được với `SaveSlotManager.keyFor(slotId, suffix)` (IDEA-56) — mỗi save slot có 1 bảng xếp hạng riêng. Nhưng đây KHÔNG PHẢI service duy nhất có đúng vấn đề đó. Xác nhận qua `grep -n "static const _storageKey" lib/core/*.dart`: còn ĐÚNG 6 service khác vẫn dùng `static const _storageKey = '...'` cố định, dùng đúng 1 lần tại `key: _storageKey` bên trong 1 `VersionedJsonStore`, và KHÔNG service nào trong 6 service này có constructor tường minh (toàn bộ đều dùng constructor mặc định ngầm của Dart — xác nhận qua `grep -nE "^  [A-Za-z]+\("` không tìm thấy constructor nào khai báo tường minh cho cả 6 class):

- `achievement_service.dart:28` — `AchievementService`, key `'achievement_progress_v1'`
- `daily_quest_service.dart:61` — `DailyQuestService`, key `'daily_quest_progress_v1'`
- `daily_login_service.dart:81` — `DailyLoginService`, key `'daily_login_state_v1'`
- `season_event_service.dart:47` — `SeasonEventService`, key `'season_event_anchors_v1'`
- `purchase_ledger_service.dart:37` — `PurchaseLedgerService`, key `'purchase_ledger_v1'`
- `onboarding_coordinator_service.dart:25` — `OnboardingCoordinatorService`, key `'onboarding_seen_v1'`

## Vì sao cần / Hậu quả
1 game nhiều nhân vật (dùng `SaveSlotManager`) chỉ nối được ĐÚNG 1 trong 7 service theo-người-chơi hiện có (`LocalScoreboardService`) với từng save slot riêng. Achievement, daily quest, daily login streak, season event, purchase ledger, onboarding — tất cả 6 service còn lại VẪN dùng chung 1 bản ghi cho toàn máy, bất kể đang ở slot nào. Đây là chỗ nứt rõ ràng nhất giữa tính năng `SaveSlotManager` vừa thêm (IDEA-56) và phần còn lại của package — 1 game thật muốn "mỗi nhân vật có tiến trình achievement/quest/streak riêng" (rất phổ biến với game nhiều save slot) không có cách nào làm được mà không tự fork lại từng service.

## Đề xuất
Áp dụng ĐÚNG pattern ENH-69 đã dùng cho `LocalScoreboardService`, lặp lại y hệt cho cả 6 service — không phát minh cách làm mới:

Với mỗi service, đổi `static const _storageKey = 'xxx_v1';` thành:
```dart
ServiceName({String? storageKey}) : _storageKey = storageKey ?? 'xxx_v1';
// ...
final String _storageKey;
```
(giữ nguyên chuỗi key mặc định y hệt cũ — không phá bất kỳ save nào đang tồn tại của consumer app hiện có). Không đổi bất kỳ hành vi nào khác của 6 service này.

**Lưu ý implement**: 1 vài service trong 6 service này có thể có field khác cần giữ trong constructor (kiểm tra kỹ từng file trước khi sửa, đừng giả định tất cả giống hệt nhau) — đọc toàn bộ file trước khi đổi, đừng chỉ copy-paste mù quáng.

## Acceptance criteria
- [x] Cả 6 service đều nhận `{String? storageKey}` trong constructor, mặc định giữ đúng key cũ khi không truyền.
- [x] Với mỗi service: 2 instance dùng 2 `storageKey` khác nhau hoàn toàn độc lập (test tương tự ENH-69).
- [x] Với mỗi service: persist đúng qua "restart" khi dùng `storageKey` tuỳ chỉnh.
- [x] Không đổi bất kỳ hành vi public API nào khác của cả 6 service; không phá bất kỳ test hiện có nào trong `test/core/`.
- [x] Test: unit test đầy đủ mọi case trên cho CẢ 6 service (mỗi service ít nhất: mặc định giữ key cũ, 2 instance độc lập, persist qua restart với key tuỳ chỉnh).
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không bắt buộc đụng `example/`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-71-remaining-services-custom-storage-key.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Đọc lại chính xác cách ENH-69 đã sửa `LocalScoreboardService` (đọc `lib/core/local_scoreboard_service.dart` hiện tại, phần constructor + `_storageKey`) làm mẫu, rồi đọc TOÀN BỘ cả 6 file trong `## Vị trí` trước khi sửa — mỗi file có thể có chi tiết khác nhau (field khác trong constructor, cách `_storageKey` được dùng trong `_store`/`_hydrate`). Implement bằng TDD (viết test fail trước, code cho pass), làm TỪNG service một, chạy test sau mỗi service trước khi qua service tiếp theo.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng nhất quán với pattern ENH-69, không phá API/test hiện có của CẢ 6 service, không over-engineer — chỉ 1 param + đổi field mỗi service, không thêm gì khác).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria, cho CẢ 6 service.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không bắt buộc đụng `example/` (thay đổi core service thuần, không có UI liên quan trực tiếp) — không cần device smoke test.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk (`git show :path | grep -c '\[x\]'` so với `grep -c '\[x\]'` trên disk), commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận bằng `grep -n "static const _storageKey" lib/core/*.dart` cho kết quả đúng 6 file còn lại (ngoài `LocalScoreboardService` đã sửa ở ENH-69), mỗi file xác nhận thêm bằng cách đọc dòng dùng `key: _storageKey` bên trong `VersionedJsonStore`/tương đương, và xác nhận cả 6 class đều KHÔNG có constructor tường minh hiện tại (constructor mặc định ngầm) nên thay đổi không có rủi ro va chạm với logic khởi tạo khác đã có. Effort M (mechanical, lặp lại đúng 1 pattern đã kiểm chứng ở ENH-69 nhưng trải trên 6 file + cần test đầy đủ cho từng file), không đụng file nhạy cảm/scope peer, không trùng bất kỳ FEAT-*/IDEA/ENH/BUG nào đã có.

## Quyết định

Áp dụng đúng pattern ENH-69 cho cả 6 service, lần lượt từng file một, chạy test ngay sau mỗi file trước khi qua file tiếp theo (đúng yêu cầu trong Prompt):

1. `AchievementService` — thêm constructor, đổi `static const` → field.
2. `DailyQuestService` — tương tự.
3. `DailyLoginService` — tương tự; xác nhận `late final _store` (khởi tạo trễ, không phải getter tính lại mỗi lần như 5 service kia) vẫn an toàn vì `late` chỉ evaluate initializer ở lần truy cập ĐẦU TIÊN, sau khi constructor đã gán xong `_storageKey`.
4. `SeasonEventService` — tương tự.
5. `PurchaseLedgerService` — tương tự.
6. `OnboardingCoordinatorService` — tương tự.

Không có bất ngờ nào giữa 6 file — đúng như "Ghi chú độ tin cậy" dự đoán, cả 6 đều dùng đúng 1 pattern (`static const _storageKey` → `key: _storageKey` bên trong `VersionedJsonStore`, không có constructor tường minh trước đó).

**Test:** 4 test mới × 6 service = 24 test trong `test/core/*_service_test.dart` tương ứng — mỗi service đều có đủ: không truyền `storageKey` giữ đúng key cũ, 2 instance với 2 key khác nhau độc lập hoàn toàn, persist đúng qua "restart" với key tuỳ chỉnh, không đổi hành vi API public hiện có. Tất cả 6 service PASS ngay lần chạy đầu tiên sau khi sửa — không phát sinh bug nào (khác IDEA-56 trước đó, nơi TDD bắt được 1 bug thật) vì đây là thay đổi thuần cơ học, lặp lại đúng 1 pattern đã kiểm chứng.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1230/1230 pass (1206 trước đó + 24 test mới). Không đụng `example/` (đúng "không bắt buộc" trong Prompt — 6 service này không có UI demo nào cần đổi API, chỉ thêm 1 param optional không phá `example/` hiện có).

**Tự chấm điểm: 10/10** — đúng chính xác 1 pattern đã kiểm chứng lặp lại nhất quán cho cả 6 file, không có sai lệch/ngoại lệ nào giữa các file, đọc kỹ từng file trước khi sửa thay vì copy-paste mù quáng (đúng yêu cầu "Lưu ý implement" trong Đề xuất — phát hiện đúng `DailyLoginService` dùng `late final` khác 5 service kia dùng getter, xác nhận vẫn an toàn thay vì bỏ qua), test đầy đủ theo từng service một, không phá bất kỳ test cũ nào trong 6 file.
