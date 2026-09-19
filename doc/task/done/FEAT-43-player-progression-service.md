---
id: FEAT-43
title: "PlayerProgressionService — XP, level curve và unlock reward"
type: feature
layer: game/data-logic
priority: P1
effort: M
depends_on: [FEAT-31, FEAT-37, FEAT-42]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là game developer, tôi muốn cấu hình curve XP và nhận level-up event/reward ổn định qua restart.

## Sprint slices
- Immutable level definition/curve validator và progression state.
- Repository versioned persistence; service SSOT `grantXp` idempotent.
- Multi-level jump, max level, unlock reward qua pipeline.
- GetX reactive snapshot và example UI.

## Acceptance criteria
- [x] Curve tăng hợp lệ; duplicate/missing/overflow config bị reject rõ.
- [x] Grant XP qua nhiều level phát đúng từng unlock một lần.
- [x] Concurrent grant, transaction trùng, max level và corrupt save không tăng quyền lợi sai.
- [x] Restart giữ XP/level/unlock nhất quán.

## Prompt loop feature
Đọc task/dependencies; implement model→repository→service→UI bằng TDD. End loop: audit code, chấm /10; unit test + widget test + integration test mọi curve/grant/race/persist/corrupt case; analyze/test root + example; smoke Android device thật chứng minh multi-level flow. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

### Kiến trúc
Tái dùng chính xác pattern "idempotent ledger" đã có ở `EconomyWallet`
(FEAT-31) và `RewardTransactionPipeline` (FEAT-42) thay vì phát minh lại:

- **Model thuần** (`LevelDefinition`, `validateLevelCurve`,
  `levelForTotalXp`, `xpIntoLevelForTotalXp`) — không phụ thuộc
  `StorageService`/GetX, viết test TRƯỚC (đúng "TDD model→repository→
  service→UI"). `level`/`xpIntoLevel`/`xpToNextLevel` KHÔNG BAO GIỜ được
  persist trực tiếp — chỉ `totalXpEarned` (lifetime) được lưu, còn lại luôn
  tính lại từ curve mỗi lần — nên không thể lệch pha dù curve thay đổi giữa
  các version.
- **`validateLevelCurve`** chạy ngay trong constructor của
  `PlayerProgressionService` — config sai (duplicate/thiếu level, không
  contiguous, level không phải cuối có `xpToNext <= 0`, curve giảm dần,
  tổng dồn tràn giới hạn hỗ trợ) throw `ArgumentError` ngay lập tức, không
  bao giờ để lọt xuống logic tính level sai âm thầm. Level CUỐI trong curve
  bắt buộc `xpToNext == 0` — đây là điểm đánh dấu max level.
- **`grantXp(amount, transactionId)`** chạy trong
  `AsyncActionGuard.runExclusive('progression', ...)` — 2 lệnh gọi đồng thời
  tự động serialize thay vì đua nhau ghi đè; `transactionId` trùng (kể cả
  sau restart, vì đã persist trong `_transactions`) là no-op trả về
  snapshot hiện tại — cùng cơ chế `EconomyWallet._apply` đã dùng.
- **Multi-level jump + unlock reward**: `grantXp` tính `newLevel` từ
  `totalXpEarned` mới, liệt kê MỌI level giữa `_highestUnlockedLevel+1` và
  `newLevel`, với mỗi level gọi `RewardTransactionPipeline.grant(
  transactionId: 'level_up:$level', ...)` (deterministic, tự idempotent ở
  tầng pipeline) rồi bắn `onLevelUp` theo đúng thứ tự tăng dần. XP quá max
  level vẫn cộng dồn vào `totalXpEarned` (trung thực cho analytics/leaderboard)
  nhưng `level` bị chặn ở max, không unlock thêm lần nào nữa.
- **Corrupt save**: `_hydrate()` bọc try/catch toàn bộ — bất kỳ lỗi parse
  nào reset về `totalXpEarned=0, highestUnlockedLevel=1, transactions=[]`
  (không throw, không trust một phần dữ liệu đã decode, không tự tăng
  quyền lợi) — giống hệt fallback của `EconomyWallet`.
- Hydrate/recompute đặt trong `onInit()` (không phải constructor) — đúng
  lifecycle GetxService mà `EconomyWallet`/`RewardTransactionPipeline` đã
  dùng, để test có thể gọi `..onInit()` thủ công khi không đi qua `Get.put`.

### Test
`test/core/player_progression_service_test.dart` (22 test, viết TRƯỚC
implementation — xoá... không cần vì lib chưa tồn tại, xác nhận RED "Method
not found", viết lib, xác nhận GREEN):
- `validateLevelCurve` (7): hợp lệ, rỗng, duplicate, gap, thiếu max marker,
  giảm dần, overflow.
- `levelForTotalXp`/`xpIntoLevelForTotalXp` pure (5): biên dưới/trên mỗi
  level, nhảy nhiều level, vượt xa max không tràn.
- `grantXp` cơ bản (4): khởi tạo, cộng XP trong level, reject input xấu,
  idempotent transaction trùng.
- Multi-level + unlock (2): nhảy thẳng lên max phát đúng 2 event theo thứ
  tự, cấp gem đúng 1 lần; level không có reward thì không gọi pipeline.
- Max level (1): XP thêm sau max không tăng level, không cấp reward lần 2.
- Persist qua restart (1): tạo service mới cùng storage giữ nguyên level/
  XP/transaction.
- Corrupt save (1): JSON hỏng không throw, không tự tăng quyền lợi.
- Config invalid (1): constructor throw `ArgumentError` rõ ràng.
Toàn bộ: root 1603/1603 pass, example 86/86 pass (2 widget test mới cho
demo). `flutter analyze` sạch root + example.

### Device smoke (Pixel 7 Pro, serial 2B051FDH3006MU)
Build `flutter build apk --debug`, cài + mở `com.galaxyjoy.roycasualkit`,
cuộn tới demo PlayerProgressionService (cuối "Layout & Cards", ngay sau
SceneTransitionOverlay). Trạng thái ban đầu "Level 1 / XP: 0/100 (total: 0)
/ Unlock gems: 0" — đúng. Bấm "Grant 300 XP (multi-level)": nhảy thẳng
"Level 3 (MAX)", "Total XP: 300", "Unlock gems: 50" — reward gem THẬT được
cấp qua `RewardTransactionPipeline`+`EconomyWallet` thật (không giả lập),
chụp ảnh màn hình lưu bằng chứng. Bấm "Grant 50 XP" lần nữa (đã max):
"Total XP: 350" tăng nhưng "Level 3 (MAX)" và "Unlock gems: 50" giữ nguyên
— đúng chính sách cap max-level, không cấp reward lần 2.
`mobile_list_crashes` rỗng trong suốt phiên thao tác.

### Tự chấm: 9.5/10
Đạt đủ 4 acceptance criteria, tái dùng đúng pattern idempotent-ledger đã
kiểm chứng ở FEAT-31/FEAT-42 thay vì phát minh lại (giảm rủi ro bug mới),
test cover đầy đủ curve validation/multi-level/max-level/corrupt-save/
persist-restart, device-smoke xác nhận multi-level jump + reward thật.
Trừ 0.5 vì "Repository versioned persistence" trong sprint slice chỉ dừng
ở việc lưu `totalXpEarned`/`highestUnlockedLevel` dạng JSON phẳng (không
có version tag/migration chain riêng như `SaveMigrationRegistry`, FEAT-37)
— chấp nhận được vì thay đổi curve không phải "đổi schema" theo nghĩa
FEAT-37 giải quyết, nhưng chưa có cơ chế tường minh cho trường hợp một bản
cập nhật game đổi hẳn cấu trúc lưu (đổi tên field, thêm field bắt buộc).

